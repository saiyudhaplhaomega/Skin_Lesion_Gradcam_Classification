# Staging environment variables for production-like validation.
# Use only after dev checks pass.

environment      = "staging"
project_name     = "skin-lesion"
aws_region       = "us-east-1"
aws_account_id   = "526404916929"
s3_unique_suffix = "version1a-0"

alert_email                   = "replace-me@example.com"
log_retention_days            = 30
waf_rate_limit                = 1000
enable_security_observability = false
enable_guardduty              = false
enable_elasticache            = false
enable_mlflow_server          = false

# D7 - Aurora DSQL (Guide 22). Set enable_aurora_dsql = true after reading
# docs/staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md.
enable_aurora_dsql      = false
dsql_deletion_protection = false

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
