variable "environment" {}
variable "cidr_block" {}
variable "availability_zones" {}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "skin-lesion-vpc-${var.environment}"
    Environment = var.environment
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "skin-lesion-igw-${var.environment}"
  }
}

# Public Subnets (ALB)
resource "aws_subnet" "public" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "skin-lesion-public-${count.index + 1}"
    Environment = var.environment
    Tier        = "Public"
  }
}

# App Subnets (ECS)
resource "aws_subnet" "app" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "skin-lesion-app-${count.index + 1}"
    Environment = var.environment
    Tier        = "App"
  }
}

# Data Subnets (RDS, Redis)
resource "aws_subnet" "data" {
  count             = 3
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 8)
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "skin-lesion-data-${count.index + 1}"
    Environment = var.environment
    Tier        = "Data"
  }
}

# NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "skin-lesion-nat-${var.environment}"
  }
}

# Route Tables
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "skin-lesion-public-rt-${var.environment}"
  }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "skin-lesion-app-rt-${var.environment}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count = 3
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "data" {
  count = 3
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.app.id
}

# S3 VPC Endpoint (for private S3 access from ECS)
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "s3.us-east-1.amazonaws.com"
  route_table_ids = [aws_route_table.app.id]

  tags = {
    Name = "skin-lesion-s3-vpce-${var.environment}"
  }
}

# Secrets Manager VPC Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id            = aws_vpc.main.id
  service_name      = "secretsmanager.us-east-1.amazonaws.com"
  security_group_ids = [aws_security_group.secretsmanager.id]
  subnet_ids        = aws_subnet.app[*].id

  tags = {
    Name = "skin-lesion-secretsmanager-vpce-${var.environment}"
  }
}

# Security Group for VPC Endpoints
resource "aws_security_group" "secretsmanager" {
  name        = "skin-lesion-secretsmanager-vpce-sg-${var.environment}"
  description = "Security group for Secrets Manager VPC Endpoint"
  vpc_id      = aws_vpc.main.id

  tags = {
    Environment = var.environment
  }
}

resource "aws_vpc_endpoint_security_group_rule" "secretsmanager" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.secretsmanager.id
  source_security_group_id = aws_security_group.secretsmanager.id
}

# Outputs
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "app_subnet_ids" {
  value = aws_subnet.app[*].id
}

output "data_subnet_ids" {
  value = aws_subnet.data[*].id
}

output "vpc_endpoint_id" {
  value = aws_vpc_endpoint.s3.id
}

output "nat_gateway_id" {
  value = aws_nat_gateway.main.id
}
