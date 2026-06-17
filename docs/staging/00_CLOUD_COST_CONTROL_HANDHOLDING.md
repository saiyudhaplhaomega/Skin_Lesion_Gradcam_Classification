# Cloud Cost Control Start Stop Handholding Guide

Read this before any guide that creates AWS resources.

The goal is to make cost control a normal part of learning:

```text
start cloud -> follow guide -> check result -> pause or shutdown cloud
```

**What this workflow means:** every guide that creates cloud resources follows this four-step pattern. You start the environment first, work through the guide, verify the result, then pause or destroy before stopping. This prevents forgotten resources from running overnight and accumulating cost.

## Goal

Learn to start, pause, resume, and shut down AWS cloud environments safely to avoid unnecessary costs while learning cloud infrastructure.

## Command Location

Run cost commands from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root where the root `Makefile` lives. The `make cloud-*` commands defined there delegate to `infra/terraform/Makefile`.

Terraform commands are delegated to:

```text
infra/terraform
```

**What this means:** Terraform state, modules, and variable files all live under `infra/terraform/`. The root Makefile is a shortcut layer - it calls `make -C infra/terraform` to run the actual Terraform commands.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform helper Makefile: `infra/terraform/Makefile`.
- Terraform environment files: `infra/terraform/env/dev.tfvars`, `infra/terraform/env/staging.tfvars`, and `infra/terraform/env/prod.tfvars`.
- Root cloud shortcut commands run from the main workspace. Terraform helper commands run from `infra/terraform/`.

## Parameters You Must Set First

```text
ENV=dev for low-cost learning
ENV=staging for production-like testing
ENV=prod only when production readiness is intentional
CONFIRM_DESTROY=YES only when you really want Terraform destroy
CONFIRM_PROD=YES only when you intentionally want to touch prod
```

**What these parameters mean:**

- `ENV=dev` - the learning environment. Uses small instance types and disposable resources. Safe to destroy at any time.
- `ENV=staging` - a production-like environment for final validation before production. More expensive than dev.
- `ENV=prod` - only for intentional production readiness practice. Protected by an additional `CONFIRM_PROD=YES` guard.
- `CONFIRM_DESTROY=YES` - a safety flag the Makefile checks before running `terraform destroy`. Prevents accidental destruction.
- `CONFIRM_PROD=YES` - a second safety flag that must be set alongside `CONFIRM_DESTROY=YES` when the target is production.

## Cost Rule

Every cloud guide must end with a pause or shutdown decision.

Use this rule:

```text
If you will continue within an hour: pause runtime workloads if possible.
If you are done for the day: shutdown the environment.
If the environment is prod: do not destroy unless this is a disposable learning prod.
```

**What this cost rule means:** pausing scales pods to zero replicas but leaves the EKS cluster, databases, and networking running - this reduces cost but does not eliminate it. Shutdown destroys everything with `terraform destroy`, stopping all charges for the environment. Production environments should never be destroyed without a documented restore plan and approvals.

## Step 1: Create The Terraform Helper Makefile

Create this file:

```text
infra/terraform/Makefile
```

**What this file is:** a safe wrapper around Terraform commands. It adds guard conditions so destructive actions require explicit confirmation flags.

Paste:

```makefile
# Safe Terraform learning commands.
# Destructive shutdown requires CONFIRM_DESTROY=YES.

.PHONY: version fmt validate plan guard-prod guard-destroy workspace status start pause resume shutdown

ENV ?= dev
CONFIRM_DESTROY ?= NO
CONFIRM_PROD ?= NO
NAMESPACE ?= skin-lesion-$(ENV)
RESUME_REPLICAS ?= 1
VAR_FILE := env/$(ENV).tfvars

version:
	terraform version

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan: guard-prod
	terraform plan -var-file="$(VAR_FILE)"

guard-prod:
	@powershell -NoProfile -Command "if ('$(ENV)' -eq 'prod' -and '$(CONFIRM_PROD)' -ne 'YES') { Write-Host 'Refusing prod operation. Re-run with CONFIRM_PROD=YES'; exit 1 }"

guard-destroy:
	@powershell -NoProfile -Command "if ('$(CONFIRM_DESTROY)' -ne 'YES') { Write-Host 'Refusing terraform destroy. Re-run with CONFIRM_DESTROY=YES'; exit 1 }"

workspace:
	terraform init -input=false
	@powershell -NoProfile -Command "terraform workspace select '$(ENV)'; if ($$LASTEXITCODE -ne 0) { terraform workspace new '$(ENV)' }"

status: guard-prod workspace
	terraform workspace show
	terraform state list

start: guard-prod workspace
	terraform apply -var-file="$(VAR_FILE)"

pause: guard-prod
	@powershell -NoProfile -Command "kubectl get namespace '$(NAMESPACE)' > $$null 2>&1; if ($$LASTEXITCODE -ne 0) { Write-Host 'Namespace $(NAMESPACE) not found. Nothing to pause.'; exit 0 }; kubectl scale deployment --all --replicas=0 -n '$(NAMESPACE)'; kubectl get deploy -n '$(NAMESPACE)'"

resume: guard-prod
	@powershell -NoProfile -Command "kubectl get namespace '$(NAMESPACE)' > $$null 2>&1; if ($$LASTEXITCODE -ne 0) { Write-Host 'Namespace $(NAMESPACE) not found. Run make start ENV=$(ENV) first.'; exit 1 }; kubectl scale deployment --all --replicas=$(RESUME_REPLICAS) -n '$(NAMESPACE)'; kubectl rollout status deployment --all -n '$(NAMESPACE)'"

shutdown: guard-prod guard-destroy workspace
	terraform destroy -var-file="$(VAR_FILE)"
```

**What this Makefile does:**

- `ENV ?= dev` - default to `dev` if `ENV` is not set. The `?=` operator means "set if not already defined".
- `VAR_FILE := env/$(ENV).tfvars` - constructs the path to the environment variable file dynamically. `make ... ENV=staging` uses `env/staging.tfvars`.
- `fmt` - runs `terraform fmt -recursive` to format all `.tf` files. Run this before committing.
- `validate` - runs `terraform validate` to check for syntax and structural errors without connecting to AWS.
- `plan` - runs the prod guard, then runs `terraform plan` with the environment's variable file. Shows what Terraform will create, change, or destroy before applying.
- `guard-prod` - a safety target that checks if `ENV=prod` without `CONFIRM_PROD=YES` and exits with an error if so.
- `guard-destroy` - a safety target that checks for `CONFIRM_DESTROY=YES` before Terraform is initialized or asked to destroy anything.
- `workspace` - runs `terraform init` and selects or creates the named workspace. Terraform workspaces keep separate state per environment.
- `status` - runs the prod guard, shows the current workspace name, and lists all tracked resources in the state.
- `start` - applies Terraform with the environment's variable file. Creates or updates resources.
- `pause` - scales all Kubernetes deployments in the environment's namespace to zero replicas. Stops the app pods without destroying cloud resources.
- `resume` - scales deployments back up to `RESUME_REPLICAS` (default 1) and waits for rollout to complete.
- `shutdown` - checks for `CONFIRM_DESTROY=YES` before Terraform initialization, then runs `terraform destroy`. Destroys everything in the environment's state.

Check:

```powershell
make -C infra/terraform version
```

**What this does:** runs the `version` target of the Makefile from the `infra/terraform` directory. This confirms that `make` can find the Makefile and that Terraform is installed and accessible from the shell.

Expected result:

```text
Terraform version prints.
The helper Makefile exists only because this guide told you to create it.
```

**What this result means:** Terraform's version string (e.g., `Terraform v1.8.2`) prints to the terminal. The note reminds you this Makefile was created by following this guide - it did not exist before.

If the command says Terraform cannot be found, stop here and install Terraform before running `cloud-status`, `cloud-start`, or any guide that uses Terraform:

```text
make (e=2): The system cannot find the file specified.
```

**What this means:** the helper Makefile was created correctly, but the `terraform` executable is not installed or not on `PATH`. No cloud resources were created.

On this Windows workspace, Chocolatey is available. Open a new PowerShell terminal as Administrator and run:

```powershell
choco install terraform -y
```

**What this does:** installs the Terraform CLI and adds it to the system `PATH`.

Close the Administrator terminal after installation. Open a normal PowerShell terminal from the repo root again:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
make -C infra/terraform version
```

**What this does:** reloads your terminal `PATH`, then reruns the exact guide check.

Expected result:

```text
Terraform version prints.
```

If Terraform still cannot be found, restart PowerShell once more and rerun:

```powershell
terraform version
make -C infra/terraform version
```

**What this does:** checks Terraform directly first, then checks it through the helper Makefile.

Why: the repo should not hide cloud automation from you. You create the helper only when the cost-control guide reaches this step.

## Step 2: Create Environment Variable Files

Create this folder:

```text
infra/terraform/env
```

**What this folder is:** the directory that holds one `.tfvars` file per environment. Terraform reads these files to fill in variable values that differ between environments.

Create:

```text
infra/terraform/env/dev.tfvars
```

**What this file is:** the variable values for the dev (learning) environment.

Paste:

```hcl
# Dev environment variables for Terraform learning.
# Keep this low-cost and disposable.

environment  = "dev"
project_name = "skin-lesion"
aws_region   = "us-east-1"

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
```

**What this content does:** sets the three base variables that all Terraform modules expect. Each guide that introduces new variables will tell you to add them here. The comment "do not paste secrets" is a reminder - secrets go in Secrets Manager, not in `.tfvars` files.

Create:

```text
infra/terraform/env/staging.tfvars
```

**What this file is:** the variable values for the staging (production-like) environment. More expensive to run than dev.

Paste:

```hcl
# Staging environment variables for production-like validation.
# Use only after dev checks pass.

environment  = "staging"
project_name = "skin-lesion"
aws_region   = "us-east-1"

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
```

Create:

```text
infra/terraform/env/prod.tfvars
```

**What this file is:** the variable values for the production-style environment. Use only for deliberate production readiness practice.

Paste:

```hcl
# Production-style environment variables.
# Use only when intentionally practicing production readiness.

environment  = "prod"
project_name = "skin-lesion"
aws_region   = "us-east-1"

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
```

Check:

```powershell
Test-Path infra/terraform/env/dev.tfvars
Test-Path infra/terraform/env/staging.tfvars
Test-Path infra/terraform/env/prod.tfvars
```

**What this does:** checks that all three `.tfvars` files exist. `Test-Path` returns `True` if the file exists and `False` if it does not. If any returns `False`, the file was not created correctly.

Expected result:

```text
All three commands return True.
```

**What this means:** all three environment variable files are present. Terraform can now resolve the `VAR_FILE` path for any of the three environments.

Why: `make cloud-start ENV=dev` uses the matching `env/dev.tfvars` file. Keeping values per environment prevents accidental prod settings in dev.

## Step 2b: Keep Only Starter Tfvars Files Trackable

Edit this file:

```text
.gitignore
```

**What this file is:** the repository-wide ignore list. It should keep real Terraform secrets and local state out of Git, while allowing the three beginner starter files from this guide to be versioned.

Make sure the Terraform section contains these exceptions after the blanket `*.tfvars` ignore rule:

```gitignore
!infra/terraform/env/
!infra/terraform/env/dev.tfvars
!infra/terraform/env/staging.tfvars
!infra/terraform/env/prod.tfvars
```

Check:

```powershell
git status --short infra/terraform/env
```

**What this does:** confirms that Git can see the three starter files. They should appear as untracked files the first time you create them.

Expected result:

```text
?? infra/terraform/env/dev.tfvars
?? infra/terraform/env/prod.tfvars
?? infra/terraform/env/staging.tfvars
```

**What this means:** only these non-secret starter tfvars files are trackable. Other `.tfvars` files remain ignored.

Why: the guide-created starter files are part of the learning scaffold and contain no secrets. Real local override files and secret-bearing tfvars files should stay ignored.

## Step 3: Check Cloud Status

Run:

```powershell
make cloud-status ENV=dev
```

**What this does:** runs the `status` Makefile target, which initialises Terraform, selects or creates the `dev` workspace, shows the active workspace name, and lists all tracked resources in the state file.

Expected result:

```text
Terraform selects or creates the dev workspace and lists tracked resources if any exist.
```

**What this result means:** the workspace name (`dev`) prints, followed by a list of resource addresses. If no resources have been applied yet, the state list will be empty. That is expected at this point.

If there is no state yet, Terraform may say there are no resources. That is fine.

## Step 4: Start One Environment

Run:

```powershell
make cloud-start ENV=dev
```

**What this does:** runs `terraform apply` with `env/dev.tfvars`. Creates all resources defined in the Terraform configuration for the dev workspace. Prompts for confirmation unless `-auto-approve` is added.

For staging:

```powershell
make cloud-start ENV=staging
```

**What this does:** applies the staging configuration. Uses `env/staging.tfvars`. Runs the same Terraform code but with staging-specific variable values.

For production-style learning:

```powershell
make cloud-start ENV=prod CONFIRM_PROD=YES
```

**What this does:** applies the prod configuration. The `CONFIRM_PROD=YES` flag bypasses the `guard-prod` check that would otherwise refuse the operation.

Expected result:

```text
Terraform applies only the selected workspace and selected tfvars file.
```

**What this means:** resources are created or updated for the specified environment only. The other environment workspaces are unaffected.

Why: one environment should start at a time so cost and blast radius stay understandable.

## Step 5: Pause Runtime Workloads

Pause is cheaper than full destroy only for runtime workloads.

For EKS non-prod, scale app workloads down:

```powershell
make cloud-pause ENV=dev
```

**What this does:** runs `kubectl scale deployment --all --replicas=0 -n skin-lesion-dev`. Stops all running pods in the dev namespace without destroying any cloud resources. The EKS cluster, databases, and networking remain active.

For staging:

```powershell
make cloud-pause ENV=staging
```

**What this does:** the same scale-to-zero operation for the staging namespace (`skin-lesion-staging`).

Check:

```powershell
kubectl get deploy -n skin-lesion-dev
kubectl get pods -n skin-lesion-dev
```

**What this does:** `kubectl get deploy` lists all deployments and shows their desired and ready replica counts. `kubectl get pods` lists all pods - after a pause, the pod list should be empty or show pods in Terminating state.

Expected result:

```text
Deployments show zero ready replicas.
App pods are stopped.
```

**What this means:** the `READY` column in the deployment list shows `0/0`. No pods are running. The namespace itself still exists.

Important: pausing pods does not stop all cloud charges. EKS clusters, NAT gateways, databases, load balancers, DSQL, GuardDuty, logs, and storage may still cost money.

## Step 6: Full Shutdown For The Day

Use full shutdown when you are done learning for the day.

Dev:

```powershell
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this does:** checks for `CONFIRM_DESTROY=YES`, then runs `terraform destroy -var-file="env/dev.tfvars"` in the dev workspace. Destroys all resources tracked in the dev state file.

Staging:

```powershell
make cloud-shutdown ENV=staging CONFIRM_DESTROY=YES
```

**What this does:** the same `terraform destroy` operation for the staging workspace. Only affects staging resources.

Production-style disposable learning environment:

```powershell
make cloud-shutdown ENV=prod CONFIRM_DESTROY=YES CONFIRM_PROD=YES
```

**What this does:** requires both confirmation flags before running `terraform destroy` on prod. Both `CONFIRM_DESTROY=YES` and `CONFIRM_PROD=YES` must be present or the Makefile exits with an error.

Expected result:

```text
Terraform destroys resources tracked in the selected workspace.
```

**What this means:** Terraform lists each resource it is destroying, then reports the number of resources destroyed. The state file for that workspace becomes empty.

Do not use full shutdown on a real production environment unless the environment is intentionally disposable and you have backups, approvals, and a restore plan.

## Step 7: Resume Later

Before beginning the next guide, start the environment again:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this does:** `cloud-start` applies Terraform to create or update the dev environment. `cloud-status` confirms the workspace is active and lists what was created.

Then rerun the guide's check command.

If you paused instead of fully shutting down, resume workloads:

```powershell
make cloud-resume ENV=dev
```

**What this does:** runs `kubectl scale deployment --all --replicas=1 -n skin-lesion-dev` and then waits for all deployments to roll out. Restores the app pods to a running state.

Expected result:

```text
Cloud resources are recreated or confirmed, and the guide can continue from a known state.
```

**What this means:** either the environment was recreated by Terraform (if it was shut down) or the pods came back up (if it was paused). Either way, the guide's check command should now pass.

## Files You Created For Environments

These starter files exist because Step 2 created them:

```text
infra/terraform/env/dev.tfvars
infra/terraform/env/staging.tfvars
infra/terraform/env/prod.tfvars
```

**What these files are:** the per-environment Terraform variable files. Each guide that introduces new Terraform variables will tell you to add them to the appropriate file here.

Each environment file should contain parameters for that environment only.

Do not commit secrets to these files.

## What One Command Means

Start:

```powershell
make cloud-start ENV=dev
```

**What this does:** runs `terraform apply` for the dev environment. Creates or updates all resources.

Pause runtime:

```powershell
make cloud-pause ENV=dev
```

**What this does:** scales all Kubernetes deployments in the dev namespace to zero replicas. Stops compute cost from running pods without destroying infrastructure.

Resume runtime:

```powershell
make cloud-resume ENV=dev
```

**What this does:** scales deployments back to one replica and waits for them to become ready.

Full shutdown:

```powershell
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this does:** destroys all dev resources tracked in the Terraform state. Stops all charges for this environment.

Status:

```powershell
make cloud-status ENV=dev
```

**What this does:** shows the active Terraform workspace and lists all tracked resources in the state file.

These same commands work with:

```text
ENV=dev
ENV=staging
ENV=prod
```

**What this means:** the same Makefile targets work for all three environments. Change `ENV=dev` to `ENV=staging` or `ENV=prod` to operate on a different environment.

For prod, add:

```powershell
CONFIRM_PROD=YES
```

**What this does:** satisfies the `guard-prod` check in the Makefile. Without it, any operation targeting `ENV=prod` exits with an error message before running.

## Completion Gate

Cost control is ready only when:

```text
root Makefile has cloud-start, cloud-status, cloud-pause, cloud-resume, and cloud-shutdown
infra/terraform/Makefile has start, status, pause, resume, and shutdown
shutdown refuses to run without CONFIRM_DESTROY=YES
prod operations refuse to run without CONFIRM_PROD=YES
each guide has a Cost Pause / Resume section
this guide contains the exact pasteable code for infra/terraform/Makefile
this guide contains the exact pasteable code for dev, staging, and prod tfvars files
you know whether the environment is dev, staging, or prod before applying Terraform
```

**What this completion gate means:** every item here is a prerequisite for safe cloud learning. `shutdown refuses to run without CONFIRM_DESTROY=YES` means accidental destruction requires deliberately typing the flag - it cannot happen by running a short command by mistake. `you know whether the environment is dev, staging, or prod` means you have checked `ENV` before running any command.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` shows what is running in the dev environment.
- `make cloud-pause ENV=dev` scales pods to zero to reduce compute cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` applies Terraform to create or update the dev environment.
- `make cloud-status ENV=dev` confirms the environment is healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
