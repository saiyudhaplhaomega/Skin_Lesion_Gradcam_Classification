terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skin-lesion-learning-dev-vpc"
  }
}

resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skin-lesion-learning-dev-public-a"
  }
}

resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "skin-lesion-learning-dev-private-app-a"
  }
}

resource "aws_subnet" "private_data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.21.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "skin-lesion-learning-dev-private-data-a"
  }
}
# --- Guide 05: KMS Key ---
resource "aws_kms_key" "main" {
  description = "KMS key for skin lesion ${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/skin-lesion-dev"
  target_key_id = aws_kms_key.main.key_id
}

# --- Guide 05: Log Bucket ---

resource "aws_s3_bucket" "logs" {
  bucket = "skin-lesion-logs-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}


# --- Guide 05: Upload Bucket ---

resource "aws_s3_bucket" "uploads" {
  bucket = "skin-lesion-upload-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "uploads"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
# --- Guide 05: Training Bucket ---

resource "aws_s3_bucket" "training" {
  bucket = "skin-lesion-training-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "training"
  }
}

resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "training" {
  bucket = aws_s3_bucket.training.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# --- Guide 05: Secrets Manager Placeholders ---

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "skin-lesion/${var.environment}/db-password"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "database-credentials"
  }
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "skin-lesion/${var.environment}/jwt-secret"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "jwt-signing"
  }
}

resource "aws_secretsmanager_secret" "powerbi_client_secret" {
  name                    = "skin-lesion/${var.environment}/powerbi-client-secret"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "powerbi-embed"
  }
}
# --- Guide 05: ECR Repository ---

resource "aws_ecr_repository" "backend" {
  name                 = "skin-lesion-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "container-registry"
  }
}
