# CloudTrail with Centralized Logging
# Implements Tier 2 defensive controls

variable "environment" {}

# S3 Bucket for CloudTrail logs
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "skin-lesion-cloudtrail-${var.environment}-${data.aws_caller_identity.current.account_id}"

  tags = {
    Environment = var.environment
  }
}

resource "aws_s3_bucket_public_access_block" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls     = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudTrail
resource "aws_cloudtrail" "main" {
  name           = "skin-lesion-cloudtrail-${var.environment}"
  s3_bucket_name = aws_s3_bucket.cloudtrail.id

  # TIER 2: Enable all regions
  is_multi_region_trail = true

  # TIER 2: Log file validation
  enable_log_file_validation = true

  # TIER 2: SNS notification on log delivery
  sns_topic_name = aws_sns_topic.cloudtrail_alerts.name

  # TIER 2: Events to capture - management + data events
  event_selector {
    read_write_type = "ALL"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3:::skin-lesion-training-*/*"]
    }

    data_resource {
      type   = "AWS::S3::Bucket"
      values = ["arn:aws:s3:::skin-lesion-training-*"]
    }
  }

  tags = {
    Environment = var.environment
  }
}

# SNS Topic for CloudTrail alerts
resource "aws_sns_topic" "cloudtrail_alerts" {
  name = "skin-lesion-cloudtrail-alerts-${var.environment}"
}

resource "aws_sns_topic_policy" "cloudtrail_alerts" {
  topic_arn = aws_sns_topic.cloudtrail_alerts.arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "SNS:Publish"
        Resource = aws_sns_topic.cloudtrail_alerts.arn
      }
    ]
  })
}

# TIER 2: EventBridge rule for critical CloudTrail events
resource "aws_cloudwatch_event_rule" "critical_events" {
  name        = "skin-lesion-critical-events-${var.environment}"
  description = "Alert on critical CloudTrail events"

  event_pattern = jsonencode({
    source = ["aws.cloudtrail"],
    detail-type = ["AWS CloudTrail Raw Event"],
    detail = {
      eventName = [
        "PutBucketPolicy",
        "DeleteBucket",
        "AttachUserPolicy",
        "CreateUser",
        "PutRolePolicy",
        "ConsoleLogin"
      ]
    }
  })

  tags = {
    Environment = var.environment
  }
}

resource "aws_cloudwatch_event_target" "critical_events_sns" {
  rule      = aws_cloudwatch_event_rule.critical_events.name
  target_id = "Alert SNS"
  arn       = aws_sns_topic.cloudtrail_alerts.arn
}

data "aws_caller_identity" "current" {}

output "trail_arn" {
  value = aws_cloudtrail.main.arn
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.cloudtrail.arn
}
