#!/bin/bash

# Got this script from the ACloudGuru video showing how to hook CloudWatch Alarms up to AutoScaling Group
# XXXX need to get instance ami-id for linux.  Also need to get the ARN for the policy you are creating


# Create launch-config and autoscaling group
aws autoscaling create-launch-configuration --launch-configuration-name my-lc --image-id XXXXXX --instance-type m1.medium
 
aws autoscaling create-auto-scaling-group --auto-scaling-group-name my-asg --launch-configuration-name my-lc --max-size 5 --min-size 1 --availability-zones "us-east-1a"

# Create scale up and down policy 
# Note: PercentChangeInCapacity increases/decreases by 60 percent
aws autoscaling put-scaling-policy --policy-name my-scaleout-policy --auto-scaling-group-name my-asg --scaling-adjustment 60 --adjustment-type PercentChangeInCapacity

# Note: ChangeInCapacity simply increases/decreases by 2 for this example
aws autoscaling put-scaling-policy --policy-name my-scalein-policy --auto-scaling-group-name my-asg --scaling-adjustment -2 --adjustment-type ChangeInCapacity


# Create AddCapacity and RemoveCapacity CloudWatch Alarms attached to the two Scale Up and Down Policies
aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 \
--statistic Average --period 60 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold  \
--dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions XXXXXXX

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 \
--statistic Average --period 60 --threshold 40 --comparison-operator LessThanOrEqualToThreshold \
--dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions XXXXXXXXXX 


# Put SNS Notification for when new instance is launched
aws autoscaling put-notification-configuration --auto-scaling-group-name lab-as-group --topic-arn <XXXXXX> \
--notification-types autoscaling:EC2_INSTANCE_LAUNCH autoscaling:EC2_INSTANCE_TERMINATE




