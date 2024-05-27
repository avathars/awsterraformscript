terraform {
  backend "s3" {
    bucket = "devopsterrafo"
    key    = "devops.tfstate"
    region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidrm
}

# Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "internetgateway"
  }
}


# Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr1
  availability_zone = "ap-south-1a"
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr2
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private"
  }
}
resource "aws_subnet" "rds_private_subnet" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.cidr3
  availability_zone = "ap-south-1b"
  tags = {
    Name = "rds_private"
  }
}

# Security Groups
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow inbound traffic
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.cidr_block]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidr_block]
  }
  tags = {
    Name = "ec2securitygroup"
  }
}
# Security Groups rds
resource "aws_security_group" "rds_sg" {
  vpc_id = aws_vpc.my_vpc.id

  # Allow inbound traffic
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.cidrm]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.cidrm]
  }
  tags = {
    Name = "rds2securitygroup"
  }
}

# Route Table for Public Subnet
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = var.cidr_block
    gateway_id = aws_internet_gateway.my_igw.id
  }
}

# Associate Route Table with Public Subnet
resource "aws_route_table_association" "public_route_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# NAT Gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  depends_on = [aws_internet_gateway.my_igw]
  tags = {
    Name = "nat_gateway"
  }
}

resource "aws_eip" "my_eip" {
  domain = "vpc"
  tags = {
    Name = "my_eip"
  }
}


# Route Table for Private Subnet
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "rtprivatesubnet"
  }
}

# Route for Private Subnet to NAT Gateway
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = var.cidr_block
  nat_gateway_id         = aws_nat_gateway.my_nat_gateway.id
}

# Associate Route Table with Private Subnet
resource "aws_route_table_association" "private_route_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  tags = {
    Name = "web"
  }
}

# S3 Bucket
resource "aws_s3_bucket" "example_bucket" {
  bucket_prefix = "example-"
  tags = {
    Name = "s3_bucket"
  }
}

# RDS Instance
resource "aws_db_instance" "example_db" {
  allocated_storage      = 20
  engine                 = "mysql"
  instance_class         = var.instance_class
  username               = var.username
  password               = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.example.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  tags = {
    Name = "rds_db"
  }
}

# RDS Subnet Group
resource "aws_db_subnet_group" "example" {
  name       = "example-subnet-group"
  subnet_ids = [aws_subnet.private_subnet.id, aws_subnet.rds_private_subnet.id]
}

#creating vpc endpoint
resource "aws_ec2_instance_connect_endpoint" "webcon" {
  subnet_id = aws_subnet.private_subnet.id
  tags = {
    Name = "connect_endpoint"
  }
}
