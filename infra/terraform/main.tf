terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ============================================================
# Tier 1: Critical Priority
# ============================================================

# VPC with 3-tier subnet design
module "vpc" {
  source = "./modules/vpc"

  environment      = var.environment
  cidr_block       = var.vpc_cidr
  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Cognito with MFA enforced for doctors/admins
module "cognito" {
  source = "./modules/cognito"

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
}

# S3 Training Bucket with VPC endpoint restriction and MFA delete
module "s3_training" {
  source = "./modules/s3-training"

  environment      = var.environment
  vpc_id          = module.vpc.vpc_id
  vpc_endpoint_id = module.vpc.vpc_endpoint_id
  account_id      = var.account_id
}

# GuardDuty for threat detection
module "guardduty" {
  source = "./modules/guardduty"

  environment = var.environment
}

# ============================================================
# Tier 2: High Priority
# ============================================================

# ECS Task Role with least privilege
module "ecs_task_role" {
  source = "./modules/ecs-task-role"

  environment     = var.environment
  s3_training_arn = module.s3_training.bucket_arn
  cognito_pool_arns = {
    patient = module.cognito.patient_pool_arn
    doctor  = module.cognito.doctor_pool_arn
  }
}

# RDS PostgreSQL with KMS encryption
module "rds" {
  source = "./modules/rds"

  environment      = var.environment
  vpc_id          = module.vpc.vpc_id
  data_subnet_ids = module.vpc.data_subnet_ids
}

# CloudTrail with centralized logging
module "cloudtrail" {
  source = "./modules/cloudtrail"

  environment = var.environment
}

# VPC Flow Logs to CloudWatch
module "vpc_flow_logs" {
  source = "./modules/vpc-flow-logs"

  environment     = var.environment
  vpc_id         = module.vpc.vpc_id
}

# ============================================================
# Tier 3: Medium Priority
# ============================================================

# WAF with rate limiting
module "waf" {
  source = "./modules/waf"

  environment = var.environment
}

# Secrets Manager with rotation
module "secrets_manager" {
  source = "./modules/secrets-manager"

  environment = var.environment
  db_username = var.db_username
}

# KMS Key for RDS encryption
module "kms" {
  source = "./modules/kms"
  description = "KMS key for RDS encryption - Skin Lesion Platform"
}

# S3 Bucket for CloudTrail logs
module "s3_logging" {
  source = "./modules/s3-logging"

  environment = var.environment
  bucket_prefix = "skin-lesion-cloudtrail"
}

# ECS Cluster
module "ecs" {
  source = "./modules/ecs"

  environment    = var.environment
  vpc_id        = module.vpc.vpc_id
  app_subnet_ids = module.vpc.app_subnet_ids
}

# Application Load Balancer
module "alb" {
  source = "./modules/alb"

  environment       = var.environment
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
}

# ============================================================
# Variables
# ============================================================

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev/staging/prod)"
  type        = string
  default     = "prod"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "skinlesionadmin"
}

variable "db_password" {
  description = "Database password (use Secrets Manager in production)"
  type        = string
  sensitive   = true
}

variable "pagerduty_webhook_arn" {
  description = "PagerDuty SNS webhook ARN for alerts"
  type        = string
  default     = ""
}

# ============================================================
# Outputs
# ============================================================

output "vpc_id" {
  description = "VPC ID"
  value      = module.vpc.vpc_id
}

output "cognito_patient_pool_id" {
  description = "Cognito Patient User Pool ID"
  value      = module.cognito.patient_pool_id
}

output "cognito_doctor_pool_id" {
  description = "Cognito Doctor User Pool ID"
  value      = module.cognito.doctor_pool_id
}

output "cognito_doctor_pool_client_id" {
  description = "Cognito Doctor User Pool Client ID"
  value      = module.cognito.doctor_pool_client_id
}

output "s3_training_bucket" {
  description = "S3 Training Bucket Name"
  value      = module.s3_training.bucket_name
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value      = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "ALB DNS Name"
  value      = module.alb.dns_name
}

output "rds_endpoint" {
  description = "RDS Instance Endpoint"
  value      = module.rds.instance_endpoint
}

output "rds_port" {
  description = "RDS Instance Port"
  value      = module.rds.instance_port
}

output "ecs_execution_role_arn" {
  description = "ECS Task Execution Role ARN"
  value      = module.ecs_task_role.execution_role_arn
}

output "ecs_task_role_arn" {
  description = "ECS Task Role ARN"
  value      = module.ecs_task_role.task_role_arn
}
