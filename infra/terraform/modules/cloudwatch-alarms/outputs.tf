output "ecs_memory_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}

output "ecs_cpu_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "ecs_health_check_failed_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.ecs_health_check_failed.arn
}

output "alb_5xx_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.alb_5xx_high.arn
}

output "alb_latency_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.alb_latency_high.arn
}

output "alb_no_healthy_targets_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.alb_no_healthy_targets.arn
}

output "rds_cpu_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.rds_cpu_high.arn
}

output "rds_connections_high_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.rds_connections_high.arn
}
