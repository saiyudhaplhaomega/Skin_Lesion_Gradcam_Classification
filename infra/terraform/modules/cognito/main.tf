# Cognito User Pools with MFA Enforcement for doctors

variable "environment" {}

# IAM Role for Lambda functions (used by Cognito triggers)
resource "aws_iam_role" "lambda_cognito_role" {
  name = "skin-lesion-lambda-cognito-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })
}

# Patient User Pool (self-registration allowed, auto-approved)
resource "aws_cognito_user_pool" "patients" {
  name = "skin-lesion-patients-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
  }

  auto_verified_attributes = ["email"]

  schema {
    name         = "role"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "approved"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  tags = {
    Environment = var.environment
  }
}

# Doctor User Pool (admin approval required, MFA enforced)
resource "aws_cognito_user_pool" "doctors" {
  name = "skin-lesion-doctors-${var.environment}"

  password_policy {
    minimum_length    = 8
    require_uppercase = true
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
  }

  # TIER 1: MFA REQUIRED for doctors
  mfa_configuration = "ON"
  sms_authentication_failure_tries = 5
  sms_verification_message = "Your verification code is {####}"

  # Admin only can recover account (prevents social engineering attacks)
  account_recovery_setting {
    recovery_mechanisms {
      name     = "admin_only"
      priority = 1
    }
  }

  schema {
    name         = "role"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "approved"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  schema {
    name         = "medical_license"
    attribute_data_type = "String"
    mutable      = true
    required     = false
  }

  tags = {
    Environment = var.environment
  }
}

# Patient User Pool Client
resource "aws_cognito_user_pool_client" "patients" {
  user_pool_id = aws_cognito_user_pool.patients.id
  name         = "skin-lesion-patient-app"

  generate_secret     = true
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

# Doctor User Pool Client
resource "aws_cognito_user_pool_client" "doctors" {
  user_pool_id = aws_cognito_user_pool.doctors.id
  name         = "skin-lesion-doctor-app"

  generate_secret     = true
  refresh_token_validity = 30
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  # TIER 1: Explicit logout URLs (prevents redirect attacks)
  logout_URIs = [
    "https://api.skinlesion.com/logout"
  ]
}

# Identity Pool
resource "aws_cognito_identity_pool" "main" {
  identity_pool_name = "skin-lesion-identity-pool-${var.environment}"

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.patients.id
    provider_name           = aws_cognito_user_pool.patients.endpoint
    server_side_token_check = true
  }

  cognito_identity_providers {
    client_id               = aws_cognito_user_pool_client.doctors.id
    provider_name           = aws_cognito_user_pool.doctors.endpoint
    server_side_token_check = true
  }

  allow_unauthenticated_identities = false

  tags = {
    Environment = var.environment
  }
}

# Outputs
output "patient_pool_id" {
  value = aws_cognito_user_pool.patients.id
}

output "patient_pool_arn" {
  value = aws_cognito_user_pool.patients.arn
}

output "doctor_pool_id" {
  value = aws_cognito_user_pool.doctors.id
}

output "doctor_pool_arn" {
  value = aws_cognito_user_pool.doctors.arn
}

output "patient_pool_client_id" {
  value = aws_cognito_user_pool_client.patients.id
}

output "doctor_pool_client_id" {
  value = aws_cognito_user_pool_client.doctors.id
}

output "identity_pool_id" {
  value = aws_cognito_identity_pool.main.id
}
