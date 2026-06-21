variable "project_name" {
  description = "Project name used as a prefix for resource names"
  type        = string
  default     = "skin-lesion"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "s3_unique_suffix" {
  description = "Globally unique suffix for S3 bucket names (from guide 04)"
  type        = string
  default     = "version1a-0"
}

variable "aws_account_id" {
  description = "12-digit AWS account ID for learning-dev"
  type        = string
  default     = "YOUR_ACCOUNT_ID"
}

variable "alert_email" {
  description = "Email address for staging alerts. Use a placeholder until you intentionally subscribe."
  type        = string
  default     = "replace-me@example.com"
}

variable "log_retention_days" {
  description = "CloudWatch log retention for staging-style logs"
  type        = number
  default     = 30
}

variable "waf_rate_limit" {
  description = "Requests per 5-minute window per IP before WAF rate limiting"
  type        = number
  default     = 1000
}

variable "enable_security_observability" {
  description = "Enable Guide 16 paid/security observability controls after explicit review"
  type        = bool
  default     = false
}

variable "enable_guardduty" {
  description = "Enable GuardDuty detector after reviewing cost and shutdown behavior"
  type        = bool
  default     = false
}

variable "enable_elasticache" {
  description = "Enable Guide 20 ElastiCache Redis after cost and auth-token review"
  type        = bool
  default     = false
}

variable "redis_node_type" {
  description = "ElastiCache node type for the optional Redis cluster"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_auth_token" {
  description = "Redis AUTH token. Keep null until setting it through a secure local tfvars or secret workflow."
  type        = string
  default     = null
  sensitive   = true
}

variable "enable_mlflow_server" {
  description = "Enable Guide 21 MLflow EC2 and artifact bucket after cost review"
  type        = bool
  default     = false
}

variable "mlflow_ami_id" {
  description = "AMI ID for the optional MLflow EC2 host. Set explicitly before enabling MLflow."
  type        = string
  default     = "ami-00000000000000000"
}

variable "mlflow_instance_type" {
  description = "Instance type for the optional MLflow EC2 host"
  type        = string
  default     = "t3.small"
}
