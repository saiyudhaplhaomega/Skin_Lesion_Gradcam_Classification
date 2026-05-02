output "service_name" {
  value       = aws_ecs_service.main.name
  description = "ECS service name"
}

output "service_arn" {
  value       = aws_ecs_service.main.arn
  description = "ECS service ARN"
}
