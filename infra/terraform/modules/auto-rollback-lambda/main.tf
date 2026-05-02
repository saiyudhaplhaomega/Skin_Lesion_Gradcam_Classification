# Auto-Rollback Lambda Function
# Triggered by CloudWatch alarm via SNS
# Reverses the ALB listener to point to the previous (healthy) target group

variable "environment" {}
variable "sns_topic_arn" {}
variable "alb_arn" {}
variable "blue_tg_arn" {}
variable "green_tg_arn" {}

resource "aws_iam_role" "rollback_lambda_role" {
  name = "skin-lesion-${var.environment}-rollback-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })

  tags = { Environment = var.environment }
}

resource "aws_iam_role_policy" "rollback_lambda_permissions" {
  name = "skin-lesion-${var.environment}-rollback-lambda-policy"
  role = aws_iam_role.rollback_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:ModifyListener"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:PutParameter"
        ],
        Resource = "arn:aws:ssm:*:*:parameter/skin-lesion/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ],
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "rollback_lambda_logs" {
  name              = "/aws/lambda/skin-lesion-${var.environment}-auto-rollback"
  retention_in_days = 14

  tags = { Environment = var.environment }
}

resource "aws_lambda_function" "auto_rollback" {
  filename      = "${path.module}/../../lambda/auto-rollback.zip"
  function_name = "skin-lesion-${var.environment}-auto-rollback"
  role          = aws_iam_role.rollback_lambda_role.arn
  handler       = "auto_rollback.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 128

  environment {
    variables = {
      ENVIRONMENT     = var.environment
      ALB_ARN         = var.alb_arn
      BLUE_TG_ARN     = var.blue_tg_arn
      GREEN_TG_ARN    = var.green_tg_arn
      ACTIVE_SLOT_SSM = "/skin-lesion/${var.environment}/active-slot"
    }
  }

  depends_on = [aws_cloudwatch_log_group.rollback_lambda_logs]

  tags = { Environment = var.environment }
}

resource "aws_sns_topic_subscription" "rollback_lambda" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_rollback.arn
}

output "rollback_lambda_arn" {
  value = aws_lambda_function.auto_rollback.arn
}

output "rollback_lambda_role_arn" {
  value = aws_iam_role.rollback_lambda_role.arn
}
