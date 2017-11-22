#!/bin/bash

echo "Building Environment SecurityGroup ELB with AutoScaling"


# delaneyskivt userid
export AWS_PROFILE=delaneyskivt

# Important variable names
keyPair=pdelaney
vpcName=Default-VPC
httpSgName=delaney-HTTP-SG
sshSgName=delaney-SSH-SG
elbName=delaney-ELB
nameTagValue=autoscaling-test

# Important that this exist in the VPC/Region 
autoscalingHooksRoleProfile="arn:aws:iam::213240414725:instance-profile/AutoScaling_Hooks_Role"

myIp=$(curl -sS http://checkip.amazonaws.com/)
echo "MY IP : $myIp"


# Get the Default VPC; assumes have one and default is the first returned.  NOT GOOD
vpcId=`aws ec2 describe-vpcs --output text --query 'Vpcs[0].VpcId'`
echo "Using VPC : $vpcId"


# Create Security Group for HTTP and SSH
httpSgId=`aws ec2 create-security-group --group-name $httpSgName --description "Security to allow HTTP traffic" --vpc-id $vpcId --output text --query 'GroupId'`
aws ec2 create-tags --resources $httpSgId --tags Key=Name,Value="HTTP to EC2"
aws ec2 authorize-security-group-ingress --group-name $httpSgName --protocol tcp --port 80 --cidr 0.0.0.0/0
echo "Http Security Group : $httpSgId"


# Create SSH
sshSgId=`aws ec2 create-security-group --group-name $sshSgName --description "Allows SSH to box" --vpc-id $vpcId --output text --query 'GroupId'`
aws ec2 create-tags --resources $sshSgId --tags Key=Name,Value="SSH to EC2"
aws ec2 authorize-security-group-ingress --group-name $sshSgName --protocol tcp --port 22 --cidr 0.0.0.0/0
#aws ec2 authorize-security-group-ingress --group-name $sshSgName --protocol tcp --port 22 --cidr $myIp/32
echo "SSH Security Group : $sshSgId"


# Create Load Balancer
subnetIds=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --output text --query 'Subnets[*].SubnetId'`
subnetId=`aws ec2 describe-subnets --filters Name=vpc-id,Values=$vpcId --output text --query 'Subnets[0].SubnetId'`
elbDnsName=`aws elb create-load-balancer --load-balancer-name $elbName --listeners "Protocol=HTTP,LoadBalancerPort=80,InstanceProtocol=HTTP,InstancePort=80" --subnets $subnetIds --security-groups $httpSgId --output text --query 'DNSName'`
echo "ELB DNS Name : $elbDnsName"


# Create Instance that will be our launch configuration
instanceType=t2.micro
aZone=us-east-1a
imageId=ami-6057e21a

instanceId=`aws ec2 run-instances --image $imageId --key $keyPair --security-group-ids $sshSgId $httpSgId --count 1 --instance-type $instanceType --user-data file://user_data.txt --subnet-id $subnetId --output text --query 'Instances[*].InstanceId'`
echo "Create EC2 Instance : $instanceId for Launch Configuration"
aws ec2 create-tags --resources $instanceId --tags Key=Name,Value="launch-config-instance"

# Waiting for instance to be  running state to can create launch-configuration
echo "Waiting for Instance to be running to create launch configuration" 
while state=$(aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "pending"; do
    echo -n . ; sleep 3;
done;
echo "Instance State $state"

# Create Launch Configuration from EC2 and Override Instance Type
launchConfigName=delaney-launch
aws autoscaling create-launch-configuration --launch-configuration-name $launchConfigName --instance-id $instanceId --instance-type $instanceType --iam-instance-profile $autoscalingHooksRoleProfile

# Describe your launch configuration
echo "#############################################"
echo "Created Launch Configuration : $launchConfigName"
aws autoscaling describe-launch-configurations --launch-configuration-names $launchConfigName
echo "#############################################"


# Create AutoScaling Group
asgName=delaney-ASG
asgPolicyUp=delaney-PolicyUp
asgPolicyDown=delaney-PolicyDown

subnetNames=`aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --output text --query 'Subnets[*].AvailabilityZone'`
echo "subnet Names : $subnetNames"
# only takes one subnet, not sure why
subnetIds=`aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --output text --query 'Subnets[*].SubnetId'`
firstSubnetId=`aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --output text --query 'Subnets[0].SubnetId'`
echo "subnet ids : $firstSubnetId"

# Go to sleep seems to have problems
sleep 10; 
aws autoscaling create-auto-scaling-group --auto-scaling-group-name $asgName --launch-configuration-name $launchConfigName --vpc-zone-identifier $firstSubnetId --load-balancer-names $elbName --max-size 2 --min-size 1 --desired-capacity 1 --health-check-type ELB --health-check-grace-period 30
echo "Created AutoScaling Group : $asgName"

# Add Availability Zones to AutoScaling
aws autoscaling update-auto-scaling-group --auto-scaling-group-name $asgName --launch-configuration-name $launchConfigName --vpc-zone-identifier $subnetIds --max-size 2 --min-size 1 --desired-capacity 1
echo "Added Subnets to Availability Zone"



# Assign Tags to instances that autoscaling creates
aws autoscaling create-or-update-tags --tags "ResourceId=$asgName,ResourceType=auto-scaling-group,Key=environment,Value=autoscale-testing,PropagateAtLaunch=true"

# Add a Scale Up Policy to AutoScaling Group
aws autoscaling put-scaling-policy --auto-scaling-group-name $asgName --policy-name $asgPolicyUp --adjustment-type ChangeInCapacity --scaling-adjustment 1 --cooldown 150
echo "Create AutoScaling Up Policy : $asgPolicyUp"

aws autoscaling put-scaling-policy --auto-scaling-group-name $asgName --policy-name $asgPolicyDown --adjustment-type ChangeInCapacity --scaling-adjustment -1 --cooldown 150
echo "Create AutoScaling Up Policy : $asgPolicyUp"


# Create lifecycle hook on LAUNCH
launchHookName=delaney-launch-hook
aws autoscaling put-lifecycle-hook --lifecycle-hook-name $launchHookName --auto-scaling-group-name $asgName --lifecycle-transition autoscaling:EC2_INSTANCE_LAUNCHING
echo "Created LifeCycle Hook : $launchHookName"

read -e -p "Delete Created Resources? [Y/N]:" answer
if [ $answer == 'n' ] || [ $answer == 'N' ]
then
    echo "Existing Script";
    exit 1
fi
    



echo "###################################"
echo "##### Begin Deleting Resources #####"
echo "###################################"

# TODO need to determine if any AutoScaling activities are in play because if they are won't be able to delete the AutoScaling Group

echo "Delete AutoScaling Group : $launchName"
aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $asgName
sleep 3;


echo "Deleted Load Balancer : $elbName"
aws elb delete-load-balancer  --load-balancer-name $elbName
echo "Deleted ELB $elbName : $elbName"
sleep 3;


echo "Delete AutoScaling Launch Configuration : $launchName"
aws autoscaling delete-launch-configuration --launch-configuration-name $launchConfigName


echo "Instance State $state"
instanceIdThatsRunning=`aws ec2 describe-instances --output text --query "Reservations[*].Instances[*].InstanceId" --filters "Name=instance-state-name,Values=running"`
echo "Instances that are running : $instanceIdThatsRunning"

# Delete Resources thus far sleep/wait for resources to get established
aws ec2 terminate-instances --instance-ids $instanceId
# Wait for instance to be terminated
echo "Wait for Instance to be terminated"
while state=$(aws ec2 describe-instances --instance-ids $instanceId --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" != "terminated"; do
    echo -n . ; sleep 3;
done;
echo "Instance $instanceId terminated"



# Detach Network Interface for the SSH Security Group
#networkInterfaceForSSH=`aws ec2 describe-network-interfaces --filters Name=group-name,Values=$sshSgName --output text --query "NetworkInterfaces[*].NetworkInterfaceId"`
#networkInterfaceAttachmentId=`aws ec2 describe-network-interfaces --filters Name=group-name,Values=$sshSgName --output text --query "NetworkInterfaces[*].Attachment.AttachmentId"`
#echo "Detach Network Interface $networkInterfaceAttachmentId"
#aws ec2 detach-network-interface --attachment-id $networkInterfaceAttachmentId

#sleep 10;
# Wait for network interface to be out of use
#httpNetworkId=`aws ec2 describe-network-interfaces --query "NetworkInterfaces[*].NetworkInterfaceId" --filters "Name=group-name,Values=$httpSgName --output text"`
#echo "Waiting for Network Interface to be out of use "
#while state=$(aws ec2 describe-network-interfaces --network-interface-ids $httpNetworkId --output text --query 'NetworkInterfaces[*].Attachment.Status'); test "$state" = "in-use"; do
#    echo -n . ; sleep 3;
#done;
#echo "Network Interface : $httpNetworkId no longer in use delete HTTP Security Group"

aws ec2 delete-security-group --group-name $httpSgName
echo "Deleted Security Group : $httpSgName"


sshNetworkId=`aws ec2 describe-network-interfaces --query "NetworkInterfaces[*].NetworkInterfaceId" --filters "Name=group-name,Values=$sshSgName --output text"`
echo "Waiting for Network Interface to be out of use "
while state=$(aws ec2 describe-network-interfaces --network-interface-ids $httpNetworkId --output text --query 'NetworkInterfaces[*].Attachment.Status'); test "$state" = "in-use"; do
    echo -n . ; sleep 3;
done;
echo "Network Interface : $sshNetworkId no longer in use delete SSH Security Group"


aws ec2 delete-security-group --group-name $sshSgName
echo "Deleted Security Group : $sshSgName"


# Stop Here
exit 1



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



# Add Health Check to AutoScaling Group
aws autoscaling update-auto-scaling-group --auto-scaling-group-name delaney-asg --health-check-type ELB --health-check-grace-period 300


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
