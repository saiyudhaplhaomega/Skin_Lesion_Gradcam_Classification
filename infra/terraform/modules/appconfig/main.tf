# AWS AppConfig for Feature Flags
# Provides real-time configuration updates for feature flags without redeployment

variable "environment" {
  description = "Environment name (dev, staging, prod)"
}

variable "lambda_function_arn" {
  description = "ARN of Lambda function to receive AppConfig notifications"
  default     = ""
}

resource "aws_appconfig_application" "main" {
  name        = "skin-lesion-${var.environment}"
  description = "Feature flags and configuration for Skin Lesion Platform"

  tags = { Environment = var.environment }
}

resource "aws_appconfig_configuration_profile" "flags" {
  application_id = aws_appconfig_application.main.id
  name           = "feature-flags"
  location_uri   = "hosted"
  type           = "AWS.FreeformConfigurationProfile"

  validators {
    type    = "JSON_SCHEMA"
    content = jsonencode({
      "$schema"     = "http://json-schema.org/draft-07/schema#"
      type          = "object"
      properties = {
        flags = {
          type = "object"
          additionalProperties = {
            type = "object"
            properties = {
              enabled          = { type = "boolean" }
              rollout_percent  = { type = "number" }
              description     = { type = "string" }
            }
            required = ["enabled"]
          }
        }
      }
      required = ["flags"]
    })
  }
}

resource "aws_appconfigHostedConfigurationVersion" "flags_v1" {
  application_id = aws_appconfig_configuration_profile.flags.application_id
  configuration_profile_id = aws_appconfig_configuration_profile.flags.id
  content = jsonencode({
    flags = {
      new_heatmap_method = {
        enabled         = false
        rollout_percent = 0
        description     = "Use new Grad-CAM implementation with guided backpropagation"
      }
      rag_explanation_v2 = {
        enabled         = false
        rollout_percent = 0
        description     = "Use RAG v2 with expanded clinical knowledge base"
      }
      vlm_cross_check = {
        enabled         = false
        rollout_percent = 0
        description     = "Enable GPT-4V second opinion on high-confidence cases"
      }
      canary_batch_percent = {
        enabled         = true
        rollout_percent = 5
        description     = "Percentage of traffic for canary deployments"
      }
      backward_compat_mode = {
        enabled         = true
        rollout_percent = 100
        description     = "Serve v1 response shape to clients without X-API-Version header"
      }
      async_report_generation = {
        enabled         = true
        rollout_percent = 100
        description     = "Generate reports asynchronously via SQS"
      }
      patient_memory_beta = {
        enabled         = false
        rollout_percent = 10
        description     = "Enable patient lesion memory and timeline features"
      }
    }
    schema_version = "1.0"
  })

  content_type = "application/json"
}

resource "aws_appconfig_deployment_strategy" "rolling" {
  name           = "skin-lesion-${var.environment}-rolling"
  description    = "Rolling deployment - propagate to all hosts in 30 minutes"
  deployment_duration_minutes = 30
  final_interval_minutes    = 10
  growth_type    = "LINEAR"
  growth_factor = 100

  tags = { Environment = var.environment }
}

resource "aws_appconfig_environment" "main" {
  application_id = aws_appconfig_application.main.id
  name          = var.environment
  description   = "Environment: ${var.environment}"

  tags = { Environment = var.environment }
}

resource "aws_appconfigDeployment" "initial" {
  application_id           = aws_appconfig_application.main.id
  configuration_profile_id = aws_appconfig_configuration_profile.flags.id
  environment_id           = aws_appconfig_environment.main.id
  deployment_strategy_id    = aws_appconfig_deployment_strategy.rolling.id
  description              = "Initial feature flag deployment"

  version = aws_appconfigHostedConfigurationVersion.flags_v1.version

  lifecycle {
    ignore_changes = [version]
  }
}

output "appconfig_application_id" {
  value = aws_appconfig_application.main.id
}

output "appconfig_config_profile_id" {
  value = aws_appconfig_configuration_profile.flags.id
}

output "appconfig_environment_id" {
  value = aws_appconfig_environment.main.id
}
