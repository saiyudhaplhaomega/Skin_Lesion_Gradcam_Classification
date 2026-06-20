# --- Guide 10: Notifications Topic ---

resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-${var.environment}-notifications"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "notifications"
  }
}

# --- Guide 13: Training Workflow Queue ---

resource "aws_sqs_queue" "training_workflow_dlq" {
  name                      = "${var.project_name}-training-workflow-dlq-${var.environment}.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "training-workflow-dlq"
  }
}

resource "aws_sqs_queue" "training_workflow" {
  name                        = "${var.project_name}-training-workflow-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true
  visibility_timeout_seconds  = 300
  message_retention_seconds   = 86400
  receive_wait_time_seconds   = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.training_workflow_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "training-workflow"
  }
}

resource "aws_iam_policy" "training_workflow_sqs_access" {
  name = "${var.project_name}-training-workflow-sqs-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = [
          aws_sqs_queue.training_workflow.arn,
          aws_sqs_queue.training_workflow_dlq.arn,
        ]
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_bus" "training" {
  name = "${var.project_name}-${var.environment}-events"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "training-workflow"
  }
}

resource "aws_cloudwatch_event_rule" "training_admin_approved" {
  name           = "${var.project_name}-${var.environment}-admin-approved"
  event_bus_name = aws_cloudwatch_event_bus.training.name

  event_pattern = jsonencode({
    source      = ["skin-lesion.backend"]
    detail-type = ["training_case.admin_approved"]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "training_admin_approved_sqs" {
  rule           = aws_cloudwatch_event_rule.training_admin_approved.name
  event_bus_name = aws_cloudwatch_event_bus.training.name
  target_id      = "training-workflow-queue"
  arn            = aws_sqs_queue.training_workflow.arn

  sqs_target {
    message_group_id = "training-workflow"
  }
}

resource "aws_sqs_queue_policy" "training_workflow_eventbridge" {
  queue_url = aws_sqs_queue.training_workflow.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = aws_sqs_queue.training_workflow.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.training_admin_approved.arn
          }
        }
      }
    ]
  })
}
