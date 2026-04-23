# GuardDuty Enablement
# Implements Tier 1 defensive controls

variable "environment" {}

resource "aws_guardduty_detector" "main" {
  count = 1

  enable = true
  finding_publishing_frequency = "SIX_HOURS"

  detector_features {
    name   = "S3Logs"
    status = "ENABLED"
  }

  detector_features {
    name   = "MalwareProtection"
    status = "ENABLED"
  }

  tags = {
    Environment = var.environment
  }
}

# TIER 1: CloudWatch EventBridge rule for GuardDuty HIGH/CRITICAL findings
resource "aws_cloudwatch_event_rule" "guardduty_finding" {
  name        = "skin-lesion-guardduty-finding-${var.environment}"
  description = "Alert on GuardDuty critical findings"

  event_pattern = jsonencode({
    source = ["aws.guardduty"],
    detail-type = ["GuardDuty Finding"],
    detail = {
      severity = ["HIGH", "CRITICAL"]
    }
  })

  tags = {
    Environment = var.environment
  }
}

# SNS Topic for GuardDuty alerts
resource "aws_sns_topic" "guardduty_alerts" {
  name = "skin-lesion-guardduty-alerts-${var.environment}"
}

resource "aws_cloudwatch_event_target" "guardduty_sns" {
  rule      = aws_cloudwatch_event_rule.guardduty_finding.name
  target_id = "SNS"
  arn       = aws_sns_topic.guardduty_alerts.arn
}

output "detector_id" {
  value = aws_guardduty_detector.main[0].id
}

output "sns_topic_arn" {
  value = aws_sns_topic.guardduty_alerts.arn
}
