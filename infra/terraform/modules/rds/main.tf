# RDS PostgreSQL with KMS Encryption
# Implements Tier 2 defensive controls

variable "environment" {}
variable "vpc_id" {}
variable "data_subnet_ids" {}

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "skin-lesion-db-subnet-${var.environment}"
  subnet_ids = var.data_subnet_ids

  tags = {
    Environment = var.environment
  }
}

# Security Group
resource "aws_security_group" "rds" {
  name        = "skin-lesion-rds-sg-${var.environment}"
  description = "Security group for RDS PostgreSQL - only allow ECS"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ECS tasks PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    source_security_group_id = aws_security_group.ecs.id
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = var.environment
  }
}

# ECS Security Group (reference for RDS SG)
resource "aws_security_group" "ecs" {
  name        = "skin-lesion-ecs-sg-${var.environment}"
  description = "ECS security group - used as source for RDS"
  vpc_id      = var.vpc_id

  tags = {
    Environment = var.environment
  }
}

# RDS Instance with encryption
resource "aws_db_instance" "main" {
  identifier = "skin-lesion-${var.environment}"

  engine            = "postgres"
  engine_version    = "15.3"
  instance_class    = "db.t3.medium"

  # Networking
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  # Credentials from Secrets Manager
  username = "skinlesionadmin"
  password = aws_secretsmanager_secret_version.db_password.secret_string

  # Storage
  allocated_storage     = 100
  max_allocated_storage = 200
  storage_type          = "gp3"
  storage_encrypted     = true

  # Backup
  multi_az                = true
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  # Monitoring
  monitoring_interval = 60
  performance_insights_enabled = true

  # Security
  publicly_accessible         = false
  auto_minor_version_upgrade  = true
  delete_automated_backups    = false

  tags = {
    Environment = var.environment
  }
}

# Secrets Manager secret for DB password
resource "aws_secretsmanager_secret" "db_password" {
  name = "skin-lesion/db-password-${var.environment}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = "CHANGE_ME_IN_prod_tfvars"  # Override in tfvars
}

output "instance_arn" {
  value = aws_db_instance.main.arn
}

output "instance_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "instance_port" {
  value = aws_db_instance.main.port
}
