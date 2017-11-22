#!/bin/bash

echo "This will delete our AutoScaling Resources such as in the following order:"
echo "AutoScaling Group"
echo "Elastic Load Balancer"
echo "Launch Configuration"
echo "EC2 Instance created for Launch Configuration"
echo "Security Groups"


# delaneyskivt userid
export AWS_PROFILE=delaneyskivt

# Important variable names
keyPair=pdelaney
vpcName=Default-VPC
httpSgName=delaney-HTTP-SG
sshSgName=delaney-SSH-SG
elbName=delaney-ELB
nameTagValue=autoscaling-test
asgName=delaney-ASG
launchConfigName=delaney-launch


echo "###################################"
echo "##### Begin Deleting Resources #####"
echo "###################################"


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
aws ec2 terminate-instances --instance-ids $instanceIdThatsRunning
# Wait for instance to be terminated
echo "Wait for Instance to be terminated"
while state=$(aws ec2 describe-instances --instance-ids $instanceIdThatsRunning --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" != "terminated"; do
    echo -n . ; sleep 3;
done;
echo "Instance $instanceId terminated"



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


