terraform {
  required_version = ">= 1.4.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

#####################
# VPC
#####################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "vpc-main"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"

  tags = {
    Name = "public-subnet"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}


#####################
# Security Group
#####################

# If using SSH and not using SSM
resource "aws_security_group" "ssh_only" {
  name        = "allow-ssh"
  description = "Allow SSH access from trusted IPs"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_public_ip}"]

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ssh-only-sg"
  }
}

#####################
# IAM Role for EC2
#####################

resource "aws_iam_role" "ec2_role" {
  name = "ec2-basic-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# Uncomment the block below and remove the security group rule for SSH if using SSM
#resource "aws_iam_role_policy_attachment" "ec2_ssm" {
#  role       = aws_iam_role.ec2_role.name
#  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
#}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-instance-profile"
  role = aws_iam_role.ec2_role.name
}

#####################
# EC2 Instance
#####################

data "aws_ami" "rhel8" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat official

  filter {
    name   = "name"
    values = ["RHEL-8.*_HVM-*-x86_64-*"]
  }
}

resource "aws_instance" "rhel8" {
  ami                    = data.aws_ami.rhel8.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  key_name = aws_key_pair.github_runner_pub_key.key_name

  user_data = <<-EOF
            #!/bin/bash
            dnf -y module enable python39
            dnf -y install python39 python39-pip python39-setuptools python39-dnf
            alternatives --set python3 /usr/bin/python3.9
            EOF

  tags = {
    Name = "rhel8-ec2"
    Environment = "production"
  }
}

output "rhel_public_ip" {
  value = aws_instance.rhel8.public_ip
}

output "ssh_user" {
  value = "ec2-user"
}
