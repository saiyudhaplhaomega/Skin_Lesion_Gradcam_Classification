# KMS Key for encryption

variable "description" {
  default = "KMS key for Skin Lesion Platform"
}

resource "aws_kms_key" "main" {
  description = var.description
  key_usage   = "ENCRYPT_DECRYPT"

  key_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "self"
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "rds.amazonaws.com"
        }
        Action   = [
          "kms:Encrypt*",
          "kms:Decrypt*",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Describe*"
        ]
        Resource = "self"
      }
    ]
  })

  tags = {
    Environment = "prod"
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/skin-lesion-platform"
  target_key_id = aws_kms_key.main.key_id
}

data "aws_caller_identity" "current" {}

output "key_arn" {
  value = aws_kms_key.main.arn
}

output "key_id" {
  value = aws_kms_key.main.key_id
}
