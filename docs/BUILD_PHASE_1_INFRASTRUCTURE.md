# Skin Lesion Platform - Terraform Infrastructure

**Hardened AWS infrastructure implementing Tier 1-3 defensive controls.**

---

## Before You Apply: Critical Questions to Answer First

Work through these before running `make apply`. Infrastructure mistakes are expensive to fix and some (like security group misconfiguration) are dangerous.

### System Architect Questions
- [ ] **Are ECS tasks in the App subnet, NOT the public subnet?** Verify your ECS service Terraform resource uses `app_subnet_ids`, not `public_subnet_ids`. Tasks with public IPs bypass the ALB and all security controls. Check the `aws_ecs_service` resource: `assign_public_ip = "DISABLED"`.
- [ ] **Is ElastiCache (Redis) provisioned?** There is no ElastiCache module in the current Terraform. Without a shared Redis instance, running multiple ECS tasks (3 are shown in the architecture) means each task has its own in-memory predictions store. A `/explain` call routed to a different task than the `/predict` call will return 404. This is a required module before backend deployment.
- [ ] **Is there a Terraform module for MLflow?** MLflow is referenced in the architecture and all backend docs but has no Terraform resource. It needs an ECS service, an RDS backing store, an S3 artifact bucket, a security group, and a VPN or bastion for admin access to the UI. Plan this before any model training code goes into CI/CD.
- [ ] **Does the ECS service have `health_check_grace_period_seconds = 120`?** Model weights load from S3 at container startup (20-40 seconds). Without a grace period, ECS will kill tasks in a restart loop before the model is ready. This must be set before first deployment.
- [ ] **Are SQS queues provisioned for the training pipeline?** The training curation pipeline (consent → doctor validation → admin approval → S3 write) has no message queue. Without SQS, each step is a synchronous API call with no retry on failure. Add an SQS module with queues for each pipeline stage and a DLQ for failed events.

### Data Engineer Questions
- [ ] **Is S3 bucket versioning enabled for the training bucket?** Already done (good). But confirm the lifecycle policy includes: delete objects in `rejected/` after 30 days, delete objects in `exports/` after 7 days, and abort incomplete multipart uploads after 1 day.
- [ ] **Is KMS encryption enabled for RDS?** Already done. Confirm the same KMS key is used for ElastiCache when you provision it - patient prediction data in Redis must be encrypted at rest too.
- [ ] **Is there a dedicated S3 bucket for MLflow artifacts?** MLflow stores model artifacts, metrics plots, and run metadata in S3. This bucket should have versioning enabled (models are versioned), a separate KMS key (model weights are sensitive), and no lifecycle deletion policy (artifacts must be retained for audit).
- [ ] **Are RDS automated backups configured?** Verify `backup_retention_period = 7` (or higher) and `backup_window = "03:00-04:00"` (off-peak) in the RDS module. The current rollback procedures mention point-in-time recovery - that requires automated backups to be enabled.

### Security Questions
- [ ] **Does the WAF protect the ALB?** Already done (good). But the WAF is not protecting the Next.js frontend on Vercel. Patient image uploads going through the Next.js server action are not covered. Consider adding Cloudflare in front of Vercel if WAF coverage on the frontend is required.
- [ ] **Are Cognito MFA requirements appropriate per role?** Patients have optional MFA. Doctors have required MFA. This is correct. But confirm the admin user creation flow - admins are created manually (no Cognito self-service registration). Where are admin credentials stored? They should use AWS IAM Identity Center, not a Cognito user pool.
- [ ] **Is the Secrets Manager rotation Lambda actually implemented?** The module has placeholder zip files for rotation. Verify the Lambda code exists and the rotation schedule is active for: DB credentials, API keys, and Cognito app client secrets.

---

## Missing Terraform Modules (Required Before Production)

| Module | Status | Priority | Why Needed |
|--------|--------|----------|-----------|
| `elasticache/` | Missing | Critical | Shared Redis for multi-instance ECS predictions store |
| `sqs/` | Missing | Critical | Async training pipeline with DLQs |
| `mlflow/` | Missing | High | Model registry and experiment tracking server |
| `ses-notifications/` | Missing | High | Doctor approval emails, training readiness alerts |
| `cloudwatch-alarms/` | Missing | High | Alert on inference error rate, latency P99, model drift |
| `ecs-service/` | Partial | High | ECS service definition (separate from ECS cluster) - health check grace period |
| `ecr/` | Missing | High | Container image registry for backend Docker images |
| `route53-acm/` | Missing | High | HTTPS custom domain and certificate management |
| `vpc-endpoints/` | Partial | High | Private access to ECR API, ECR Docker, CloudWatch Logs, STS, Secrets Manager |
| `terraform-backend/` | Missing | High | Remote state bucket and DynamoDB lock table for safe team usage |

### Build These Modules Before Applying Production

For learning, create modules in this order:

1. `ecr/` - needed before any ECS deployment can pull backend images.
2. `elasticache/` - needed before `/predict` and `/explain` run on more than one ECS task.
3. `sqs/` - needed before consent, doctor review, and admin approval pipeline work.
4. `cloudwatch-alarms/` - needed before traffic.
5. `route53-acm/` - needed before public HTTPS.
6. `mlflow/` - needed before model registry and promotion.

Do not wire these all at once. Add one module, run `terraform fmt`, `terraform validate`, `terraform plan`, then commit.

### VPC/Security Wiring Corrections To Check

The current VPC direction is good, but verify these before production:

- App subnets should route egress through NAT, but data subnets should not have broad internet egress unless a specific reason exists.
- Use one source of truth for the ECS service security group. RDS should allow inbound only from the actual ECS service SG, not a duplicate SG created inside the RDS module.
- ALB should redirect HTTP 80 to HTTPS 443 after ACM is configured.
- WAF must be explicitly associated with the ALB ARN.
- ECS service must use `assign_public_ip = false` and app subnet IDs.
- Add interface endpoints for ECR API, ECR Docker, CloudWatch Logs, STS, and Secrets Manager if you want private image pulls and private secret access.

---

## Quick Start

```bash
# 1. Navigate to terraform directory
cd infra/terraform

# 2. Initialize
make init

# 3. Plan
make plan ENV=prod

# 4. Apply (requires MFA + AWS credentials)
make apply ENV=prod
```

---

## File Structure

```
infra/terraform/
├── main.tf                    # Root module - calls all submodules
├── Makefile                   # Commands: init, plan, apply, destroy, validate
├── environments/
│   ├── prod.tfvars           # Production variables (fill in your account ID + password)
│   └── dev.tfvars             # Development variables
├── modules/
│   ├── vpc/main.tf            # 3-tier VPC (public/app/data subnets) + NAT + S3 VPC endpoint
│   ├── cognito/main.tf         # User pools for patients and doctors
│   ├── s3-training/main.tf    # Training data bucket with versioning + lifecycle
│   ├── ecs-task-role/main.tf   # Least-privilege IAM roles for ECS tasks
│   ├── rds/main.tf            # PostgreSQL with KMS encryption + Multi-AZ
│   ├── guardduty/main.tf      # Threat detection with SNS alerts
│   ├── cloudtrail/main.tf     # Multi-region audit logging to S3
│   ├── waf/main.tf            # Rate limiting + SQL injection + XSS protection
│   ├── kms/main.tf            # KMS key for encryption
│   ├── secrets-manager/main.tf # Secrets Manager with rotation (placeholder)
│   ├── s3-logging/main.tf     # S3 bucket for CloudTrail logs
│   ├── vpc-flow-logs/main.tf   # VPC Flow Logs to CloudWatch
│   ├── ecs/main.tf            # ECS Cluster with Container Insights
│   └── alb/main.tf            # Application Load Balancer
└── lambdas/                   # Lambda functions (placeholder zips for rotation)
```

---

## Prerequisites

1. **AWS CLI** configured with credentials
2. **Terraform** >= 1.5.0 installed
3. **AWS Account ID** - you'll fill this in `environments/prod.tfvars`
4. **MFA** - enabled on your AWS account (required for production)

---

## Environment Setup

### 1. Fill in prod.tfvars

Edit `environments/prod.tfvars`:

```hcl
aws_region   = "us-east-1"
environment  = "prod"
account_id   = "YOUR_AWS_ACCOUNT_ID"       # Replace this

# Database password - use a strong generated password
db_username  = "skinlesionadmin"
db_password  = "YOUR_STRONG_PASSWORD"       # Replace this

# Optional: PagerDuty SNS ARN for GuardDuty alerts
pagerduty_webhook_arn = ""
```

### 2. Initialize Terraform

```bash
cd infra/terraform
make init
```

### 3. Plan and Review

```bash
make plan ENV=prod
```

Review the changes before applying.

### 4. Apply

```bash
make apply ENV=prod
```

This will create all AWS resources. The ALB DNS name will be output at the end.

---

## Makefile Commands

| Command | Description |
|---------|-------------|
| `make init` | Initialize Terraform providers |
| `make plan ENV=prod` | Preview changes for production |
| `make apply ENV=prod` | Deploy to production |
| `make destroy ENV=prod` | Tear down all resources (careful!) |
| `make validate` | Validate Terraform syntax |
| `make format` | Auto-format Terraform files |
| `make output` | Show Terraform outputs |

---

## Terraform Modules

### VPC (`modules/vpc/`)

Creates a 3-tier VPC with NAT gateway for outbound traffic:

| Subnet | Purpose | Accessibility |
|--------|---------|---------------|
| Public | ALB, NAT Gateway | Direct internet (via IGW) |
| App | ECS tasks | Private, egress via NAT |
| Data | RDS, Redis | Private, no direct internet |

Also creates S3 VPC endpoint so ECS tasks can access S3 without going over internet.

**Outputs:**
- `vpc_id`
- `public_subnet_ids`
- `app_subnet_ids`
- `data_subnet_ids`
- `vpc_endpoint_id`

---

### Cognito (`modules/cognito/`)

Two user pools:

| Pool | MFA | Password Policy |
|------|-----|-----------------|
| Patients | Optional | Minimum 8 chars |
| Doctors | **Required** | Must include uppercase, lowercase, numbers, symbols |

Doctor pool has `admin_only` account recovery to prevent social engineering.

**Outputs:**
- `patient_pool_id`
- `doctor_pool_id`
- `doctor_pool_client_id`
- `ecs_security_group_id`
- `alb_security_group_id`

---

### S3 Training (`modules/s3-training/`)

Training data bucket with:

- **Versioning enabled** - keeps object history
- **Server-side encryption** - AES256
- **Lifecycle rules** - incomplete uploads abort after 7 days
- **Public access blocked** - no direct internet access

Creates folder structure for the curation pipeline:
- `pending_review/` - doctor validation queue
- `pending_admin/` - admin approval queue
- `approved/` - cleared for training
- `rejected/` - rejected cases

**Outputs:**
- `bucket_arn`
- `bucket_name`

---

### ECS Task Role (`modules/ecs-task-role/`)

Two IAM roles:

| Role | Purpose | Permissions |
|------|---------|-------------|
| `task_execution` | Pull images, write logs | ECS Task Execution Policy + Secrets Manager |
| `task` | Application logic | S3 (read/write pending_review, pending_admin, approved - no delete), RDS (connect only), Cognito (describe, list, adminGetUser) |

DENY policy blocks: `DeleteObject`, `DeleteBucket`, `PutBucketPolicy`, `PutBucketVersioning`.

**Outputs:**
- `execution_role_arn`
- `task_role_arn`

---

### RDS (`modules/rds/`)

PostgreSQL instance:

- **Engine**: PostgreSQL 15.3
- **Instance**: db.t3.medium
- **Storage**: 100GB gp3, up to 200GB
- **Encryption**: KMS (uses `modules/kms/main.tf` key)
- **Multi-AZ**: Enabled
- **Backups**: 7-day retention
- **Monitoring**: Enhanced monitoring, Performance Insights

**Outputs:**
- `instance_arn`
- `instance_endpoint`

---

### GuardDuty (`modules/guardduty/`)

Threat detection enabled with:
- S3Logs feature (analyzes S3 data events)
- MalwareProtection feature
- Finding publishing: 6 hours
- EventBridge rule triggers SNS for HIGH/CRITICAL findings

**Outputs:**
- `detector_id`
- `sns_topic_arn`

---

### CloudTrail (`modules/cloudtrail/`)

Multi-region audit trail:
- Logs to S3 bucket with AES256 encryption
- Log file validation enabled
- Captures management + data events for S3 training bucket
- EventBridge alerts on: PutBucketPolicy, DeleteBucket, AttachUserPolicy, CreateUser, PutRolePolicy, ConsoleLogin

**Outputs:**
- `trail_arn`
- `s3_bucket_arn`

---

### WAF (`modules/waf/`)

Web Application Firewall with:

| Rule | Priority | Action | Description |
|------|----------|--------|-------------|
| RateLimitRule | 1 | BLOCK | 1000 requests/min per IP |
| SQLInjectionRule | 2 | BLOCK | SQL injection in query string |
| XSSRule | 3 | BLOCK | XSS in query string |
| MaliciousIPRule | 4 | BLOCK | Known malicious IPs (TOR exit nodes) |

Associated with ALB.

---

### VPC Flow Logs (`modules/vpc-flow-logs/`)

Flow logs to CloudWatch:
- 30-day retention
- Captures ALL traffic
- Format includes VPC ID, subnet ID, interface ID, region

---

## Validation Commands

After deployment, verify the controls:

```bash
# Get outputs
make output

# Verify S3 versioning is enabled
aws s3api get-bucket-versioning --bucket skin-lesion-training-ACCOUNT_ID

# Verify Cognito MFA is on
aws cognito-idp get-user-pool-mfa-config --user-pool-id YOUR_DOCTOR_POOL_ID

# Verify WAF is attached to ALB
aws wafv2 get-web-acl-for-resource --resource-arn YOUR_ALB_ARN

# Verify GuardDuty is enabled
aws guardduty list-detectors

# Verify VPC Flow Logs
aws ec2 describe-flow-logs --filters Name=resource-id,Values=YOUR_VPC_ID

# Verify RDS is encrypted
aws rds describe-db-instances --db-instance-identifier skin-lesion-prod --query 'DBInstances[0].StorageEncrypted'
```

---

## Destroying Resources

```bash
# Tear down everything
make destroy ENV=prod
```

This will delete all AWS resources created by Terraform.

---

## Security Controls Summary

| Tier | Control | Module |
|------|---------|--------|
| 1 | VPC with 3-tier subnet design | `modules/vpc/` |
| 1 | Cognito MFA for doctors | `modules/cognito/` |
| 1 | S3 training bucket with versioning | `modules/s3-training/` |
| 1 | GuardDuty threat detection | `modules/guardduty/` |
| 2 | ECS least-privilege IAM | `modules/ecs-task-role/` |
| 2 | RDS with KMS encryption | `modules/rds/` |
| 2 | CloudTrail multi-region logging | `modules/cloudtrail/` |
| 2 | VPC Flow Logs to CloudWatch | `modules/vpc-flow-logs/` |
| 3 | WAF rate limiting + OWASP rules | `modules/waf/` |
| 3 | Secrets Manager | `modules/secrets-manager/` |
| 3 | KMS key management | `modules/kms/` |
| 3 | S3 logging bucket | `modules/s3-logging/` |
