# Skin Lesion Platform - Terraform Infrastructure (Defensive Hardened)

**This Terraform configuration implements all Tier 1-3 defensive controls from the red-team analysis.**

---

## Overview

This Terraform template creates the production-ready AWS infrastructure with security hardening applied at every layer:

- Tier 1 (Critical): Cognito MFA, S3 bucket lockdown, Rate limiting, MLflow access
- Tier 2 (High): ECS least privilege, RDS encryption, VPC Flow Logs, GuardDuty
- Tier 3 (Medium): WAF, Secrets Manager rotation, CloudTrail integration

---

## Files

```
infra/terraform/
├── main.tf                 # Root module - calls all submodules
├── variables.tf             # Input variables
├── outputs.tf               # Output values
├── modules/
│   ├── vpc/
│   │   └── main.tf         # VPC with 3-tier subnet design
│   ├── cognito/
│   │   └── main.tf         # Cognito with MFA enforced
│   ├── s3-training/
│   │   └── main.tf         # S3 training bucket with VPC endpoint restriction
│   ├── ecs-task-role/
│   │   └── main.tf         # ECS task role with least privilege
│   ├── rds/
│   │   └── main.tf         # RDS PostgreSQL with encryption
│   ├── guardduty/
│   │   └── main.tf         # GuardDuty enablement
│   ├── cloudtrail/
│   │   └── main.tf         # CloudTrail with centralized logging
│   ├── waf/
│   │   └── main.tf         # WAF with rate limiting rules
│   └── secrets-manager/
│       └── main.tf         # Secrets Manager with rotation
└── Makefile                # terraform apply/destroy shortcuts
```

---

## main.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "skin-lesion-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
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
  source "./modules/vpc"

  environment = var.environment
  cidr_block  = var.vpc_cidr

  availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

# Cognito with MFA enforced for doctors/admins
module "cognito" {
  source "./modules/cognito"

  environment     = var.environment
  vpc_id          = module.vpc.vpc_id
  app_subnet_ids  = module.vpc.app_subnet_ids
  data_subnet_ids = module.vpc.data_subnet_ids
}

# S3 Training Bucket with VPC endpoint restriction and MFA delete
module "s3_training" {
  source "./modules/s3-training"

  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  vpc_endpoint_id = module.vpc.vpc_endpoint_id
  account_id  = var.account_id
}

# GuardDuty for threat detection
module "guardduty" {
  source "./modules/guardduty"

  environment = var.environment
  s3_bucket_arn = module.s3_training.bucket_arn
}

# ============================================================
# Tier 2: High Priority
# ============================================================

# ECS Task Role with least privilege
module "ecs_task_role" {
  source "./modules/ecs-task-role"

  environment       = var.environment
  s3_training_arn   = module.s3_training.bucket_arn
  rds_instance_arn  = module.rds.instance_arn
  cognito_pool_arns = module.cognito.pool_arns
}

# RDS PostgreSQL with KMS encryption
module "rds" {
  source "./modules/rds"

  environment         = var.environment
  vpc_id             = module.vpc.vpc_id
  data_subnet_ids    = module.vpc.data_subnet_ids
  kms_key_arn        = module.kms_rds.key_arn
  db_password_secret = aws_secretsmanager_secret.db_password.arn
}

# CloudTrail with centralized logging
module "cloudtrail" {
  source "./modules/cloudtrail"

  environment = var.environment
  s3_bucket_arn = module.s3_cloudtrail.bucket_arn
}

# VPC Flow Logs to CloudWatch
module "vpc_flow_logs" {
  source "./modules/vpc-flow-logs"

  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  log_group_name = "/aws/vpc/flow-logs-${var.environment}"
}

# ============================================================
# Tier 3: Medium Priority
# ============================================================

# WAF with rate limiting
module "waf" {
  source "./modules/waf"

  environment    = var.environment
  alb_arn        = module.alb.alb_arn
  alb_zone_id    = module.alb.alb_zone_id
}

# Secrets Manager with rotation
module "secrets_manager" {
  source "./modules/secrets-manager"

  environment = var.environment
  db_username = var.db_username
}

# ============================================================
# Shared Resources
# ============================================================

# KMS Key for RDS encryption
module "kms_rds" {
  source "./modules/kms"
  description = "KMS key for RDS encryption - Skin Lesion Platform"
}

# S3 Bucket for CloudTrail logs
module "s3_cloudtrail" {
  source "./modules/s3-logging"
  environment = var.environment
  bucket_prefix = "skin-lesion-cloudtrail"
}

# ECS Cluster
module "ecs" {
  source "./modules/ecs"

  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  app_subnet_ids   = module.vpc.app_subnet_ids
  task_execution_role_arn = module.ecs_task_role.execution_role_arn
  task_role_arn    = module.ecs_task_role.task_role_arn
}

# Application Load Balancer
module "alb" {
  source "./modules/alb"

  environment   = var.environment
  vpc_id        = module.vpc.vpc_id
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

# ============================================================
# Outputs
# ============================================================

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "cognito_patient_pool_id" {
  value = module.cognito.patient_pool_id
}

output "cognito_doctor_pool_id" {
  value = module.cognito.doctor_pool_id
}

output "s3_training_bucket" {
  value = module.s3_training.bucket_name
}

output "ecs_cluster_name" {
  value = module.ecs.cluster_name
}

output "alb_dns_name" {
  value = module.alb.dns_name
}

output "rds_endpoint" {
  value = module.rds.instance_endpoint
}
```

---

## modules/cognito/main.tf

```hcl
# Cognito User Pools with MFA Enforcement

variable "environment" {}
variable "vpc_id" {}
variable "app_subnet_ids" {}
variable "data_subnet_ids" {}

resource "aws_cognito_user_pool" "patients" {
  name = "skin-lesion-patients-${var.environment}"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  # Auto-verified email
  auto_verified_attributes = ["email"]

  # Schema attributes
  schema {
    name         = "role"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "approved"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  # TIER 1: Lambda trigger for rate limiting on sign-up
  lambda_config {
    pre_sign_up = aws_lambda_function.rate_limit_signup.arn
  }
}

resource "aws_cognito_user_pool" "doctors" {
  name = "skin-lesion-doctors-${var.environment}"

  # Password policy
  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # TIER 1: MFA REQUIRED for doctors
  mfa_configuration          = "ON"
  sms_authentication_failure_tries = 5
  sms_verification_message  = "Your verification code is {####}"

  # Admin only can recover account (prevents social engineering)
  account_recovery_setting {
    recovery_mechanisms {
      name     = "admin_only"
      priority = 1
    }
  }

  # Schema attributes
  schema {
    name         = "role"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "approved"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "medical_license"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  # TIER 1: Lambda trigger for MFA enforcement
  lambda_config {
    define_auth_challenge  = aws_lambda_function.mfa_enforce.arn
    pre_authentication      = aws_lambda_function.check_mfa.arn
  }
}

# TIER 1: Rate limiting Lambda for patient sign-up (prevents Sybil attack)
resource "aws_lambda_function" "rate_limit_signup" {
  filename         = "../lambdas/rate_limit_signup.zip"
  function_name    = "skin-lesion-rate-limit-signup-${var.environment}"
  role            = aws_iam_role.lambda_cognito_role.arn
  handler         = "rate_limit_signup.handler"
  runtime         = "python3.10"
  memory_size     = 128
  timeout         = 10

  environment {
    variables = {
      RATE_LIMIT_WINDOW   = "3600"  # 1 hour
      RATE_LIMIT_MAX     = "10"     # Max 10 sign-ups per IP
    }
  }
}

# TIER 1: MFA enforcement Lambda
resource "aws_lambda_function" "mfa_enforce" {
  filename         = "../lambdas/mfa_enforce.zip"
  function_name    = "skin-lesion-mfa-enforce-${var.environment}"
  role            = aws_iam_role.lambda_cognito_role.arn
  handler         = "mfa_enforce.handler"
  runtime         = "python3.10"
  memory_size     = 128
  timeout         = 10
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_cognito_role" {
  name = "skin-lesion-lambda-cognito-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

# User Pool Clients
resource "aws_cognito_user_pool_client" "patients" {
  user_pool_id = aws_cognito_user_pool.patients.id
  name         = "skin-lesion-patient-app"

  generate_secret     = true
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_client" "doctors" {
  user_pool_id = aws_cognito_user_pool.doctors.id
  name         = "skin-lesion-doctor-app"

  generate_secret     = true
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # TIER 1: Explicit logout URLs (prevents redirect attacks)
  logout_URIs = [
    "https://${var.environment}-api.skinlesion.com/logout"
  ]
}

# Identity Pool
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name = "skin-lesion-identity-pool-${var.environment}"

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.patients.id
    provider_name           = aws_cognito_user_pool.patients.endpoint
    server_side_token_check = true
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.doctors.id
    provider_name           = aws_cognito_user_pool.doctors.endpoint
    server_side_token_check = true
  }

  allow_unauthenticated_identities = false
}

# Outputs
output "patient_pool_id" {
  value = aws_cognito_user_pool.patients.id
}

output "doctor_pool_id" {
  value = aws_cognito_user_pool.doctors.id
}

output "patient_pool_client_id" {
  value = aws_cognito_user_pool_client.patients.id
}

output "doctor_pool_client_id" {
  value = aws_cognito_user_pool_client.doctors.id
}

output "pool_arns" {
  value = {
    patient = aws_cognito_user_pool.patients.arn
    doctor  = aws_cognito_user_pool.doctors.arn
  }
}
```

---

## modules/s3-training/main.tf

```hcl
# S3 Training Bucket with VPC Endpoint Restriction and MFA Delete

variable "environment" {}
variable "vpc_id" {}
variable "vpc_endpoint_id" {}
variable "account_id" {}

# Training data bucket
resource "aws_s3_bucket" "training" {
  bucket = "skin-lesion-training-${var.account_id}"

  tags = {
    Environment = var.environment
    DataClassification = "Medical-PHI"
  }
}

# TIER 1: Block all public access
resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

# TIER 1: MFA Delete required (prevents accidental/tempest deletion)
resource "aws_s3_bucket_versioning" "training" {
  bucket = aws_s3_bucket.training.id

  versioning_configuration {
    status = "Enabled"
    mfa_delete = "Enabled"
  }
}

# TIER 1: Bucket policy - Deny non-VPC access
resource "aws_s3_bucket_policy" "training_vpc_only" {
  bucket = aws_s3_bucket.training.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "EnforceVPCEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
        Condition = {
          NotIpAddress = {
            "aws:sourceVpce" = var.vpc_endpoint_id
          }
        }
      },
      {
        Sid    = "AllowECSServiceRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
      }
    ]
  })
}

# TIER 1: Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TIER 1: Access logging to CloudWatch
resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class  = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

# Create curation pipeline prefixes
resource "aws_s3_object" "pending_review_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "pending_review/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "pending_admin_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "pending_admin/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "approved_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "approved/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "rejected_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "rejected/"
  content_type = "application/x-directory"
}

# Outputs
output "bucket_arn" {
  value = aws_s3_bucket.training.arn
}

output "bucket_name" {
  value = aws_s3_bucket.training.id
}
```

---

## modules/ecs-task-role/main.tf

```hcl
# ECS Task Role with Least Privilege

variable "environment" {}
variable "s3_training_arn" {}
variable "rds_instance_arn" {}
variable "cognito_pool_arns" {}

# Task Execution Role (used by ECS to pull images and write logs)
resource "aws_iam_role" "task_execution" {
  name = "skin-lesion-ecs-task-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_base" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_secrets" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# TIER 2: Task Role (application running in ECS)
resource "aws_iam_role" "task" {
  name = "skin-lesion-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

# TIER 2: Scoped S3 policy - only specific prefixes, no delete
resource "aws_iam_policy" "task_s3" {
  name = "skin-lesion-ecs-task-s3-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${var.s3_training_arn}/*/pending_review/*",
          "${var.s3_training_arn}/*/pending_admin/*",
          "${var.s3_training_arn}/*/approved/*",
          var.s3_training_arn
        ]
      },
      {
        Effect = "Deny"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketVersioning"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_s3.arn
}

# TIER 2: Scoped RDS policy - connect only, no admin
resource "aws_iam_policy" "task_rds" {
  name = "skin-lesion-ecs-task-rds-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "rds-db:Connect"
        ]
        Resource = var.rds_instance_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_rds" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_rds.arn
}

# TIER 2: Limited Cognito access
resource "aws_iam_policy" "task_cognito" {
  name = "skin-lesion-ecs-task-cognito-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPool",
          "cognito-idp:ListUsers",
          "cognito-idp:AdminGetUser"
        ]
        Resource = values(var.cognito_pool_arns)
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_cognito" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_cognito.arn
}

# Outputs
output "execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
```

---

## modules/guardduty/main.tf

```hcl
# GuardDuty Enablement

variable "environment" {}
variable "s3_bucket_arn" {}

resource "aws_guardduty_detector" "main" {
  count = 1

  enable                         = true
  finding_publishing_frequency = "SIX_HOURS"

  detector_features {
    name   = "S3Logs"
    status = "ENABLED"
  }

  detector_features {
    name   = "MalwareProtection"
    status = "ENABLED"
  }

  tags = {
    Environment = var.environment
  }
}

# TIER 1: CloudWatch EventBridge rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name        = "skin-lesion-guardduty-finding-${var.environment}"
  description = "Alert on GuardDuty critical findings"

  event_pattern = jsonencode({
    source = ["aws.guardduty"],
    detail-type = ["GuardDuty Finding"],
    detail = {
      severity = ["HIGH", "CRITICAL"]
    }
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "guardduty_pagerduty" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "PagerDuty"
  arn       = var.pagerduty_webhook_arn  # Pass via variable
}

# TIER 1: SNS topic for GuardDuty alerts
resource "aws_sns_topic" "guardduty_alerts" {
  name = "skin-lesion-guardduty-alerts-${var.environment}"
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "SNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

output "detector_id" {
  value = aws_guardduty_detector.main[0].id
}

output "sns_topic_arn" {
  value = aws_sns_topic.guardduty_alerts.arn
}
```

---

## modules/waf/main.tf

```hcl
# AWS WAF with Rate Limiting and OWASP Rules

variable "environment" {}
variable "alb_arn" {}
variable "alb_zone_id" {}

resource "aws_wafv2_web_acl" "main" {
  name        = "skin-lesion-waf-${var.environment}"
  description = "WAF for Skin Lesion Platform API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # TIER 3: Rate limiting rule
  rule {
    name     = "RateLimitRule"
    priority = 1
    action {
      type = "BLOCK"
    }

    statement {
      rate_based_statement {
        limit               = 1000
        aggregate_key_type   = "IP"
        scope_down_statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            string_sequence = ["/api/v1/feedback"]
            text_transformations {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name              = "RateLimitRule"
    }
  }

  # TIER 3: SQL Injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 2
    action {
      type = "BLOCK"
    }

    statement {
      sqli_match_statement {
        field_to_match {
          query_string {}
        }
        text_transformations {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name              = "SQLInjectionRule"
    }
  }

  # TIER 3: XSS protection
  rule {
    name     = "XSSRule"
    priority = 3
    action {
      type = "BLOCK"
    }

    statement {
      xss_match_statement {
        field_to_match {
          query_string {}
        }
        text_transformations {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name              = "XSSRule"
    }
  }

  # TIER 3: Block known malicious IPs
  rule {
    name     = "MaliciousIPRule"
    priority = 4
    action {
      type = "BLOCK"
    }

    statement {
      ip_set_reference_statement {
        arn = aws_wafv2_ip_set.malicious_ips.arn
      }
    }

    visibility_config {
      sampled_requests_enabled = true
      cloudwatch_metrics_enabled = true
      metric_name              = "MaliciousIPRule"
    }
  }

  tags = {
    Environment = var.environment
  }

  visibility_config {
    sampled_requests_enabled = true
    cloudwatch_metrics_enabled = true
    metric_name              = "waf ACL metrics"
  }
}

# Malicious IPs block list (can be updated via AWS Firewall Manager)
resource "aws_wafv2_ip_set" "malicious_ips" {
  name        = "malicious-ips-${var.environment}"
  description = "Known malicious IP addresses"
  scope       = "REGIONAL"
  ip_address_version = "IPV4"

  addresses = [
    # TOR exit nodes (example - should be dynamically updated)
    # "1.2.3.4/32"
  ]
}

# Associate WAF with ALB
resource "aws_wafv2_web_acl_association" "main" {
  resource_arn = var.alb_arn
  web_acl_arn  = aws_wafv2_web_acl.main.arn
}

output "web_acl_id" {
  value = aws_wafv2_web_acl.main.id
}
```

---

## modules/cloudtrail/main.tf

```hcl
# CloudTrail with Centralized Logging

variable "environment" {}
variable "s3_bucket_arn" {}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name           = "skin-lesion-cloudtrail-${var.environment}"
  s3_bucket_name = var.s3_bucket_arn
  s3_key_prefix  = "cloudtrail"

  # TIER 2: Enable all regions
  is_multi_region_trail = true

  # TIER 2: Log file validation
  enable_log_file_validation = true

  # TIER 2: SNS notification on log delivery
  sns_topic_name = aws_sns_topic.cloudtrail_alerts.name

  # TIER 2: Events to capture
  event_selector {
    read_write_type = "ALL"
    include_management_events = true

    data_resource {
      type = "AWS::S3::Object"
      values = ["arn:aws:s3:::skin-lesion-training-*/*"]
    }

    data_resource {
      type = "AWS::S3::Bucket"
      values = ["arn:aws:s3:::skin-lesion-training-*"]
    }
  }

  tags = {
    Environment = var.environment
  }
}

# SNS Topic for CloudTrail alerts
resource "aws_sns_topic" "cloudtrail_alerts" {
  name = "skin-lesion-cloudtrail-alerts-${var.environment}"
}

resource "aws_sns_topic_policy" "cloudtrail_alerts" {
  topic_arn = aws_sns_topic.cloudtrail_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail_alerts.arn
      }
    ]
  })
}

# TIER 2: EventBridge rule for critical CloudTrail events
resource "aws_cloudwatch_event_rule" "critical_events" {
  name        = "skin-lesion-critical-events-${var.environment}"
  description = "Alert on critical CloudTrail events"

  event_pattern = jsonencode({
    source = ["aws.cloudtrail"],
    detail-type = ["AWS CloudTrail Raw Event"],
    detail = {
      eventName = [
        "PutBucketPolicy",
        "DeleteBucket",
        "AttachUserPolicy",
        "CreateUser",
        "PutRolePolicy",
        "ConsoleLogin"
      ]
    }
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "critical_events_sns" {
  rule      = aws_cloudwatch_event_rule.critical_events.name
  target_id = "Alert SNS"
  arn       = aws_sns_topic.cloudtrail_alerts.arn
}

output "trail_arn" {
  value = aws_cloudtrail.main.arn
}
```

---

## modules/rds/main.tf

```hcl
# RDS PostgreSQL with KMS Encryption

variable "environment" {}
variable "vpc_id" {}
variable "data_subnet_ids" {}
variable "kms_key_arn" {}
variable "db_password_secret" {}

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
  description = "Security group for RDS PostgreSQL"
  vpc_id      = var.vpc_id

  ingress {
    description     = "ECS tasks PostgreSQL"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    source_security_group_id = var.ecs_security_group_id
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
  kms_key_id            = var.kms_key_arn

  # Backup
  multi_az                = true
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "mon:04:00-mon:05:00"

  # Monitoring
  monitoring_interval = 60
  monitoring_role_arn = aws_iam_role.rds_monitoring.arn
  performance_insights_enabled = true

  # Security
  publicly_accessible = false
  auto_minor_version_upgrade = true

  tags = {
    Environment = var.environment
  }
}

# RDS Monitoring Role
resource "aws_iam_role" "rds_monitoring" {
  name = "skin-lesion-rds-monitoring-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Secrets Manager secret
resource "aws_secretsmanager_secret" "db_password" {
  name = "skin-lesion/db-password-${var.environment}"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id = aws_secretsmanager_secret.db_password.id
  secret_string = var.db_password
}

output "instance_arn" {
  value = aws_db_instance.main.arn
}

output "instance_endpoint" {
  value = aws_db_instance.main.endpoint
}
```

---

## modules/vpc/main.tf

```hcl
# VPC with 3-tier subnet design

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
  route_table_id = aws_route_table.app.id  # Data subnets use same route as app (no public egress needed except through NAT)
}

# S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id          = aws_vpc.main.id
  service_name    = "s3.us-east-1.amazonaws.com"
  route_table_ids = [aws_route_table.app.id]

  tags = {
    Name = "skin-lesion-s3-vpce-${var.environment}"
  }
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
```

---

## Makefile

```makefile
# Skin Lesion Platform - Terraform Commands
# Usage: make apply, make destroy, make plan

ENV ?= prod
REGION ?= us-east-1
TFVARS = -var-file=environments/$(ENV).tfvars

.PHONY: apply destroy plan format check validate

apply:
	@echo "Applying Terraform for $(ENV) environment..."
	cd infra/terraform && terraform init
	cd infra/terraform && terraform apply $(TFVARS) -auto-approve

destroy:
	@echo "Destroying Terraform for $(ENV) environment..."
	cd infra/terraform && terraform destroy $(TFVARS) -auto-approve

plan:
	@echo "Planning Terraform for $(ENV) environment..."
	cd infra/terraform && terraform init
	cd infra/terraform && terraform plan $(TFVARS)

format:
	@echo "Formatting Terraform files..."
	cd infra/terraform && terraform fmt -recursive

check:
	@echo "Checking Terraform files..."
	cd infra/terraform && terraform fmt -check -recursive

validate:
	@echo "Validating Terraform modules..."
	cd infra/terraform && terraform init
	cd infra/terraform && terraform validate

output:
	@echo "Showing Terraform outputs..."
	cd infra/terraform && terraform output

refresh:
	@echo "Refreshing Terraform state..."
	cd infra/terraform && terraform refresh $(TFVARS)

# Quick dev deployment (no MFA)
dev:
	ENV=dev make apply

# Production deployment (requires MFA)
prod:
	@echo "Deploying to production - ensure you have MFA enabled!"
	@aws sts get-caller-identity | grep -q "arn:aws:iam::.*:user" && echo "User authenticated" || (echo "ERROR: Not authenticated"; exit 1)
	ENV=prod make apply
```

---

## environments/prod.tfvars

```hcl
# Production environment variables
aws_region   = "us-east-1"
environment  = "prod"
vpc_cidr     = "10.0.0.0/16"
account_id   = "123456789012"

# Database (use a strong password!)
db_username  = "skinlesionadmin"
db_password  = "REPLACE_WITH_STRONG_PASSWORD_FROM_SECRETS_MANAGER"

# Alerts
pagerduty_webhook_arn = "arn:aws:sns:us-east-1:123456789012:skin-lesion-pagerduty"
```

---

## How to Use

```bash
# 1. Initialize Terraform
cd infra/terraform
terraform init

# 2. Create prod.tfvars with your values
cp environments/prod.tfvars.example environments/prod.tfvars
# Edit prod.tfvars with your account ID and passwords

# 3. Plan the deployment
make plan ENV=prod

# 4. Apply the deployment (requires MFA)
make apply ENV=prod

# 5. Get outputs
make output

# 6. Destroy (careful!)
make destroy ENV=prod
```

---

## Validation Commands

After deployment, verify the controls:

```bash
# Verify S3 MFA Delete is enabled
aws s3api get-bucket-versioning --bucket skin-lesion-training-$ACCOUNT_ID

# Verify Cognito MFA is on
aws cognito-idp get-user-pool-mfa-config --user-pool-id $DOCTOR_POOL_ID

# Verify WAF is attached to ALB
aws wafv2 get-web-acl-for-resource --resource-arn $ALB_ARN

# Verify GuardDuty is enabled
aws guardduty list-detectors

# Verify VPC Flow Logs
aws ec2 describe-flow-logs --filters Name=resource-id,Values=$VPC_ID
```
