# serverfarm-with-terraform-
I used terraform to create multiple private and public servers in AWS.
Problem Statement 
Create a deployment of an EC2 instance using Terraform with Specific Parameters: T2.Micro 12GB Storage London Region Access to SSH and RDP from a single IP address Address to https from anywhere
Solution 
#1 Create VPC 
#2 Create IGW 
#3 Create a Public Route Table 
#4 Create a Public Subnet 
#5 Associate the Public Subnet with Public Route Table 
#6 Create Security Group 
#7 Create ENI within the public subnet 
#8 Assign an EIP to the ENI @ #7 
#9 Launch an EC2 instance.
