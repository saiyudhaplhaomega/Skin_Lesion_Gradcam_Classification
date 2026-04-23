# Secrets Manager with automatic rotation

variable "environment" {}
variable "db_username" {
  default = "skinlesionadmin"
}

# Secrets Manager secret for DB password
resource "aws_secretsmanager_secret" "db_password" {
  name = "skin-lesion/db-password-${var.environment}"
  description = "Database password for Skin Lesion Platform RDS"

  recovery_window_in_days = 7

  tags = {
    Environment = var.environment
  }
}

resource "aws_secretsmanager_secret_rotation" "db_password" {
  count = 0  # Disable automatic rotation until Lambda is deployed

  secret_id = aws_secretsmanager_secret.db_password.id

  rotation_lambda_arn = length(aws_lambda_function.rotation) > 0 ? aws_lambda_function.rotation[0].arn : ""
}

# Lambda function for secret rotation (placeholder)
resource "aws_lambda_function" "rotation" {
  count = 0  # Disable until rotation Lambda is implemented

  filename         = "lambdas/rotation-placeholder.zip"
  function_name    = "skin-lesion-secret-rotation-${var.environment}"
  role            = aws_iam_role.lambda_rotation.arn
  handler         = "rotation.handler"
  runtime         = "python3.10"
  memory_size     = 128
  timeout         = 30

  environment {
    variables = {
      DB_USERNAME = var.db_username
    }
  }
}

resource "aws_iam_role" "lambda_rotation" {
  count = 0  # Disable until rotation Lambda is implemented

  name = "skin-lesion-lambda-rotation-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

output "db_password_secret_arn" {
  value = aws_secretsmanager_secret.db_password.arn
}
