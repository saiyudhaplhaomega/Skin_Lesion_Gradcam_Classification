# --- Guide 16: Security And Observability Baseline ---

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count             = var.enable_security_observability ? 1 : 0
  name              = "/aws/vpc/${var.project_name}-${var.environment}-flow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "vpc-flow-logs"
  }
}

resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_security_observability ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_security_observability ? 1 : 0
  name  = "${var.project_name}-${var.environment}-vpc-flow-logs"
  role  = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "${aws_cloudwatch_log_group.vpc_flow_logs[0].arn}:*"
      }
    ]
  })
}

resource "aws_flow_log" "main" {
  count                    = var.enable_security_observability ? 1 : 0
  iam_role_arn             = aws_iam_role.vpc_flow_logs[0].arn
  log_destination          = aws_cloudwatch_log_group.vpc_flow_logs[0].arn
  traffic_type             = "ALL"
  vpc_id                   = aws_vpc.main.id
  max_aggregation_interval = 60

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "network-observability"
  }
}

resource "aws_cloudwatch_metric_alarm" "training_queue_depth" {
  alarm_name          = "${var.project_name}-${var.environment}-training-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 10
  alarm_description   = "Training workflow queue has messages waiting for worker processing."
  alarm_actions       = [aws_sns_topic.notifications.arn]
  ok_actions          = [aws_sns_topic.notifications.arn]

  dimensions = {
    QueueName = aws_sqs_queue.training_workflow.name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "worker-reliability"
  }
}

resource "aws_cloudwatch_metric_alarm" "training_dlq_depth" {
  alarm_name          = "${var.project_name}-${var.environment}-training-dlq-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "Training workflow dead-letter queue has failed messages."
  alarm_actions       = [aws_sns_topic.notifications.arn]

  dimensions = {
    QueueName = aws_sqs_queue.training_workflow_dlq.name
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "worker-reliability"
  }
}

resource "aws_sns_topic_subscription" "alert_email" {
  count     = var.enable_security_observability ? 1 : 0
  topic_arn = aws_sns_topic.notifications.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_guardduty_detector" "main" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_rule" "guardduty_high" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-guardduty-high"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
    detail = {
      severity = [{ numeric = [">=", 7] }]
    }
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "guardduty_high_sns" {
  count = var.enable_guardduty ? 1 : 0
  rule  = aws_cloudwatch_event_rule.guardduty_high[0].name
  arn   = aws_sns_topic.notifications.arn
}
