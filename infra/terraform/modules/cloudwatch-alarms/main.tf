# CloudWatch Alarms for Auto-Rollback and Auto-Healing
# These alarms trigger Lambda functions that perform automated remediation

variable "environment" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "alb_arn" {}
variable "sns_topic_arn" {}
variable "lambda_function_rollback_arn" {}
variable "lambda_function_heal_arn" {}

# ========== ECS Alarms ==========

resource "aws_cloudwatch_metric_alarm" "ecs_memory_high" {
  alarm_name          = "skin-lesion-${var.environment}-ecs-memory-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "ECS task memory above 90% for 10 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_heal_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "ecs_cpu_high" {
  alarm_name          = "skin-lesion-${var.environment}-ecs-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "ECS task CPU above 85% for 10 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ClusterName = var.ecs_cluster_name
    ServiceName = var.ecs_service_name
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_heal_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "ecs_health_check_failed" {
  alarm_name          = "skin-lesion-${var.environment}-ecs-health-check-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "No healthy ECS tasks for 1 minute"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = element(split("/", var.alb_arn), length(split("/", var.alb_arn)) - 1)
    TargetGroup  = "*/targetGroup/*"
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_rollback_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

# ========== ALB Alarms ==========

resource "aws_cloudwatch_metric_alarm" "alb_5xx_high" {
  alarm_name          = "skin-lesion-${var.environment}-alb-5xx-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors above 10 for 3 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = element(split("/", var.alb_arn), length(split("/", var.alb_arn)) - 1)
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_rollback_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "alb_latency_high" {
  alarm_name          = "skin-lesion-${var.environment}-alb-latency-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "ALB target response time above 3 seconds for 3 consecutive minutes"
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = element(split("/", var.alb_arn), length(split("/", var.alb_arn)) - 1)
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_heal_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "alb_no_healthy_targets" {
  alarm_name          = "skin-lesion-${var.environment}-alb-no-healthy-targets"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 30
  statistic           = "Minimum"
  threshold           = 1
  alarm_description   = "ALB has no healthy targets"
  treat_missing_data  = "breaching"

  dimensions = {
    LoadBalancer = element(split("/", var.alb_arn), length(split("/", var.alb_arn)) - 1)
    TargetGroup  = "*/targetGroup/*"
  }

  alarm_actions = [var.sns_topic_arn, var.lambda_function_rollback_arn]
  ok_actions    = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

# ========== RDS Alarms ==========

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "skin-lesion-${var.environment}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS CPU above 80%"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "skin-lesion-${var.environment}"
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions   = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

resource "aws_cloudwatch_metric_alarm" "rds_connections_high" {
  alarm_name          = "skin-lesion-${var.environment}-rds-connections-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "RDS connections above 80% of limit"
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBInstanceIdentifier = "skin-lesion-${var.environment}"
  }

  alarm_actions = [var.sns_topic_arn]
  ok_actions   = [var.sns_topic_arn]

  tags = { Environment = var.environment }
}

output "ecs_memory_high_alarm" {
  value = aws_cloudwatch_metric_alarm.ecs_memory_high.arn
}

output "ecs_cpu_high_alarm" {
  value = aws_cloudwatch_metric_alarm.ecs_cpu_high.arn
}

output "ecs_health_check_failed_alarm" {
  value = aws_cloudwatch_metric_alarm.ecs_health_check_failed.arn
}

output "alb_5xx_high_alarm" {
  value = aws_cloudwatch_metric_alarm.alb_5xx_high.arn
}

output "alb_latency_high_alarm" {
  value = aws_cloudwatch_metric_alarm.alb_latency_high.arn
}

output "alb_no_healthy_targets_alarm" {
  value = aws_cloudwatch_metric_alarm.alb_no_healthy_targets.arn
}
