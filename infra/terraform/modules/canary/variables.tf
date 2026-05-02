variable "environment" {
  description = "Environment name"
}

variable "alb_arn" {
  description = "ARN of the existing ALB (HTTPS listener on 443)"
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
