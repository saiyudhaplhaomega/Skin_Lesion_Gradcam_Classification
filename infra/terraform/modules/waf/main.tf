# AWS WAF with Rate Limiting and OWASP Rules
# Implements Tier 3 defensive controls

variable "environment" {}

resource "aws_wafv2_web_acl" "main" {
  name        = "skin-lesion-waf-${var.environment}"
  description = "WAF for Skin Lesion Platform API"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # TIER 3: Rate limiting rule - 1000 requests per IP per minute
  rule {
    name     = "RateLimitRule"
    priority = 1
    action {
      type = "BLOCK"
    }

    statement {
      rate_based_statement {
        limit               = 1000
        aggregate_key_type   = "IP"
        scope_down_statement {
          byte_match_statement {
            field_to_match {
              uri_path {}
            }
            string_sequence = ["/api/v1/feedback"]
            text_transformations {
              priority = 1
              type     = "NONE"
            }
          }
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name               = "RateLimitRule"
    }
  }

  # TIER 3: SQL Injection protection
  rule {
    name     = "SQLInjectionRule"
    priority = 2
    action {
      type = "BLOCK"
    }

    statement {
      sqli_match_statement {
        field_to_match {
          query_string {}
        }
        text_transformations {
          priority = 1
          type     = "URL_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name               = "SQLInjectionRule"
    }
  }

  # TIER 3: XSS protection
  rule {
    name     = "XSSRule"
    priority = 3
    action {
      type = "BLOCK"
    }

    statement {
      xss_match_statement {
        field_to_match {
          query_string {}
        }
        text_transformations {
          priority = 1
          type     = "HTML_ENTITY_DECODE"
        }
      }
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name               = "XSSRule"
    }
  }

  tags = {
    Environment = var.environment
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name               = "waf-acl-metrics"
  }
}

output "web_acl_id" {
  value = aws_wafv2_web_acl.main.id
}

output "web_acl_arn" {
  value = aws_wafv2_web_acl.main.arn
}
