variable "environment" {}

resource "aws_sns_topic" "notifications" {
  name = "skin-lesion-${var.environment}-notifications"

  tags = { Environment = var.environment }
}

resource "aws_sns_topic_policy" "default" {
  arn = aws_sns_topic.notifications.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = { Service = "cloudwatch.amazonaws.com" }
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notifications.arn
      },
      {
        Effect = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action   = ["sns:Publish"]
        Resource = aws_sns_topic.notifications.arn
      }
    ]
  })
}

output "notifications_topic_arn" {
  value = aws_sns_topic.notifications.arn
}

output "notifications_topic_name" {
  value = aws_sns_topic.notifications.name
}
