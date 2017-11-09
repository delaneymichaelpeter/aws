#!/bin/bash

echo "Building Environment SecurityGroup ELB with AutoScaling"


# delaneyskivt userid
export AWS_PROFILE=delaneyskivt

vpcName=Default-VPC
# Get the Default VPC; assumes have one and default is the first returned.  NOT GOOD
vpcId=`aws ec2 describe-vpcs --output text --query 'Vpcs[0].VpcId'`
# Another way
vpcId=`aws ec2 describe-vpcs --filters Name=tag-key,Values=vpcname --filters Name=tag-value,Values=$vpcName --output text --query 'Vpcs[*].VpcId'`
echo "VPC : $vpcId"

# Create Security Group for HTTP and SSH
httpSgName=delaney-HTTP-SG
httpSgId=`aws ec2 create-security-group --group-name $httpSgName --description "Security to allow HTTP traffic" --vpc-id $vpcId --output text --query 'GroupId'`
aws ec2 create-tags --resources $httpSgId --tags Key=Name,Value="HTTP to EC2"
aws ec2 authorize-security-group-ingress --group-name $httpSgName --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "Http Security Group : $httpSgId"


# Create SSH
sshSgName=delaney-SSH-SG
sshSgId=`aws ec2 create-security-group --group-name $sshSgName --description "Allows SSH to box" --vpc-id $vpcId --output text --query 'GroupId'`
aws ec2 create-tags --resources $sshSgId --tags Key=Name,Value="SSH to EC2"
aws ec2 authorize-security-group-ingress --group-name $sshSgName --protocol tcp --port 22 --cidr 0.0.0.0/0
echo "SSH Security Group : $sshSgId"


# Create Load Balancer
elbName=delaney-ELB
subnetIds=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --output text --query 'Subnets[*].SubnetId'`
elbDnsName=`aws elb create-load-balancer --load-balancer-name $elbName --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $subnetIds --security-groups $sshSgId --output text --query 'DNSName'`
echo "ELB DNS Name : $elbDnsName"

# Delete Resources thus far
aws elb delete-load-balancer  --load-balancer-name $elbName
echo "Deleted ELB $elbName"
aws ec2 delete-security-group --group-name $sshSgName
echo "Deleted Security Group $sshSgName"
aws ec2 delete-security-group --group-name $httpSgName
echo "Deleted Security Group $httpSgName"


# Stop Here
exit 1

# Create Launch Configuration from EC2 instance
aws autoscaling create-launch-configuration --launch-configuration-name delaney-launch --instance-id i-a8e09d9c

# Describe your launch configuration
aws autoscaling describe-launch-configurations --launch-configuration-names delaney-launch

# Create Launch Configuraiton from EC2 instance but Override the block device
aws autoscaling create-launch-configuration --launch-configuration-name delaney-launch --instance-id i-a8e09d9c \
--block-devic-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{"SnapshotId\":\"snap-3decf207\"}},{\"DeviceName\":\"/dev/sdf\",\"Ebs\":{"SnapshotId\":\"snap-eed6ac86\"}}]"

# Create Launch Configuration from EC2 and Override Instance Type
aws autoscaling create-launch-configuration --launch-configuration-name delaney-launch --instance-id i-a8e09d9c \
--instance-type m1.small

# Create Launch Configuration from EC2 and Override Instance Type and set Spot Price
aws autoscaling create-launch-configuration --launch-configuration-name delaney-launch --image-id ami-1a2bc4d \
--instance-type m1.small --spot-price "0.05"


# Create AutoScaling Group
asgName=delaney-ASG
subnetNames=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --output text --query 'Subnets[*].AvailabilityZones'`
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $asgName --launch-configuration-name delaney-launch --availability-zones $subnetNames \
--load-balancer-names $elbName --max-size 5 --min-size 1 --desired-capacity 2



# Create AutoScaling Group from a running EC2 Instance
aws autoscaling create-scaling-group --auto-scaling-group-name delaney-asg-cli \
--instance-id i-7f12e649 \
--min-size 1 --max-size 2 --desired-capacity 2

# Add Tags to Existing AutoScaling Group
aws autoscaling create-or-update-tags --tags "ResourceId=my-asg,ResourceType=auto-scaling-group,Key=environment,Value=test,PropagateAtLaunch=true"
aws autoscaling describe-tags --filters Name=auto-scaling-group,Values=my-asg
aws autoscaling delete-tages --tags "ResourceId=my-asg,ResourceType=auto-scaling-group,Key=environment"


# Describe your AutoScaling Group
aws autoscaling describe-scaling-activities --auto-scaling-group-name delaney-launch

# Attach/Detach Load Balancer to AutoScaling Group
aws autoscaling attach-load-balancers --auto-scaling-group-name delaney-asg --load-balancer-names delaney-elb
aws autoscaling detach-load-balancers --auto-scaling-group-name delaney-asg --load-balancer-names delaney-elb

# Set AutoScaling Group capacity
aws autoscaling --auto-scaling-group-name delaney-asg --desired-capacity 6


# Add Subnet to your AutoScaling Group
aws autoscaling update-auto-scaling-group --auto-scaling-group-name delaney-asg --vpc-zone-identifier subnet-41767929 subnet-c663da2 --min-size 2

# Attach Region for you ELB
aws elb attach-load-balancer-to-subnets --load-balancer-name delaney-elb --subnets subnet-41767929 subnet-c663da2




# Create lifecycle hook on Startup


# Add Health Check to AutoScaling Group
aws autoscaling update-auto-scaling-group --auto-scaling-group-name delaney-asg --health-check-type ELB --health-check-grace-period 300


# Attach/Detach running EC2 instance to AutoScaling Group
aws autoscaling attach-instances --instance-ids i-a8d09d9c --auto-scaling-group-name delaney-asg
aws autoscaling detach-instances --instance-ids i-a8d09d9c --auto-scaling-group-name delaney-asg --should-decrement-desired-capacity

# Put Step Scaling Policy to AutoScaling Group
aws autoscaling put-scaling-policy --policy-name delaney-scale-policy --auto-scaling-group-name delaney-asg --scaling-adjustment 30 --adjustment-type PercentChangeInCapacity
aws autoscaling put-scaling-policy --policy-name delaney-scale-policy --auto-scaling-group-name delaney-asg --scaling-adjustment 30 --adjustment-type ChangeInCapacity
aws autoscaling put-scaling-policy --policy-name delaney-scale-policy --auto-scaling-group-name delaney-asg TargetTrackingScaling --target-tracking-configuration file://config.json


# AutoScaling Termination Polciy; tells how to terminate/start new instances
aws autoscaling update-auto-scaling-group --auto-scaling-group-name delaney-asg --termination-policies "OldestLaunchConfiguration,ClosestToNextInstanceHour"

# Update your AutoScaling Group with a new Launch Configuration
aws autoscaling update-auto-scaling-group --auto-scaling-group-name delaney-asg --launch-configuration-name delaney-launch

# CloudWatch Alarms for your AutoScaling Group for AddCapacity and RemoveCapacity
aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization \
--namespace AWS/EC2 --statistic Average --period 120 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold \
--dimensions "Name=AutoScalingGroupName,Value='delaney-asg" --evaluation-period 2 --alarm-actions PolicyARN

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization \
--namespace AWS/EC2 --statistic Average --period 120 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold \
--dimensions "Name=AutoScalingGroupName,Value='delaney-asg" --evaluation-period 2 --alarm-actions PolicyARN


# Create LifeCycle Hook
aws autoscaling put-lifecycle-hook --lifecycle-hook-name delaney-hook --autoscaling-group-name delaney-asg --lifecycle-transition autoscaling:EC2_INSTANCE_LAUNCHING
aws autoscaling put-lifecycle-hook --lifecycle-hook-name delaney-hook --autoscaling-group-name delaney-asg --lifecycle-transition autoscaling:EC2_INSTANCE_TERMINATING
# Set the Hook when in Pending
aws autoscaling complete-lifecycle-action --lifecycle-action-result CONTINUE --lifecycle-hook-name delaney-hook --auto-scaling-group-name delaney-asg \
--lifecycle-action-token xxxxxxxx  OR --instance-id i-xxxxx

# Remove then put back an Instance from AutoScaling Group, put into standby
aws autoscaling enter-standby --instance-id i-xxxxxx --auto-scaling-group-name delaney-asg --should-decrement-desired-capacity
aws autoscaling exit-standby --instance-id i-xxxxxx --auto-scaling-group-name delaney-asg

# Suspend AutoScaling Processs (Launch,Terminate,HealthCheck,ReplaceUnhealthy,AZRebalance,AlarmNotification,ScheduledActions,AddToLoadBalancer)
aws autoscaling suspend-processes --auto-scaling-group-name delaney-asg --scaling-processes AlarmNotification
aws autoscaling resume-processes --auto-scaling-group-name delaney-asg --scaling-processes AlarmNotification


# Delete AutoScaling Group and Launch Configuration
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name delaney-asg --force-delete
aws autoscaling delete-launch-configuration --launch-configuration-name delaney-launch
aws elb delete-load-balancer --load-balancer-name delaney-load-balancer
aws cloudwatch delete-alarms --alarm-name AddCapacity RemoveCapacity
