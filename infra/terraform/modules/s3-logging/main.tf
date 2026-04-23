# S3 Bucket for Logging (CloudTrail, VPC Flow Logs, etc.)

variable "environment" {}
variable "bucket_prefix" {}

resource "aws_s3_bucket" "logging" {
  bucket = "${var.bucket_prefix}-${var.environment}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "logging" {
  bucket = aws_s3_bucket.logging.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 90
    }
  }
}

output "bucket_arn" {
  value = aws_s3_bucket.logging.arn
}
