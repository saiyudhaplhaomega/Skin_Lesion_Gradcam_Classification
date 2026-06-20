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
