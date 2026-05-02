# Terraform Guide

This directory contains the root Terraform stack and modules for the Skin Lesion XAI platform.

Use this guide together with `../../docs/BUILD_PHASE_1_INFRASTRUCTURE.md`.

## Current Layout

```text
infra/terraform/
  main.tf
  Makefile
  environments/
    dev.tfvars
    prod.tfvars
  modules/
    alb/
    cloudtrail/
    cognito/
    ecs/
    ecs-task-role/
    guardduty/
    kms/
    rds/
    s3-logging/
    s3-training/
    secrets-manager/
    vpc/
    vpc-flow-logs/
    waf/
```

## What Exists Today

The current stack provisions foundation infrastructure:

- VPC with public, app, and data subnets
- Cognito user pools
- S3 training bucket
- GuardDuty
- ECS task roles
- RDS PostgreSQL
- CloudTrail
- VPC Flow Logs
- WAF
- Secrets Manager placeholders
- KMS
- S3 logging bucket
- ECS cluster
- ALB

## What Is Still Needed Before Production

Add these modules before real production traffic:

| Module | Why |
|---|---|
| `ecr/` | Backend container registry |
| `elasticache/` | Shared Redis for prediction/explanation jobs |
| `sqs/` | Async consent, validation, approval, and worker queues |
| `cloudwatch-alarms/` | Alerting for API, ECS, RDS, Redis, and model failures |
| `route53-acm/` | HTTPS custom domain and certificates |
| `mlflow/` | Model registry and model promotion workflow |
| `terraform-backend/` | Remote state bucket and DynamoDB locking |
| `vpc-endpoints/` | Private access to ECR, CloudWatch Logs, STS, and Secrets Manager |

Build these one at a time. Do not add all modules in one commit.

## Safe Learning Workflow

Start with dev, not prod.

```bash
cd infra/terraform
make init
make check
make validate
make plan ENV=dev
```

Only apply after you understand the plan:

```bash
make apply ENV=dev
```

For production:

```bash
make check-prod
make plan ENV=prod
```

Do not apply production until remote state, locking, secrets, rollback, and smoke tests are ready.

## Add A New Module Safely

Use this sequence for every new module:

1. Create `modules/<name>/main.tf`.
2. Define inputs and outputs in the module.
3. Wire it in `main.tf`.
4. Add environment variables to `environments/dev.tfvars` and `environments/prod.tfvars` if needed.
5. Run:

```bash
make format
make validate
make plan ENV=dev
```

6. Commit only that module.

## Dev, Staging, Production

The current repo has `dev.tfvars` and `prod.tfvars`. Before a real launch, add staging:

```text
environments/
  dev.tfvars
  staging.tfvars
  prod.tfvars
```

Recommended promotion:

```text
local plan
dev apply
dev smoke tests
staging plan/apply
staging smoke tests
manual approval
prod plan/apply
prod smoke tests
```

## Multi-Region Direction

Start with one AWS region. Multi-region is approved as a future scale and resilience path, but it should not be the first Terraform apply.

Recommended order:

1. Single-region dev.
2. Single-region staging.
3. Single-region production.
4. Active-passive multi-region for disaster recovery.
5. Active-active multi-region only after traffic and reliability needs justify the complexity.

When the project reaches multi-region work, add modules and configuration for:

- S3 Cross-Region Replication
- regional ECS services and ALBs
- regional Redis clusters
- regional SQS queues with idempotent workers
- Aurora Global Database or another tested Postgres replication strategy
- Route53 health checks and failover routing
- per-region secrets and KMS keys

Database sharding is an application/data-model concern first. Terraform should support it later through separate database clusters, networking, secrets, alarms, and routing once the app schema has shard keys such as `user_id` or `tenant_id`.

## Important Warnings

- `prod.tfvars` contains placeholders. Do not apply it as-is.
- Do not commit real passwords, API keys, or patient data.
- Use Secrets Manager for runtime secrets.
- Use remote Terraform state before team usage.
- Keep ECS tasks in private app subnets, not public subnets.
- Use shared Redis before running more than one backend task.
- Use queues for long-running model, Grad-CAM, LLM, and training-curation work.
