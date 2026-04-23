# ECS Task Role with Least Privilege
# Implements Tier 2 defensive controls

variable "environment" {}
variable "s3_training_arn" {}
variable "cognito_pool_arns" {}

# Task Execution Role (used by ECS to pull images, write logs, access Secrets Manager)
resource "aws_iam_role" "task_execution" {
  name = "skin-lesion-ecs-task-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_base" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "task_execution_secrets" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

# Task Role (application running in ECS)
resource "aws_iam_role" "task" {
  name = "skin-lesion-ecs-task-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

# TIER 2: Scoped S3 policy - only specific prefixes, explicit DENY for delete
resource "aws_iam_policy" "task_s3" {
  name = "skin-lesion-ecs-task-s3-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:HeadObject"
        ]
        Resource = [
          "${var.s3_training_arn}/*/pending_review/*",
          "${var.s3_training_arn}/*/pending_admin/*",
          "${var.s3_training_arn}/*/approved/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = var.s3_training_arn
      },
      {
        Effect = "Deny"
        Action = [
          "s3:DeleteObject",
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "s3:PutBucketVersioning",
          "s3:PutBucketAcl"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_s3" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_s3.arn
}

# TIER 2: Limited Cognito access for user validation only
resource "aws_iam_policy" "task_cognito" {
  name = "skin-lesion-ecs-task-cognito-${var.environment}"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cognito-idp:DescribeUserPool",
          "cognito-idp:ListUsers",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminListGroupsForUser",
          "cognito-idp:GetUser"
        ]
        Resource = [
          values(var.cognito_pool_arns)[0],
          values(var.cognito_pool_arns)[1]
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "task_cognito" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_cognito.arn
}

# Outputs
output "execution_role_arn" {
  value = aws_iam_role.task_execution.arn
}

output "task_role_arn" {
  value = aws_iam_role.task.arn
}
