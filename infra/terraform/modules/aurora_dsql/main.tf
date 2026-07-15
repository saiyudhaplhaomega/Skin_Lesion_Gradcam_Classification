# Aurora DSQL Cluster (D7)
#
# Aurora DSQL is a serverless distributed SQL service - no instances to size,
# no VPC required, IAM authentication only (no passwords).
#
# Prerequisites in the AWS account:
#   - Provider version >= 5.78.0 (aws_dsql_cluster resource)
#   - DSQL is available in us-east-1 and us-east-2 only (as of 2026-06)
#   - The backend IRSA workload role needs dsql:DbConnectAdmin on this cluster
#
# Connection from the backend:
#   1. Generate an IAM auth token: aws dsql generate-db-connect-admin-auth-token
#   2. Use as the password in: postgresql://admin:{token}@{endpoint}:5432/postgres
#
# In practice the backend uses the Aurora DSQL IAM token refresher sidecar or
# the generate_token() helper in app/db/session.py.

resource "aws_dsql_cluster" "main" {
  deletion_protection_enabled = var.deletion_protection

  # Deliberate destroy speed bump: intentionally tear down DSQL only after
  # first removing this lifecycle block, then applying that change.
  # The parent module creates this resource only when DSQL is enabled.
  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-dsql"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# aws_dsql_cluster exposes no `endpoint` attribute - the connection hostname
# is derived from the cluster identifier and region. Read the region from the
# provider itself rather than threading it through as a variable, so it can
# never drift from where the cluster actually gets created.
# See: https://docs.aws.amazon.com/aurora-dsql/latest/userguide/CLI_connect.html
data "aws_region" "current" {}

locals {
  dsql_endpoint = "${aws_dsql_cluster.main.identifier}.dsql.${data.aws_region.current.name}.on.aws"
}

# Store the cluster endpoint in SSM so the backend can read it at startup
resource "aws_ssm_parameter" "dsql_endpoint" {
  name        = "/${var.project_name}/${var.environment}/dsql/endpoint"
  type        = "String"
  value       = local.dsql_endpoint
  description = "Aurora DSQL cluster endpoint for ${var.environment}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM policy allowing the dedicated backend IRSA role to connect to DSQL.
data "aws_iam_policy_document" "dsql_connect" {
  statement {
    sid    = "AllowDSQLAdminConnect"
    effect = "Allow"
    actions = [
      "dsql:DbConnectAdmin",
      "dsql:DbConnect",
    ]
    resources = [aws_dsql_cluster.main.arn]
  }
}

resource "aws_iam_policy" "dsql_connect" {
  name        = "${var.project_name}-${var.environment}-dsql-connect"
  description = "Allow EKS pods to authenticate to Aurora DSQL"
  policy      = data.aws_iam_policy_document.dsql_connect.json

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
