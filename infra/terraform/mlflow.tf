# --- Guide 21: Optional MLflow Server ---

resource "aws_s3_bucket" "mlflow_artifacts" {
  count  = var.enable_mlflow_server ? 1 : 0
  bucket = "${var.project_name}-mlflow-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "mlflow-artifacts"
  }
}

resource "aws_s3_bucket_public_access_block" "mlflow_artifacts" {
  count  = var.enable_mlflow_server ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "mlflow_artifacts" {
  count  = var.enable_mlflow_server ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mlflow_artifacts" {
  count  = var.enable_mlflow_server ? 1 : 0
  bucket = aws_s3_bucket.mlflow_artifacts[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_iam_role" "mlflow_ec2" {
  count = var.enable_mlflow_server ? 1 : 0
  name  = "${var.project_name}-mlflow-ec2-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy" "mlflow_s3" {
  count = var.enable_mlflow_server ? 1 : 0
  name  = "${var.project_name}-mlflow-s3-${var.environment}"
  role  = aws_iam_role.mlflow_ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          aws_s3_bucket.mlflow_artifacts[0].arn,
          "${aws_s3_bucket.mlflow_artifacts[0].arn}/*",
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "mlflow_ec2" {
  count = var.enable_mlflow_server ? 1 : 0
  name  = "${var.project_name}-mlflow-ec2-${var.environment}"
  role  = aws_iam_role.mlflow_ec2[0].name
}

resource "aws_security_group" "mlflow" {
  count       = var.enable_mlflow_server ? 1 : 0
  name        = "${var.project_name}-mlflow-${var.environment}"
  description = "Allow MLflow UI/API only from private app subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 5000
    to_port   = 5000
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private_app_a.cidr_block,
      aws_subnet.private_app_b.cidr_block,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "mlflow"
  }
}

resource "aws_instance" "mlflow" {
  count                  = var.enable_mlflow_server ? 1 : 0
  ami                    = var.mlflow_ami_id
  instance_type          = var.mlflow_instance_type
  subnet_id              = aws_subnet.private_app_a.id
  vpc_security_group_ids = [aws_security_group.mlflow[0].id]
  iam_instance_profile   = aws_iam_instance_profile.mlflow_ec2[0].name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3-pip
    pip3 install mlflow==2.19.0 boto3
    mkdir -p /opt/skin-lesion-mlflow
    cd /opt/skin-lesion-mlflow
    nohup mlflow server \
      --host 0.0.0.0 \
      --port 5000 \
      --backend-store-uri sqlite:////opt/skin-lesion-mlflow/mlflow.db \
      --default-artifact-root s3://${aws_s3_bucket.mlflow_artifacts[0].id}/artifacts/ \
      > /var/log/skin-lesion-mlflow.log 2>&1 &
  EOF

  tags = {
    Name        = "${var.project_name}-mlflow-${var.environment}"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "mlflow"
  }
}
