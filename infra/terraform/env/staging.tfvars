# Staging environment variables for production-like validation.
# Use only after dev checks pass.

environment  = "staging"
project_name = "skin-lesion"
aws_region   = "us-east-1"

alert_email                   = "replace-me@example.com"
log_retention_days            = 30
waf_rate_limit                = 1000
enable_security_observability = false
enable_guardduty              = false

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
