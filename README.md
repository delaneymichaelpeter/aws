Contains AWS artifacts to create AutoScaling Group with a Elastic Load Balancer
================================================================================

### Script ToDo:
* Before trying to delete AutoScaling Group need to make sure that no Instances are in Pending State or are all RUNNING 
* Create CloudWatch Alarm to Scale Out when Percent at 35%.  
* Create CloudWatch Alarm for Scale Out to send email to delaneymichaelpeter
* Delete the Policy and CloudWatch Alarms in delete script
* Need AutoScaling Policy at the Elastic Load Balancer also, want it to scale on that using Bees with Machine Guns
* When deleting resources, need to wait for all of the instances to be in terminated state  because you won't be able to delete the security groups until then
* Turn CloudWatch to Warn AutoScaling Group


### Python ToDo:
* Start building the python script to do the same

### CloudFormation ToDo:
* Build Cloud Formation template to do the same

### REST API ToDo:
* See if can build a Postman script to build out the resources.


### GO ToDo:
* Try building same artifacts using GO
