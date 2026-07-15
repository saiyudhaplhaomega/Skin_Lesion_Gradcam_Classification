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
  deletion_protection = var.dsql_deletion_protection
}

# The backend ServiceAccount can assume only one IRSA role. When DSQL is
# enabled, attach its connect policy to the general-purpose backend role.
resource "aws_iam_role_policy_attachment" "dsql_workload_connect" {
  count      = var.enable_aurora_dsql ? 1 : 0
  role       = aws_iam_role.backend_workload.name
  policy_arn = module.aurora_dsql[0].connect_policy_arn

  depends_on = [module.aurora_dsql, aws_iam_role.backend_workload]
}
