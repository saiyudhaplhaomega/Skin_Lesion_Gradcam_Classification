# Terraform Database And Events Handholding Guide

Use this after VPC, storage, secrets, and ECR are understood.

This guide integrates the ideas from the old `rds` and `sns` modules and connects them to the SQS/EventBridge workflow guides.

## Current Project Implementation

Guide 10 is now implemented as the first safe event layer, not as a database fallback switch.

Files created or edited:

```text
infra/terraform/events.tf
infra/terraform/outputs.tf
infra/terraform/variables.tf
```

What exists now:

```text
SNS notifications topic
SQS FIFO training workflow queue
SQS FIFO dead-letter queue
EventBridge custom event bus
EventBridge rule for training_case.admin_approved
Queue policy allowing EventBridge to send to SQS
Terraform outputs for topic, queue, DLQ, and event bus
```

What does not exist yet:

```text
Aurora PostgreSQL fallback
RDS instance
Public database ingress
```

Why: EKS is the runtime path from Guides 08 and 09. The database remains Aurora DSQL for staging in Guide 11. This guide only adds the shared notification and event primitives that later guides can safely reference.

## Command Location

Run commands from the main workspace first:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. AWS CLI commands and backend validation commands run from here.

Then run Terraform commands from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before running any `terraform` command. Terraform looks for `.tf` files relative to its working directory.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Backend repo, only when a step explicitly names backend code: `Skin_Lesion_Classification_backend/`
- Create or edit database, SNS, SQS, and EventBridge Terraform resources under `infra/terraform/`.
- Run backend migration checks from `Skin_Lesion_Classification_backend/` only when a step says to validate application behavior.

## Goal

Add durable state and event notifications in this order:

```text
database access boundary -> Aurora DSQL staging target -> Aurora PostgreSQL fallback only if blocked -> SNS -> SQS/EventBridge later
```

## Parameters You Must Set First

```text
ENVIRONMENT=dev
DB_IDENTIFIER=skin-lesion-dev
DB_NAME=skin_lesion
DB_USERNAME=skinlesionadmin
DSQL_CLUSTER_NAME_TAG=skin-lesion-staging-dsql
DSQL_DELETION_PROTECTION=true
DSQL_CONFIG_SECRET_NAME=/skin-lesion/staging/dsql-config
FALLBACK_ENGINE=aurora-postgresql only if DSQL blocks staging
NOTIFICATIONS_TOPIC=skin-lesion-dev-notifications
```

**What these parameters mean:**

- `DB_IDENTIFIER=skin-lesion-dev` - the RDS instance identifier, used only if the fallback Aurora PostgreSQL path is taken.
- `DSQL_CLUSTER_NAME_TAG=skin-lesion-staging-dsql` - a tag applied to the Aurora DSQL cluster to identify it. DSQL resources are created with the AWS CLI or console, not directly in Terraform.
- `DSQL_DELETION_PROTECTION=true` - prevents accidental deletion of the DSQL cluster. Must be explicitly disabled before you can delete the cluster.
- `DSQL_CONFIG_SECRET_NAME=/skin-lesion/staging/dsql-config` - the Secrets Manager path where the DSQL connection details (endpoint, token, etc.) are stored for the app to read.
- `FALLBACK_ENGINE=aurora-postgresql` - only used if DSQL is unavailable or blocking the staging milestone. Document the reason before switching to the fallback.
- `NOTIFICATIONS_TOPIC=skin-lesion-dev-notifications` - the name for the SNS topic that CloudWatch alarms, GuardDuty alerts, and deployment events publish to.

The file path to edit is:

```text
infra/terraform/main.tf
```

**What this means:** all Terraform resource blocks in this guide are appended to the existing `main.tf`.

## Step 1: Database Access Boundary

Use the VPC from the VPC guide as the access boundary for the cloud database.

For Aurora DSQL, create AWS PrivateLink interface endpoints that keep management and database connection traffic inside the intended AWS boundary. Do not expose database access to the public internet.

PrivateLink endpoint types you will create in the DSQL guide:

```text
management endpoint: com.amazonaws.<region>.dsql
connection endpoint: cluster-specific service name from aws dsql get-vpc-endpoint-service-name
```

**What these endpoints are:** PrivateLink creates a private network interface inside your VPC that routes to the AWS service. The `management endpoint` handles DSQL cluster operations (create, delete, status). The `connection endpoint` is cluster-specific and is where the app sends SQL queries. Both stay inside the VPC - no traffic leaves to the public internet.

Why: the planned cloud database is Aurora DSQL, and access control must be designed before the app connects.

## Step 2: Aurora PostgreSQL Fallback Subnet Group

Only add this fallback subnet group if Aurora DSQL blocks the staging milestone and you explicitly document the fallback reason.

Fallback resource shape:

File path:

```text
infra/terraform/main.tf
```

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "skin-lesion-db-subnet-dev"
  subnet_ids = [aws_subnet.private_data_a.id]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}
```

**What this resource does:** `aws_db_subnet_group` is a named collection of subnets that RDS or Aurora PostgreSQL places its instances into. `subnet_ids = [aws_subnet.private_data_a.id]` places the database into the private data subnet (10.0.21.x) from the VPC guide - not reachable from the internet. Aurora requires at least two subnets in different AZs for production; one is enough for the dev fallback path.

Why: Aurora PostgreSQL fallback needs private data subnets. Aurora DSQL remains the intended cloud target.

## Step 3: Aurora PostgreSQL Fallback Security Group

Only add this if using the fallback path:

File path:

```text
infra/terraform/main.tf
```

```hcl
resource "aws_security_group" "database" {
  name        = "skin-lesion-db-sg-dev"
  description = "Allow PostgreSQL from app security group only"
  vpc_id      = aws_vpc.main.id
}
```

**What this resource does:** creates a security group for the database that starts with no inbound rules (deny by default). The ingress rule added in the next step restricts PostgreSQL access to only the app's security group - not from any IP address directly.

If fallback is used, add ingress from the backend/EKS app security group only:

```text
from_port=5432
to_port=5432
source=app workload security group
```

**What this ingress rule means:** allows TCP traffic on port 5432 (PostgreSQL default port) only from pods running in the app security group. Nothing else - no `0.0.0.0/0`, no management IPs - can reach the database port.

Do not allow `0.0.0.0/0` to PostgreSQL.

## Step 4: Aurora DSQL Is The Planned Cloud Database

Use:

```text
docs/staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md
```

**What this guide covers:** creating the Aurora DSQL cluster, configuring PrivateLink endpoints, running Alembic database migrations against it using an IAM-generated auth token, and running backend tests to verify the connection works.

That guide creates and validates the planned staging database.

Expected result:

```text
Terraform or AWS CLI plans an Aurora DSQL cluster for staging.
Alembic migrations run against DSQL with an IAM auth token.
Backend tests pass against DSQL with generated connection credentials.
```

**What this result means:** all three validations pass - DSQL is provisioned, migrations applied cleanly, and the backend can connect and query it. Only after this result is confirmed should the staging deployment use DSQL instead of local Postgres.

Why: the project plan is to learn local Postgres first, then use Aurora DSQL as the cloud database target.

## Step 5: Aurora PostgreSQL Fallback Only

Add a dev-sized Aurora PostgreSQL or RDS PostgreSQL database only if DSQL blocks you.

Fallback example:

File path:

```text
infra/terraform/main.tf
```

```hcl
resource "aws_db_instance" "main" {
  identifier             = "skin-lesion-dev"
  engine                 = "postgres"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  username               = "skinlesionadmin"
  password               = "CHANGE_ME_USE_SECRET_VALUE_LATER"
  publicly_accessible    = false
  skip_final_snapshot    = true
}
```

**What this resource does:** creates a single RDS PostgreSQL instance as a fallback. `instance_class = "db.t3.micro"` is the smallest available size - cheapest option for learning. `allocated_storage = 20` gives 20 GB of storage. `publicly_accessible = false` keeps the instance inside the VPC only. `skip_final_snapshot = true` skips the automated final backup when the instance is destroyed - saves time when tearing down dev resources. Do not use `skip_final_snapshot = true` in production. `password = "CHANGE_ME_USE_SECRET_VALUE_LATER"` - replace this with a value from Secrets Manager before applying.

Beginner rule:

```text
Do not apply this unless the DSQL blocker is written down and you understand monthly database cost and shutdown behavior.
```

**What this means:** a `db.t3.micro` RDS instance costs roughly $13-18 per month when running continuously. If you apply it and forget about it, it will accumulate charges. Document the DSQL blocker first so there is a record of why the fallback was taken.

## Step 6: SNS Notifications Topic

Add:

File path:

```text
infra/terraform/main.tf
```

```hcl
resource "aws_sns_topic" "notifications" {
  name = "${var.project_name}-${var.environment}-notifications"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "notifications"
  }
}
```

**What this resource does:** creates an SNS (Simple Notification Service) topic as a fan-out hub. Other AWS services (CloudWatch alarms, GuardDuty findings, Lambda functions) publish events to this topic. Subscribers (email, Slack webhooks, PagerDuty) receive those events. Creating it as a placeholder now means later guides can reference it without re-running Terraform for the foundational resources.

Why: CloudWatch, GuardDuty, Lambda, and deployment alarms need a common notification topic later.

## Step 7: SQS And EventBridge Gate

The existing event workflow is user-driven:

```text
consent -> doctor validation -> admin approval -> training write
```

**What this workflow means:** the event flow starts with a patient giving consent for their image to be used in training. Then a doctor reviews and validates the image. Then an admin approves it. Only after both approvals does the image move to the `approved/` prefix in the training bucket. Building this locally first lets you verify the business logic before adding messaging infrastructure.

Build locally first, then add:

```text
SQS queue
dead-letter queue
EventBridge rule
worker deployment
idempotency checks
```

**What each piece does:** the SQS queue buffers approval events so the worker processes them at its own pace. The dead-letter queue (DLQ) catches messages that the worker failed to process after the maximum retry count. The EventBridge rule routes events from multiple sources into SQS. The worker deployment is an EKS pod that reads from SQS and processes approvals. Idempotency checks prevent a message from being processed twice if SQS delivers it more than once.

Do not add Airflow for this workflow.

In the current repo, this guide also creates the queue and EventBridge shell because the backend state model already exists enough for local workflow tests. The cloud resources are still only planned until you explicitly approve AWS apply:

File path:

```text
infra/terraform/events.tf
```

Check command:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
terraform fmt -recursive
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform validates the SNS topic, SQS FIFO queue, DLQ, EventBridge bus, rule, target, and queue policy.
No RDS or Aurora PostgreSQL fallback resources appear.
```

Why: queue resources are low-risk to describe and validate in Terraform, but they still create AWS resources and possible charges if applied. Do not run `terraform apply` until you intentionally enter the AWS-cost step.

## Checks

Run from:

```text
infra/terraform
```

Commands:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

**What these commands do:** `terraform fmt` formats the HCL. `terraform validate` checks all resource references and syntax. `terraform plan` previews the resources this guide adds - the plan should show the SNS topic (always), the PrivateLink endpoints (for DSQL), and the fallback subnet group/security group/RDS instance only if the fallback path was taken.

Expected result:

```text
Terraform plans DSQL-oriented database access, fallback resources only if documented, and notification resources without exposing database access publicly.
```

**What this means:** the plan shows the expected resources and no database security groups allow `0.0.0.0/0` ingress. The database lives in private subnets only.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports the current state of dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment - if the fallback RDS instance was applied, this command destroys it and stops the hourly charges.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms the environment came back healthy.

If this guide was local-only, no cloud shutdown is needed.
