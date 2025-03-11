//https://dev.betterdoc.org/infrastructure/2020/02/04/setting-up-a-nat-gateway-on-aws-using-terraform.html
// building a VPC, private and public subnets with an EC2 instance in the private subnet
// a bastion host, NAT and Internet gateway in the public subnet

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
      "Name" = "dummy"
    }
}

resource "aws_subnet" "instance" {
  availability_zone = data.aws_availability_zones.available.names[0]
  cidr_block = "10.0.1.0/24"
  vpc_id = aws_vpc.vpc.id
  tags = {
    "Name" = "DummySubnetInstance"
  }
}

resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "aws_key_pair" "ssh" {
  key_name = "DummyMachine"
  public_key = tls_private_key.ssh.public_key_openssh
}

resource "aws_security_group" "securitygroup" {
  name = "DummySecurityGroup"
  description = "DummySecurityGroup"
  vpc_id = aws_vpc.vpc.id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
  tags = {
    "Name" = "DummySecurityGroup"
  }
}

resource "aws_instance" "ec2instance" {
  instance_type = "t2.micro"
  ami = "ami-0f0a0e45a2a62b229" # https://cloud-images.ubuntu.com/locator/ec2/ (Ubuntu) - Oracular Oriole, 24.10 gp3
  subnet_id = aws_subnet.instance.id
  security_groups = [aws_security_group.securitygroup.id]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = "10"
  }
  tags = {
    "Name" = "DummyMachine"
  }
}

# public subnet

resource "aws_subnet" "nat_gateway" {
    availability_zone = data.aws_availability_zones.available.names[0]
    cidr_block = "10.0.2.0/24"
    vpc_id = aws_vpc.vpc.id
    tags = {
      "Name" = "DummySubnetNAT"
    }
}

resource "aws_internet_gateway" "nat_gateway" {
    vpc_id = aws_vpc.vpc.id
    tags = {
      "Name" = "DummyGateway"
    }
}

// NAT gateway for private/public subnet translation
resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "nat_gateway" {
    subnet_id = aws_subnet.nat_gateway.id
    route_table_id = aws_route_table.nat_gateway.id
}

resource "aws_eip" "nat_gateway" {}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_gateway.id
  subnet_id = aws_subnet.nat_gateway.id
  tags = {
    "Name" = "DummyNatGateway"
  }
}

resource "aws_route_table" "instance" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "instance" {
  subnet_id = aws_subnet.instance.id
  route_table_id = aws_route_table.instance.id
}

// ec2 instance now inside private network - jump box to test

resource "aws_instance" "ec2jumphost" {
  instance_type = "t2.micro"
  ami = "ami-0f0a0e45a2a62b229"
  subnet_id = aws_subnet.nat_gateway.id
  security_groups = [ aws_security_group.securitygroup.id ]
  key_name = aws_key_pair.ssh.key_name
  disable_api_termination = false
  ebs_optimized = false
  root_block_device {
    volume_size = 10
  }
  tags = {
    "Name" = "DummyMachineJumphost"
  }
}

resource "aws_eip" "jumphost" {
  instance = aws_instance.ec2jumphost.id
}