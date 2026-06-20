# Aurora DSQL Staging Handholding Guide

Use this after `staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md`.

This guide corrects the database direction:

```text
local Postgres for learning -> Aurora DSQL for cloud staging -> Aurora PostgreSQL only as fallback -> multi-region later
```

**What this progression means:** local Postgres is for development only (fast, free, no AWS needed). Aurora DSQL is the cloud staging target - it uses IAM authentication and is serverless. Aurora PostgreSQL is only used if DSQL blocks a milestone. Multi-region active-active comes after single-region staging is proven.

Aurora DSQL is the planned cloud database target for this project. Aurora PostgreSQL is not the default plan; it is the fallback if DSQL blocks learning, compatibility, availability, or cost.

## Current Project Implementation

This guide is intentionally documented but not applied yet.

Current repo state:

```text
Guide 10 event infrastructure exists in Terraform.
No aws_dsql_cluster resource has been committed.
No Aurora PostgreSQL fallback has been committed.
No live DSQL cluster has been created by this task.
```

Why: checking Terraform provider schema currently needs AWS/backend credentials in this workspace, and Aurora DSQL creates real hourly cost. The next DSQL step needs an explicit AWS SSO/console/CLI moment from you before I create or apply anything.

When you are ready, I will ask before running any of these:

```powershell
aws sso login
aws dsql create-cluster
terraform apply -var-file="env/staging.tfvars"
kubectl config updates for staging
```

> **One exception, decided in advance: the RAG vector index.** When you build the RAG features (`product/07`, `product/14`, `product/15`), the vector index needs the `pgvector` extension, and DSQL's extension support does not include it as far as is known. That is not a DSQL "blocker" to work around; it is an expected split. Transactional data stays on DSQL, and the vector index lives on a pgvector-capable Postgres (Aurora PostgreSQL or a small dedicated RDS PostgreSQL) in the same VPC, or on OpenSearch Serverless vector search. See `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.3. While you are here, it is worth confirming exactly which extensions DSQL does and does not support and noting it, since `local-dev/04` deliberately avoids extensions until this guide confirms them.

## Goal

Validate Aurora DSQL as the staging database target by connecting a local app to a DSQL instance before committing to it as the production database direction.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. AWS CLI commands for DSQL run from here.

Run Terraform commands from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before any `terraform` command. DSQL Terraform resources live in this directory.

Run backend migration checks from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** `cd Skin_Lesion_Classification_backend` before running `alembic` or `pytest` commands. The database URL for migrations is set as an environment variable pointing to DSQL.

Use two terminals when validating staging:

```text
Terminal 1: infra/terraform for infrastructure plan
Terminal 2: Skin_Lesion_Classification_backend for Alembic and API checks
```

**What this setup does:** keeps Terraform commands and application commands in separate shells so directory changes in one terminal do not affect the other.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit DSQL and database Terraform resources under `infra/terraform/`.
- Run Alembic, pytest, and API checks from `Skin_Lesion_Classification_backend/`.

## Parameters You Must Set First

Set these before writing cloud database code:

```text
AWS_REGION=us-east-1
ENVIRONMENT=staging
DSQL_CLUSTER_NAME_TAG=skin-lesion-staging-dsql
DSQL_DELETION_PROTECTION=true
DSQL_KMS_KEY_ALIAS=alias/skin-lesion-staging-dsql
DSQL_ACCESS_VPC_ID=<vpc id from the VPC guide>
DSQL_ADMIN_ROLE_NAME=skin-lesion-staging-dsql-admin
DSQL_APP_ROLE_NAME=skin-lesion-staging-dsql-app
DATABASE_NAME=skin_lesion
DSQL_CONFIG_SECRET_NAME=/skin-lesion/staging/dsql-config
DSQL_DB_ROLE=admin for first migration validation, custom role later
FALLBACK_ENGINE=aurora-postgresql
```

**What these parameters mean:**

- `DSQL_DELETION_PROTECTION=true` - the cluster cannot be deleted until this is explicitly disabled. Guards against accidental `terraform destroy` while the cluster holds staging data.
- `DSQL_KMS_KEY_ALIAS` - the KMS key that encrypts DSQL data at rest. Use the same key alias from the storage guide.
- `DSQL_ACCESS_VPC_ID` - the VPC where PrivateLink endpoints are created so the backend pods can reach DSQL privately.
- `DSQL_ADMIN_ROLE_NAME` / `DSQL_APP_ROLE_NAME` - two IAM roles: admin for running Alembic migrations, app for normal backend queries. Least-privilege separation.
- `DSQL_CONFIG_SECRET_NAME` - the Secrets Manager path where DSQL connection details (endpoint, region, database name) are stored. The app reads this at startup instead of hardcoding values.
- `DSQL_DB_ROLE=admin` - use the admin database role for the first migration run to verify schema creation works, then switch to a more restricted custom role for ongoing app connections.

**Where these parameters are saved:** this guide is for the staging environment, so the values go into the staging Terraform variable file `infra/terraform/env/staging.tfvars` (not `dev.tfvars`). The corresponding `variable` blocks (the declarations that receive these values) must be added to `infra/terraform/variables.tf` first — same pattern as guide 05 Step 0 created 5 dev variables. The DSQL-specific values are *staging-only* and do not exist in the current `variables.tf` (which has only dev variables). Do not put staging values in `dev.tfvars`. Do not put real secret values in any `.tfvars` file — secrets go into AWS Secrets Manager, not Terraform.

**Before editing `variables.tf` and `staging.tfvars`:** verify guide 05 Step 0 created `infra/terraform/variables.tf` and `infra/terraform/env/dev.tfvars` already. If those files do not exist, go back and complete guide 05 first.

Expected result:

```text
You know the target region, cluster name, access boundary, secret name, and fallback engine before creating anything.
```

**What this means:** filling in all parameters before writing any Terraform prevents ad-hoc naming decisions that break consistency between guides.

Why: DSQL touches IAM, network access, secrets, and migrations. Choosing parameters first prevents random cloud resources.

## Step 1: Confirm Tool Support

Run from the repo root:

```powershell
aws dsql help
aws dsql get-vpc-endpoint-service-name help
terraform providers
```

**What these commands do:** `aws dsql help` lists all available DSQL subcommands - if this fails with "Invalid choice", the AWS CLI version does not support DSQL and must be updated before continuing. `aws dsql get-vpc-endpoint-service-name help` verifies the specific subcommand used in Step 3 is available. `terraform providers` lists the installed provider versions - the AWS provider must be 5.x or later to support `aws_dsql_cluster`.

Expected result:

```text
AWS CLI shows dsql commands.
Terraform AWS provider is installed after terraform init.
```

**What this means:** both tools recognize DSQL. If either fails, update the tool before creating any DSQL resources.

If the AWS provider in your environment does not support the DSQL resource you want to use yet, stop and use the AWS CLI path for learning first. Do not replace DSQL with Aurora PostgreSQL unless DSQL blocks the staging goal.

Why: Aurora DSQL support may depend on AWS CLI and Terraform provider versions. The guide must verify tooling before applying infrastructure.

## Step 2: Add The DSQL Cluster Resource

Create or edit:

```text
infra/terraform/dsql.tf
```

Start with a single-region staging cluster:

```hcl
resource "aws_dsql_cluster" "main" {
  deletion_protection_enabled = true

  tags = {
    Name        = "skin-lesion-staging-dsql"
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "staging-database"
  }
}
```

**What this HCL does:** creates an Aurora DSQL cluster. DSQL is serverless - there are no instance types or storage configuration. `deletion_protection_enabled = true` prevents the cluster from being accidentally destroyed. The tags identify it across the AWS console, cost reports, and CloudTrail logs.

Check:

```powershell
cd infra/terraform
terraform fmt
terraform validate
terraform plan -var-file="env/staging.tfvars"
```

**What these commands do:** `terraform fmt` formats the new `.tf` file. `terraform validate` checks the resource syntax. `terraform plan` shows what will be created - should show exactly one `aws_dsql_cluster.main` and no RDS or Aurora PostgreSQL resources.

Expected result:

```text
Terraform plans one Aurora DSQL cluster for staging.
No Aurora PostgreSQL or RDS instance is planned as the default database.
```

**What this means:** the plan contains only DSQL. If any `aws_db_instance` or `aws_rds_cluster` resource appears in the plan here, it was added by mistake - remove it before applying.

If `aws_dsql_cluster` is not supported by the installed provider, use the AWS CLI learning command only after reviewing cost and deletion behavior:

```powershell
aws dsql create-cluster --region us-east-1 --tags Name=skin-lesion-staging-dsql,Project=skin-lesion,Environment=staging,Purpose=staging-database
```

**What this does:** creates the DSQL cluster directly via AWS CLI when the Terraform provider does not support `aws_dsql_cluster` yet. The cluster starts billing immediately at approximately $3.50 per hour - disable deletion protection and destroy it before stopping for the day.

Why: Terraform is preferred for repeatable cloud setup, but the project decision is DSQL itself, not a specific tool shortcut.

Beginner stop point for this repo:

```text
Do not add aws_dsql_cluster until terraform provider support is confirmed in an authenticated AWS/Terraform session.
Do not use Aurora PostgreSQL fallback unless the failed DSQL check is written in docs/reference/04_RECOVERY_AND_SOURCE_NOTES.md.
```

## Step 3: Create DSQL PrivateLink Endpoints

Aurora DSQL private connectivity needs interface VPC endpoints.

Create the management endpoint first. Run from the repo root:

```powershell
aws ec2 create-vpc-endpoint `
  --region us-east-1 `
  --service-name com.amazonaws.us-east-1.dsql `
  --vpc-id <your-vpc-id> `
  --subnet-ids <private-app-subnet-id-1> <private-app-subnet-id-2> `
  --vpc-endpoint-type Interface `
  --security-group-ids <app-or-dsql-client-security-group-id>
```

**What this does:** creates an interface VPC endpoint for DSQL management calls. `--vpc-endpoint-type Interface` creates a private ENI (Elastic Network Interface) inside the subnets you specify - management traffic routes through this ENI instead of the public internet. Replace `<your-vpc-id>` with the VPC ID from the VPC guide and `<private-app-subnet-id-*>` with the private app subnet IDs.

Expected result:

```text
AWS creates an interface endpoint for Aurora DSQL management calls.
Private DNS remains enabled.
```

**What this means:** the endpoint is in `pending` state briefly, then becomes `available`. Private DNS means calls to the DSQL management hostname automatically resolve to the private endpoint IP.

After the DSQL cluster exists, get the cluster-specific connection endpoint service name:

```powershell
aws dsql get-vpc-endpoint-service-name `
  --region us-east-1 `
  --identifier <dsql-cluster-id>
```

**What this does:** retrieves the unique service name for this cluster's connection endpoint. Each DSQL cluster has its own endpoint service name, different from the shared management endpoint.

Expected result:

```text
AWS returns a service name like com.amazonaws.us-east-1.dsql-xxxx.
```

**What this means:** copy this service name for use in the next command. The `xxxx` part is unique to your cluster.

Create the connection endpoint:

```powershell
aws ec2 create-vpc-endpoint `
  --region us-east-1 `
  --service-name <service-name-from-get-vpc-endpoint-service-name> `
  --vpc-id <your-vpc-id> `
  --subnet-ids <private-app-subnet-id-1> <private-app-subnet-id-2> `
  --vpc-endpoint-type Interface `
  --security-group-ids <app-or-dsql-client-security-group-id>
```

**What this does:** creates a second endpoint - the one the backend app uses to send SQL queries to DSQL. The service name from the previous step determines which cluster this endpoint connects to.

Check:

```powershell
aws ec2 describe-vpc-endpoints --filters Name=vpc-id,Values=<your-vpc-id>
```

**What this does:** lists all interface endpoints in the VPC. Both the management endpoint and the connection endpoint should appear with state `available` (or `pending` briefly after creation).

Expected result:

```text
Both DSQL interface endpoints are present or pending.
Backend traffic can later reach DSQL through private networking.
```

**What this means:** both endpoints exist. The backend pods running in the private app subnets can now reach DSQL without leaving the VPC.

Why: Power BI, backend services, and workers must never turn the staging database into a public data source. PrivateLink keeps requests to Aurora DSQL on AWS private networking.

## Step 4: Store DSQL Config In Secrets Manager

Create or edit Terraform secrets in:

```text
infra/terraform/secrets.tf
```

Add the secret container:

```hcl
resource "aws_secretsmanager_secret" "dsql_config" {
  name = "/skin-lesion/staging/dsql-config"

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
```

**What this resource does:** creates the secret container in Secrets Manager. No value is set by Terraform - only the name and tags. The actual JSON value is set manually with the AWS CLI (see below). This keeps connection details out of `.tf` files and git history.

Do not paste a live password or auth token into Git.

Store configuration values such as:

```json
{
  "region": "us-east-1",
  "cluster_endpoint": "<cluster-id>.dsql.us-east-1.on.aws",
  "database": "postgres",
  "role": "admin"
}
```

**What these fields mean:** `cluster_endpoint` is the DSQL hostname the app connects to. `database` is the PostgreSQL database name (DSQL defaults to `postgres`). `role` determines what permissions the connection gets. The app reads this JSON at startup and uses these values to construct the connection string - then calls `aws dsql generate-db-connect-auth-token` at connection time to get the password.

Do not store the generated auth token as a long-lived secret.

Check:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** verifies the secrets file is valid HCL and shows that only the secret metadata (name, tags) will be created - not any secret value.

Expected result:

```text
Terraform plans the secret metadata only. No plaintext database credential or DSQL auth token appears in Git or terminal output.
```

**What this means:** the Terraform plan contains only `aws_secretsmanager_secret.dsql_config` with no `secret_string` value. The actual DSQL auth token is generated at runtime per connection - it expires in 15 minutes and is never stored.

Why: Aurora DSQL uses IAM authentication tokens as the database password. The backend should read stable DSQL config from the cloud secret store and generate short-lived auth tokens when opening new database connections.

## Step 5: Validate Migrations Against DSQL

Run from:

```text
Skin_Lesion_Classification_backend
```

Generate a temporary admin auth token, then assemble a one-session connection string for migration validation:

```powershell
$env:DSQL_ENDPOINT="<cluster-id>.dsql.us-east-1.on.aws"
$env:DSQL_TOKEN=(aws dsql generate-db-connect-admin-auth-token --region us-east-1 --expires-in 3600 --hostname $env:DSQL_ENDPOINT)
$env:DSQL_TOKEN_URLENCODED=[uri]::EscapeDataString($env:DSQL_TOKEN)
$env:DATABASE_URL="postgresql+psycopg://admin:$env:DSQL_TOKEN_URLENCODED@$env:DSQL_ENDPOINT:5432/postgres?sslmode=require"
alembic upgrade head
alembic current
pytest
```

**What this block does line by line:**

- `$env:DSQL_ENDPOINT` - sets the DSQL cluster hostname in the session. Replace `<cluster-id>` with the actual cluster identifier from the AWS console or `aws dsql list-clusters`.
- `aws dsql generate-db-connect-admin-auth-token` - generates a short-lived IAM authentication token (like a signed URL) that acts as the PostgreSQL password for this session. `--expires-in 3600` makes it valid for one hour. `--hostname` must match the endpoint you connect to.
- `$env:DSQL_TOKEN_URLENCODED` - the token contains characters that break URL parsing if used raw. `[uri]::EscapeDataString()` percent-encodes them so they survive the connection string.
- `$env:DATABASE_URL` - assembles the full SQLAlchemy connection string. `postgresql+psycopg://` uses the psycopg3 driver. `admin` is the DSQL admin role. The URL-encoded token is the password. `sslmode=require` is mandatory for DSQL.
- `alembic upgrade head` - runs all pending database migrations against DSQL. Uses the `DATABASE_URL` set above.
- `alembic current` - shows which migration revision the database is currently at, confirming migrations ran successfully.
- `pytest` - runs the backend test suite with the DSQL connection active to verify SQL compatibility.

Expected result:

```text
Alembic migrations apply cleanly.
Backend tests pass with a DSQL connection that uses an IAM auth token.
No migration depends on unsupported PostgreSQL extensions or local-only behavior.
```

**What this means:** all three checks pass. If a migration fails, check for DSQL-incompatible syntax (some PostgreSQL extensions, `SERIAL` in certain contexts, or database-specific features that DSQL does not support).

If a migration fails:

1. fix the migration to be PostgreSQL-compatible with DSQL
2. rerun `alembic upgrade head`
3. only use Aurora PostgreSQL fallback if DSQL blocks the staging milestone after the incompatibility is documented

Why: `DATABASE_URL` can still be the local app abstraction, but DSQL authentication requires token generation. Staging is where both SQL compatibility and auth behavior are proven.

## Step 6: Connect The Backend In Staging

Create or edit the backend deployment environment in the staging deployment guide or Kubernetes secret path:

```text
infra/k8s/overlays/staging/
```

**What this directory is:** the staging-specific Kubernetes overlay. Environment variables, secrets references, and image tags specific to staging go here without modifying the base dev manifests.

Set the backend to read:

```text
DSQL config from /skin-lesion/staging/dsql-config
IAM permissions for dsql:DbConnectAdmin during first validation
custom database role and dsql:DbConnect later
```

**What this configuration means:** the pod reads the DSQL endpoint and database name from the Secrets Manager path at startup. The pod's IAM role (via IRSA - IAM Roles for Service Accounts) must have `dsql:DbConnectAdmin` permission to generate admin auth tokens for migrations. After validation, switch to a custom role and `dsql:DbConnect` for read/write app queries with least privilege.

Check:

```powershell
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
kubectl exec -n skin-lesion-staging deploy/skin-lesion-backend -- python -c "from app.core.config import settings; print('database config loaded')"
```

**What these commands do:** `kubectl rollout status` confirms the staging deployment is healthy. The `kubectl exec` command runs a Python one-liner inside the running container to verify the app's settings object loads the DSQL config from Secrets Manager without error.

Expected result:

```text
The backend rollout succeeds, DSQL config loads from Secrets Manager, and application database connections generate DSQL auth tokens instead of using a static password.
```

**What this means:** the full staging path works - the pod is running, the config is loading from the cloud secret store, and connections authenticate with temporary IAM tokens instead of a static password stored in environment variables.

Why: staging must prove the app runs against the intended cloud database, not only against local development state.

## Step 7: Fallback Rule

Use Aurora PostgreSQL only when one of these is true:

```text
DSQL is unavailable in the chosen region.
Terraform or AWS CLI support blocks a learning milestone.
A required PostgreSQL feature is not compatible with DSQL.
Cost or quota blocks the staging exercise.
```

**What these conditions mean:** DSQL is a newer service with limited regional availability and occasional tooling gaps. If none of these four blockers apply, use DSQL as planned.

If fallback is used, document it in:

```text
docs/reference/04_RECOVERY_AND_SOURCE_NOTES.md
```

**What this file is:** the recovery notes doc where architectural decisions that deviate from the plan are recorded with context. Writing the reason here ensures future work can come back to DSQL once the blocker is resolved.

Include:

```text
date
reason
failed DSQL check
temporary fallback database
what must be fixed before returning to DSQL
```

**What these fields capture:** enough context to understand why the fallback was taken and what needs to change to get back to DSQL. Without this, the fallback silently becomes permanent.

Expected result:

```text
Aurora PostgreSQL is treated as a temporary compatibility fallback, not a silent change in architecture.
```

**What this means:** the decision is documented and the plan still targets DSQL. Aurora PostgreSQL is a workaround, not the new direction.

## Completion Gate

Staging database work is complete only when:

```text
DSQL cluster exists or has a documented blocker
DSQL config secret exists
backend migrations run against DSQL with an IAM auth token
backend tests pass against DSQL with token-based authentication
backend staging deployment reads DSQL config and generates auth tokens
Power BI analytics views are planned against analytics-safe SQL, not raw patient tables
Aurora PostgreSQL fallback is documented only if used
```

**What this gate means:** each condition is a concrete, verifiable check. Work is not done until all seven are confirmed. Multi-region work starts from a proven single-region baseline, not a partially working one.

Do not move to multi-region active-active until this single-region DSQL gate passes.

## DSQL Shutdown Procedure (CRITICAL - Read Before Creating The Cluster)

Aurora DSQL costs approximately $3.50 per hour when active. The Terraform resource has `deletion_protection_enabled = true`, which means `terraform destroy` will fail unless you disable it first.

**Before running `make cloud-shutdown` or `terraform destroy`, always run this first:**

```powershell
# 1. Get the DSQL cluster ID
aws dsql list-clusters --query "clusters[?tags.Environment=='staging'].identifier" --output text

# 2. Disable deletion protection
aws dsql update-cluster --identifier <YOUR_CLUSTER_ID> --no-deletion-protection-enabled

# 3. Now destroy is safe
cd infra/terraform
terraform destroy -var="environment=staging" -target=aws_dsql_cluster.main -auto-approve
```

**What this shutdown sequence does:**

- `aws dsql list-clusters` with the JMESPath query finds the cluster ID by its Environment tag, so you do not have to look it up manually in the console.
- `aws dsql update-cluster --no-deletion-protection-enabled` disables the deletion protection that was set to `true` in Step 2. Without this step, `terraform destroy` fails with a deletion protection error and the cluster keeps running (and billing).
- `terraform destroy -target=aws_dsql_cluster.main` destroys only the DSQL cluster, leaving other infrastructure (VPC, S3, ECR) intact.

Or update the Terraform resource temporarily before destroying:

```hcl
# In your DSQL Terraform resource, change to false before destroy:
resource "aws_dsql_cluster" "main" {
  deletion_protection_enabled = false   # <- change this before terraform destroy
  ...
}
```

**What this approach does:** sets `deletion_protection_enabled = false` in the Terraform resource so the next `terraform apply` disables protection through Terraform instead of the CLI. Useful if you prefer keeping all infrastructure changes in Terraform.

```powershell
terraform apply -var="environment=staging" -auto-approve   # apply the false value
terraform destroy -var="environment=staging" -target=aws_dsql_cluster.main -auto-approve
```

**What these commands do:** `terraform apply` first pushes the `deletion_protection_enabled = false` change to AWS. Then `terraform destroy -target` destroys the cluster. Both `-auto-approve` flags skip confirmation prompts - only use this when you are certain about what will be destroyed.

**If you forgot and `terraform destroy` failed:** The cluster is still running and billing. Run the `aws dsql update-cluster` CLI command above first, then retry the destroy.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports the current state of dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev resources - for this guide, the DSQL cluster must have deletion protection disabled first (see the shutdown procedure above) before this command can complete successfully.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms the environment is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
