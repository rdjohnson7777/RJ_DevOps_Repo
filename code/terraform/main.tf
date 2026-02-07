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
    cidr_blocks = ["${var.my_public_ip}/32"]

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

resource "aws_instance" "linux" {
  ami                    = "ami-0a3c3a20c09d6f377"
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh_only.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "linux-ec2"
    Environment = "dev"
  }
}

output "rhel_public_ip" {
  value = aws_instance.linux.public_ip
}

output "ssh_user" {
  value = "ec2-user"
}
