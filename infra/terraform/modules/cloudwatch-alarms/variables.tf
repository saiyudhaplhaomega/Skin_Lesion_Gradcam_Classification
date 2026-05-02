variable "environment" {
  description = "Environment name"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
}

variable "ecs_service_name" {
  description = "ECS service name"
}

variable "alb_arn" {
  description = "ALB ARN"
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
}

variable "lambda_function_rollback_arn" {
  description = "Lambda function ARN for auto-rollback"
}

variable "lambda_function_heal_arn" {
  description = "Lambda function ARN for auto-heal"
}
