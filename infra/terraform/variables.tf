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