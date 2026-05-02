variable "environment" {
  description = "Environment name (prod, staging)"
}

variable "alb_arn" {
  description = "ARN of the existing ALB (from alb module)"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "app_subnet_ids" {
  description = "List of private app subnet IDs"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
}
