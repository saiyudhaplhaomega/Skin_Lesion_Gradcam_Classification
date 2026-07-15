# database.tf - Aurora DSQL staging database (D7)
#
# Aurora DSQL is the primary application database for staging and production.
# It is serverless, globally distributed, and uses IAM authentication.
#
# Enable with: enable_aurora_dsql = true in env/staging.tfvars
#
# After creating the cluster:
# 1. Get the endpoint from the SSM parameter or terraform output
# 2. Generate a connection token: aws dsql generate-db-connect-admin-auth-token
# 3. Apply Alembic migrations:
#      export DATABASE_URL="postgresql://admin:${TOKEN}@${ENDPOINT}:5432/postgres"
#      alembic upgrade head
# 4. Update the EKS deployment DATABASE_URL secret to point at the cluster
#
# See docs/staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md for the full walkthrough.

module "aurora_dsql" {
  count  = var.enable_aurora_dsql ? 1 : 0
  source = "./modules/aurora_dsql"

  project_name        = var.project_name
  environment         = var.environment
  aws_region          = var.aws_region
  deletion_protection = var.dsql_deletion_protection
}

# One IRSA role is trusted by the same named backend ServiceAccount in each
# supported environment namespace. Kubernetes manifests must annotate that
# ServiceAccount with the dsql_workload_role_arn output for their environment.
data "aws_iam_policy_document" "dsql_workload_assume_role" {
  count = var.enable_aurora_dsql ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer_url, "https://", "")}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(module.eks.oidc_issuer_url, "https://", "")}:sub"
      values = [
        "system:serviceaccount:skin-lesion-dev:skin-lesion-backend",
        "system:serviceaccount:skin-lesion-staging:skin-lesion-backend",
        "system:serviceaccount:skin-lesion-prod:skin-lesion-backend",
      ]
    }
  }
}

resource "aws_iam_role" "dsql_workload" {
  count              = var.enable_aurora_dsql ? 1 : 0
  name               = "${var.project_name}-${var.environment}-backend-dsql"
  assume_role_policy = data.aws_iam_policy_document.dsql_workload_assume_role[0].json

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "backend-dsql-irsa"
  }
}

resource "aws_iam_role_policy_attachment" "dsql_workload_connect" {
  count      = var.enable_aurora_dsql ? 1 : 0
  role       = aws_iam_role.dsql_workload[0].name
  policy_arn = module.aurora_dsql[0].connect_policy_arn

  depends_on = [module.aurora_dsql, aws_iam_role.dsql_workload]
}
