# Terraform Learning Area

This folder is for Terraform learning.

The root `main.tf` has been removed on purpose so you can build from scratch.

For beginner learning, start with the guide:

```text
docs/staging/02_TERRAFORM_FROM_EMPTY_MAIN.md
```

## Why You Should Not Start With A Full `main.tf`

A large `main.tf` that creates many services at once is hard to learn from. It also creates errors for resources you have not studied yet.

The learning path is:

```text
scratch folder -> provider block -> validate -> one resource -> plan -> understand -> maybe apply
```

## What To Do First

From the repo root, create or use:

```text
infra/terraform/
```

Then check Terraform:

```powershell
terraform version
```

If Terraform is installed, continue with the guide.

If Terraform is not installed, install it before writing any `.tf` files.

## Helper Makefile

The helper Makefile is not assumed to exist from the beginning. Create it when this guide tells you:

```text
docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md
```

After that guide creates `infra/terraform/Makefile`, the root Makefile can delegate cloud cost commands:

```powershell
make cloud-status ENV=dev
make cloud-start ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

Shutdown is guarded on purpose. It refuses to run unless `CONFIRM_DESTROY=YES` is provided.

Production-style operations are also guarded. Add `CONFIRM_PROD=YES` only when intentionally touching prod:

```powershell
make cloud-start ENV=prod CONFIRM_PROD=YES
make cloud-shutdown ENV=prod CONFIRM_DESTROY=YES CONFIRM_PROD=YES
```

Environment files are also created by the cost-control guide:

```text
infra/terraform/env/dev.tfvars
infra/terraform/env/staging.tfvars
infra/terraform/env/prod.tfvars
```

## Former Module Folders

The old module and Lambda folders were removed after their ideas were integrated into the handholding guides:

```text
infra/terraform/modules/
infra/terraform/lambda/
```

Do not recreate or wire modules until a guide tells you:

1. what the module does
2. why you need it
3. what it will cost
4. what command checks it
5. what the expected Terraform plan should roughly show

The staged learning guides that preserve the old module and Lambda ideas are:

```text
docs/staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md
docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md
docs/staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md
docs/staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md
docs/staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
docs/staging/09_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md
docs/production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md
docs/production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md
docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md
docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
docs/production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md
docs/production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md
```

## Safe Terraform Loop

Use this loop for every small change:

```powershell
terraform fmt
terraform validate
terraform plan
```

Do not run:

```powershell
terraform apply
```

until you understand the plan output.

## Build Order For Cloud Infrastructure

Build later in this order:

1. provider only
2. one S3 bucket for learning
3. cost start/stop commands
4. VPC
5. ECR
6. local Docker image pushed to ECR
7. Kubernetes local
8. EKS dev
9. EKS Ingress through AWS Load Balancer Controller
10. Aurora DSQL staging database
11. SQS/EventBridge
12. monitoring
13. CI/CD
14. AppConfig and cache only after runtime basics work

This order keeps cloud errors small and understandable.
