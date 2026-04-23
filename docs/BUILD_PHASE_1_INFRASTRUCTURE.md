# Skin Lesion Platform - Terraform Infrastructure

**Hardened AWS infrastructure implementing Tier 1-3 defensive controls.**

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