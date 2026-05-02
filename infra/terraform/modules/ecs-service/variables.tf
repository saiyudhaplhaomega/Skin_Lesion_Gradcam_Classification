variable "environment" {
  description = "Environment name (prod, staging, blue, green)"
}

variable "cluster_name" {
  description = "Name of the ECS cluster"
}

variable "task_definition_arn" {
  description = "Full ARN of the task definition (family:version)"
}

variable "target_group_arn" {
  description = "ARN of the ALB target group to attach"
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
}

variable "app_subnet_ids" {
  description = "List of private app subnet IDs"
  type        = list(string)
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  default     = 2
}

variable "health_check_grace_period_seconds" {
  description = "Grace period before ECS starts health checks (seconds)"
  default     = 120  # Must be >= 120 for model loading from S3
}
