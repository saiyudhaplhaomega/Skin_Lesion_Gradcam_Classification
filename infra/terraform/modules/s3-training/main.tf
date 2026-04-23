# S3 Training Bucket with VPC Endpoint Restriction and MFA Delete
# Implements Tier 1 defensive controls

variable "environment" {}
variable "vpc_id" {}
variable "vpc_endpoint_id" {}
variable "account_id" {}

# Training data bucket
resource "aws_s3_bucket" "training" {
  bucket = "skin-lesion-training-${var.account_id}"

  tags = {
    Environment          = var.environment
    DataClassification  = "Medical-PHI"
    GDPR                 = "Required"
  }
}

# TIER 1: Block all public access
resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

# TIER 1: MFA Delete required (prevents accidental/malicious deletion)
resource "aws_s3_bucket_versioning" "training" {
  bucket = aws_s3_bucket.training.id

  versioning_configuration {
    status   = "Enabled"
    mfa_delete = "Enabled"
  }
}

# TIER 1: Server-side encryption with AES-256
resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# TIER 1: Bucket policy - Deny non-HTTPS and non-VPC access
resource "aws_s3_bucket_policy" "training_vpc_only" {
  bucket = aws_s3_bucket.training.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      },
      {
        Sid       = "EnforceVPCEndpoint"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
        Condition = {
          NotIpAddress = {
            "aws:sourceVpce" = var.vpc_endpoint_id
          }
        }
      },
      {
        Sid    = "AllowECSServiceRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.training.arn,
          "${aws_s3_bucket.training.arn}/*"
        ]
      }
    ]
  })
}

# TIER 1: Lifecycle rules for incomplete uploads and version management
resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = "Enabled"

    filter {}

    transition {
      days          = 30
      storage_class = "GLACIER"
    }
  }
}

# Create curation pipeline prefixes
resource "aws_s3_object" "pending_review_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "pending_review/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "pending_admin_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "pending_admin/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "approved_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "approved/"
  content_type = "application/x-directory"
}

resource "aws_s3_object" "rejected_prefix" {
  bucket = aws_s3_bucket.training.id
  key    = "rejected/"
  content_type = "application/x-directory"
}

# Outputs
output "bucket_arn" {
  value = aws_s3_bucket.training.arn
}

output "bucket_name" {
  value = aws_s3_bucket.training.id
}
