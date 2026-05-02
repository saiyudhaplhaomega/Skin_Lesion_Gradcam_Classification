# ECS Service - binds ECS tasks to an ALB target group
# This is separate from the cluster module because each deployment environment
# (blue, green, staging) needs its own service definition

variable "environment" {}
variable "cluster_name" {}
variable "task_definition_arn" {}
variable "target_group_arn" {}
variable "ecs_security_group_id" {}
variable "app_subnet_ids" {}
variable "desired_count" { default = 2 }
variable "health_check_grace_period_seconds" { default = 120 }

resource "aws_ecs_service" "main" {
  name            = "skin-lesion-${var.environment}"
  cluster         = var.cluster_name
  task_definition = var.task_definition_arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  platform_version = "1.4.0"

  deployment_controller {
    type = "ECS"  # Rolling deploy by default; blue-green uses CODE deploy with ext controller
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds = var.health_check_grace_period_seconds

  network_configuration {
    subnets          = var.app_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false  # CRITICAL: tasks in private app subnet, not public
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "backend"
    container_port   = 8080
  }

  # Prevent terraform from destroying the service on destroy apply
  # This protects against accidental infrastructure deletion
  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Environment = var.environment
  }
}

output "ecs_service_name" {
  value = aws_ecs_service.main.name
}

output "ecs_service_arn" {
  value = aws_ecs_service.main.arn
}
