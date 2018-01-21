#!/bin/sh

# Got this script from the ACloudGuru video showing how to hook CloudWatch Alarms up to AutoScaling Group
# XXXX need to get instance ami-id for linux.  Also need to get the ARN for the policy you are creating


aws autoscaling create-launch-configuration --launch-configuration-name my-lc --image-id XXXXXX --instance-type m1.medium
 
aws autoscaling create-auto-scaling-group --auto-scaling-group-name my-asg --launch-configuration-name my-lc --max-size 5 --min-size 1 --availability-zones "us-east-1a"

aws autoscaling put-scaling-policy --policy-name my-scaleout-policy --auto-scaling-group-name my-asg --scaling-adjustment 60 --adjustment-type PercentChangeInCapacity

aws autoscaling put-scaling-policy --policy-name my-scalein-policy --auto-scaling-group-name my-asg --scaling-adjustment -2 --adjustment-type ChangeInCapacity

aws cloudwatch put-metric-alarm --alarm-name AddCapacity --metric-name CPUUtilization --namespace AWS/EC2 \
--statistic Average --period 60 --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold  \
--dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions XXXXXXX

aws cloudwatch put-metric-alarm --alarm-name RemoveCapacity --metric-name CPUUtilization --namespace AWS/EC2 \
--statistic Average --period 60 --threshold 40 --comparison-operator LessThanOrEqualToThreshold \
--dimensions "Name=AutoScalingGroupName,Value=my-asg" --evaluation-periods 2 --alarm-actions XXXXXXXXXX 



