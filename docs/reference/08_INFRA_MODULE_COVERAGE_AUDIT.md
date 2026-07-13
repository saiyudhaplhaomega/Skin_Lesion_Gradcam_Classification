# Infra Module Coverage Audit

Use this as the map between deleted old `infra/terraform` material and the current handholding guides.

The current learning path intentionally teaches direct resources first. Old modules and Lambda folders were deleted after their ideas were preserved in guides.

## Command Location

Read from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root before running any audit commands.

Check infra files:

```powershell
Get-ChildItem infra/terraform -Recurse
```

**What this does:** lists all files and directories inside `infra/terraform/` recursively. Use this to verify which `.tf` files, modules, and helper files currently exist before adding or modifying infrastructure.

## Fully Integrated As Build Guides

```text
vpc -> staging/04_TERRAFORM_VPC_HANDHOLDING.md
kms -> staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md
sns -> staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md
appconfig -> production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md
EKS probes/HPA -> production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
Redis/ElastiCache -> production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md
```

**What this mapping means:** each old Terraform module concept is now taught through a specific handholding guide. The guide walks you through creating the resources directly rather than calling a module. This mapping tells you which guide covers the same ground as which old module.

## Integrated As ECS/ALB Reference Only

```text
alb
ecs
ecs-service
ecs-task-role
blue-green
canary
auto-heal-lambda
auto-rollback-lambda
lambda/auto_heal.py
lambda/auto_rollback.py
```

**What "ECS/ALB reference only" means:** these module and Lambda artifacts are preserved as documented reference material, not as active build targets. They apply only to the ECS runtime path. Since the main project path is EKS, do not build or wire these unless you have explicitly decided to use ECS instead.

Guides:

```text
production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md
production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md
production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md
staging/09_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md
```

**What these guides cover:** the guides that document ECS/ALB patterns as reference material and explain the EKS-to-ECS translation for each concept.

Rule:

```text
EKS main path uses AWS Load Balancer Controller and Ingress.
ECS alternate path may use the old ALB/ECS modules.
Do not wire ECS Lambda code to EKS alarms.
```

**What this rule means:**

- `EKS main path uses AWS Load Balancer Controller and Ingress` - the EKS runtime does not use ECS ALB modules. It provisions ALBs through Kubernetes Ingress resources managed by the AWS Load Balancer Controller.
- `ECS alternate path may use the old ALB/ECS modules` - only relevant if you switch to ECS. Document the switch explicitly.
- `Do not wire ECS Lambda code to EKS alarms` - the auto-heal and auto-rollback Lambda functions call ECS API. They have no effect on EKS pods and wiring them to EKS CloudWatch alarms will silently do nothing useful.

## Conceptually Integrated, Direct Resource First

These modules are represented in guides, but the beginner path creates direct resources first instead of `module "..."` calls:

```text
waf -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
cognito -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
cloudwatch-alarms -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
cloudtrail -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
guardduty -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
vpc-flow-logs -> staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
s3-training -> staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md and product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md
s3-logging -> staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md
secrets-manager -> staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md
rds -> staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md as Aurora PostgreSQL fallback only
```

**What these module-to-guide mappings mean:** each old Terraform module is taught as a direct resource in the beginner guides rather than as a `module "..."` block. The mappings tell you which guide covers the concept:

- `waf`, `cognito`, `cloudwatch-alarms`, `cloudtrail`, `guardduty`, `vpc-flow-logs` - all security and observability resources, covered together in `staging/16`.
- `s3-training` - covered in both the storage guide and the training pipeline guide because training data storage spans both concerns.
- `s3-logging`, `secrets-manager` - covered in the storage and secrets guide.
- `rds` - only covered as an Aurora PostgreSQL fallback. DSQL is the primary database path; RDS is documented only in case DSQL is unavailable.

Why: direct resources teach what each cloud service does. Modules can be introduced later after the learner understands the resources they wrap.

## Helper Files

These files are referenced by the learning workflow:

```text
infra/terraform/README.md -> Terraform learning area overview
infra/terraform/Makefile -> safe Terraform helper commands and guarded start/shutdown
```

**What these helper files do:**

- `infra/terraform/README.md` - the entry point for the Terraform learning area. It explains the directory structure, which guides to follow in order, and how the learning path is organized.
- `infra/terraform/Makefile` - provides safe wrappers around common Terraform commands. It includes guarded shutdown targets that require explicit confirmation, so you cannot accidentally destroy infrastructure.

These deleted files were reference artifacts and should not be recreated blindly:

```text
infra/terraform/lambda/auto-heal.zip
infra/terraform/lambda/auto-rollback.zip
```

**What these deleted zip files were:** deployment packages for the ECS auto-heal and auto-rollback Lambda functions. They are not relevant to the EKS main path. Do not recreate them unless the runtime is explicitly switched to ECS/ALB.

The deleted source files were:

```text
infra/terraform/lambda/auto_heal.py
infra/terraform/lambda/auto_rollback.py
```

**What these deleted source files were:** the Python scripts that the zip files contained. `auto_heal.py` called ECS API to restart unhealthy tasks. `auto_rollback.py` called ECS API to roll back a service to its previous task definition. Neither script has any effect on EKS workloads.

Only recreate source and zip artifacts after the runtime path is explicitly ECS/ALB.

## Remaining Decisions

```text
Use EKS main path unless explicitly switching to ECS.
Use DSQL main cloud database path unless DSQL is blocked and fallback is documented.
Use direct resources while learning; modules can be reintroduced after the guide proves the resource.
Use full shutdown at the end of each cloud learning session to avoid idle cost.
```

**What these decisions mean:**

- `Use EKS main path unless explicitly switching to ECS` - EKS is the default runtime. ECS is documented as an alternative but should not be built unless there is a deliberate, recorded decision to switch.
- `Use DSQL main cloud database path unless DSQL is blocked and fallback is documented` - Aurora DSQL is the primary database. If DSQL is unavailable in a region or blocked by a quota issue, document the reason before switching to the RDS PostgreSQL fallback.
- `Use direct resources while learning; modules can be reintroduced after the guide proves the resource` - write `resource "aws_..."` blocks directly in Terraform files while working through the guides. Wrap them in a reusable module only after you understand what the resource does and have proven it works.
- `Use full shutdown at the end of each cloud learning session to avoid idle cost` - cloud resources that sit idle between sessions still incur charges. Run `make cloud-shutdown` at the end of each session to avoid accumulating cost while not actively working.

## Check

Run:

```powershell
make docs-check
```

**What this does:** runs the documentation readiness checker, which scans all required guide files to confirm they exist and meet minimum content requirements. If any expected guide is missing or empty, the check fails with a list of missing files.

Expected result:

```text
docs-check ok
```

**What this result means:** all required documentation is present and passes the readiness check. If the check fails, inspect the output to identify which guides are missing or incomplete.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of all dev cloud resources so you know what is running before you pause or destroy anything.
- `make cloud-pause ENV=dev` pauses resources that support pause (such as RDS instances) without destroying them. This reduces cost while preserving state.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` runs `terraform destroy` for the dev environment. The `CONFIRM_DESTROY=YES` flag is a safety guard that prevents accidental destruction without explicit intent.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` applies Terraform configuration to recreate or resume the dev environment. For paused resources, this restarts them. For destroyed resources, this provisions them fresh.
- `make cloud-status ENV=dev` confirms that all resources came up healthy before you begin working.

If this guide was local-only, no cloud shutdown is needed.
