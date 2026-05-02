# Auto-Heal Lambda Function
# Triggered by CloudWatch ECS/ALB alarms
# Performs ECS service scaling and sends alerts

variable "environment" {}
variable "ecs_cluster_name" {}
variable "ecs_service_name" {}
variable "sns_topic_arn" {}

resource "aws_iam_role" "heal_lambda_role" {
  name = "skin-lesion-${var.environment}-heal-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "heal_lambda_permissions" {
  name = "skin-lesion-${var.environment}-heal-lambda-policy"
  role = aws_iam_role.heal_lambda_role.id

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
          "ecs:DescribeServices",
          "ecs:UpdateService",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:StopTask"
        ],
        Resource = "*"
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

resource "aws_cloudwatch_log_group" "heal_lambda_logs" {
  name              = "/aws/lambda/skin-lesion-${var.environment}-auto-heal"
  retention_in_days = 14
}

resource "aws_lambda_function" "auto_heal" {
  filename      = "${path.module}/../../lambda/auto-heal.zip"
  function_name = "skin-lesion-${var.environment}-auto-heal"
  role          = aws_iam_role.heal_lambda_role.arn
  handler       = "auto_heal.lambda_handler"
  runtime       = "python3.11"
  timeout       = 120
  memory_size   = 256

  environment {
    variables = {
      ENVIRONMENT      = var.environment
      ECS_CLUSTER_NAME = var.ecs_cluster_name
      ECS_SERVICE_NAME = var.ecs_service_name
      SNS_TOPIC_ARN    = var.sns_topic_arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.heal_lambda_logs]

  tags = { Environment = var.environment }
}

resource "aws_sns_topic_subscription" "heal_lambda" {
  topic_arn = var.sns_topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.auto_heal.arn
}

output "heal_lambda_arn" {
  value = aws_lambda_function.auto_heal.arn
}
