# Create VPC
resource "aws_vpc" "bello-vpc" {
  cidr_block       = "50.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "bello-vpc"
  }
}

#2 Create IGW
resource "aws_internet_gateway" "bello-igw" {
  vpc_id = aws_vpc.bello-vpc.id

  tags = {
    Name = "bello-igw"
  }
}

#3 Create a  Public Route Table
resource "aws_route_table" "bello_pubrt" {
  vpc_id = aws_vpc.bello-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.bello-igw.id
  }

#   route {
#     ipv6_cidr_block        = "::/0"
#     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
#   }

  tags = {
    Name = "bello_pubrt"
  }
}

#3b Create a  Private Route Table
resource "aws_route_table" "bello_privrt" {
  vpc_id = aws_vpc.bello-vpc.id

  route {
    cidr_block = "0.0.0.0/0" 
    gateway_id = aws_nat_gateway.bello-natgw.id
  }

#   route {
#     ipv6_cidr_block        = "::/0"
#     egress_only_gateway_id = aws_egress_only_internet_gateway.example.id
#   }

  tags = {
    Name = "bello_privrt"
  }
}

#4 Create a Public Subnet
resource "aws_subnet" "bello-pubsn-2a" {
  vpc_id     = aws_vpc.bello-vpc.id
  cidr_block = "50.0.0.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "bello-pubsn-2a"
  }
}

#4 Create a Private Subnet
resource "aws_subnet" "bello-privsn-2a" {
  vpc_id     = aws_vpc.bello-vpc.id
  cidr_block = "50.0.1.0/24"
  availability_zone = "eu-west-2a"

  tags = {
    Name = "bello-privsn-2a"
  }
}

#5 Associate the Public Subnet with Public Route Table
resource "aws_route_table_association" "ass-1" {
  subnet_id      = aws_subnet.bello-pubsn-2a.id
  route_table_id = aws_route_table.bello_pubrt.id
}

#5 Associate the Private Subnet with Private Route Table
resource "aws_route_table_association" "ass-2" {
  subnet_id      = aws_subnet.bello-privsn-2a.id
  route_table_id = aws_route_table.bello_privrt.id
}

#6 Create Security Group
resource "aws_security_group" "bello-sg" {
  name        = "bello-sg"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.bello-vpc.id

  tags = {
    Name = "bello-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "allow_ssh" {
  security_group_id = aws_security_group.bello-sg.id
  cidr_ipv4         = "197.168.100.5/32"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "allow_rdp" {
  security_group_id = aws_security_group.bello-sg.id
  cidr_ipv4         = "197.168.100.5/32" 
  from_port         = 3389
  ip_protocol       = "tcp"
  to_port           = 3389
}

resource "aws_vpc_security_group_ingress_rule" "allow_https" {
  security_group_id = aws_security_group.bello-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  ip_protocol       = "tcp"
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "allow_all" {
  security_group_id = aws_security_group.bello-sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

#7 Create ENI within the public subnet
resource "aws_network_interface" "bello-eni" {
  subnet_id       = aws_subnet.bello-pubsn-2a.id
  private_ips     = ["50.0.0.4"]
  security_groups = [aws_security_group.bello-sg.id]

  # attachment {
  #   instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

#8 Assign an EIP to the ENI @ #7
resource "aws_eip" "bello-eip-1" {
  domain                    = "vpc"
  network_interface         = aws_network_interface.bello-eni.id
  associate_with_private_ip = "50.0.0.4"
}

# Create NAT-GW for private route table
resource "aws_nat_gateway" "bello-natgw" {
  allocation_id = aws_eip.bello-eip-2.id
  subnet_id     = aws_subnet.bello-pubsn-2a.id

  tags = {
    Name = "bello-natgw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.bello-igw]
}

# Allocate the Elastic IP (EIP) for NATGW
resource "aws_eip" "bello-eip-2" {
  domain = "vpc"
}

