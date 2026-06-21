# CI/CD Handholding Guide

Use this only after local checks exist.

## Current Project Implementation

Guide 17 now has CI for checks that are already safe to automate.

Files created:

```text
.github/workflows/docs-terraform-ci.yml
Skin_Lesion_Classification_backend/.github/workflows/backend-ci.yml
```

Why there are two workflow locations:

```text
Parent repo: docs and Terraform live in the parent workspace.
Backend repo: backend code is a nested Git repository with its own GitHub remote.
```

Current CI coverage:

```text
parent docs-check
parent Terraform fmt/validate with backend disabled in CI
backend focused pytest checks
backend ruff checks for Guides 17-21 files
```

Not added yet:

```text
frontend CI
deployment CI
Terraform apply CI
production approval workflow
```

Why: the frontend repo currently has an existing dirty `package-lock.json`, and deployment/Terraform apply require live cloud credentials and manual staging proof first.

## Goal

Automate commands you already run successfully by hand.

Why: CI/CD should only automate checks that already pass locally, so failed workflows point to real regressions instead of unfinished setup.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root, which is the git repository root where `.github/workflows/` will be created.

GitHub workflow files belong in:

```text
.github/workflows
```

**What this directory is:** the folder GitHub Actions reads on every push and pull request. YAML files here define when jobs run (triggers), what machine they run on (runner), and what steps to execute.

Do not create that folder until this guide tells you to.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- GitHub workflow files: `.github/workflows/`
- Backend repo checks: `Skin_Lesion_Classification_backend/`
- Frontend repo checks: `Skin_Lesion_Classification_frontend/`
- Terraform checks: `infra/terraform/`
- Create workflow YAML only under `.github/workflows/`, and keep each job's working directory aligned with the repo named in the local check table.

Because this workspace contains nested Git repositories, backend workflow YAML belongs under:

```text
Skin_Lesion_Classification_backend/.github/workflows/
```

**What this means:** GitHub Actions for backend code must live in the backend GitHub repository, not only in the parent docs/infra repository.

## Rule

No workflow should be created until the command works locally.

Run each local check from the directory it belongs to:

| Check | Directory |
|---|---|
| `make test` | `Skin_Lesion_Classification_backend` |
| `make build` | `Skin_Lesion_Classification_frontend` |
| `terraform fmt` and `terraform validate` | `infra/terraform` |
| `docker build` | `Skin_Lesion_Classification_backend` |

## First Backend CI

Create at this CI gate:

```text
Skin_Lesion_Classification_backend/.github/workflows/backend-ci.yml
```

**What this file is:** the backend CI workflow. GitHub Actions runs this on every push and pull request. The workflow must pass for a PR to be mergeable if branch protection is configured.

Only after:

```powershell
cd Skin_Lesion_Classification_backend
pytest
```

**What this means:** the backend test suite must pass locally before the workflow is created. If tests fail locally, the CI workflow will also fail - and debugging CI failures is harder than debugging local failures.

Workflow should do:

```text
checkout
setup Python
install dependencies
run pytest
```

**What each step does:** `checkout` clones the repo into the CI runner. `setup Python` installs the correct Python version. `install dependencies` runs `pip install -r requirements.txt` (or equivalent) to install the project packages. `run pytest` executes the test suite and fails the workflow if any test fails.

Do not create this workflow until the backend test command passes by hand.

## Frontend CI Gate

Only after:

```powershell
cd Skin_Lesion_Classification_frontend
npm run build
```

**What this means:** the frontend must build without errors locally before the CI workflow is created. Common failures here are missing environment variables, TypeScript type errors, and missing dependencies.

Workflow should do:

```text
checkout
setup Node
npm ci
npm run build
```

**What each step does:** `checkout` clones the repo. `setup Node` installs the Node.js version from `.nvmrc` or the workflow config. `npm ci` installs dependencies from `package-lock.json` exactly (no version resolution) - faster and more reproducible than `npm install`. `npm run build` compiles TypeScript, bundles assets, and fails the workflow if there are errors.

Do not create this workflow until the frontend build command passes by hand.

## Terraform CI Gate

Only after:

```powershell
cd infra/terraform
terraform fmt
terraform validate
```

**What this means:** both commands must succeed locally before the Terraform CI workflow is created. `terraform fmt` with no flags modifies files in place - in CI use `terraform fmt -check` which exits non-zero if formatting is wrong without modifying files.

Workflow should do:

```text
terraform fmt -check
terraform validate
```

**What each step does:** `terraform fmt -check` reads all `.tf` files and exits with an error if any are not formatted correctly - fails the workflow without modifying files. `terraform validate` checks resource references, variable types, and syntax without connecting to AWS. The plan step is deliberately excluded from CI because it requires AWS credentials and would cost money on every PR.

Do not create this workflow until `infra/terraform/main.tf` exists and validates locally.

Current parent workflow:

```text
.github/workflows/docs-terraform-ci.yml
```

It runs:

```text
terraform fmt -recursive -check
terraform init -backend=false -input=false
terraform validate
./scripts/docs-validate.ps1
```

**Why `-backend=false`:** the local Terraform backend uses AWS S3 state. CI should validate syntax without needing AWS credentials or touching cloud state.

## Do Not Add Yet

- deploy workflow
- blue/green workflow
- canary workflow
- Terraform apply workflow
- production approval workflow

## Deployment Automation Gate

Only automate deployment after manual deployment works:

```text
build image -> push image -> update Kubernetes -> rollout status -> health check -> rollback plan
```

**What this manual sequence does:** each step is run by hand until it is repeatable without errors. `build image` builds the Docker image with the commit SHA as the tag. `push image` uploads it to ECR. `update Kubernetes` patches the deployment image field to the new tag. `rollout status` waits for pods to become ready. `health check` confirms the app is responding. `rollback plan` documents the `kubectl rollout undo` command to use if something is wrong.

That manual release order becomes a GitHub Actions deployment workflow at the deployment automation gate:

```text
checkout
run backend tests
run frontend build
build backend image
push immutable image tag to ECR
update staging Kubernetes deployment
wait for rollout status
run staging health check
require approval for production
update production deployment
run production health check
keep rollback command visible
```

**What each step does in the automated workflow:** `checkout` fetches the code. Tests and build run first to catch regressions before any image is built. `push immutable image tag` uses the git commit SHA as the Docker tag so each deployment is traceable to a specific commit. `require approval for production` is a GitHub Actions environment protection rule - a human must approve before the production steps run. `keep rollback command visible` means the workflow outputs the `kubectl rollout undo` command in the logs even on success, so it is always one click away if needed.

Do not add blue/green, canary, or Terraform apply workflows until the simple manual staging deploy is repeatable.

## Check

Run from the repo root:

```powershell
make docs-check
git status
```

**What these commands do:** `make docs-check` runs the documentation readiness checks to confirm guide ordering and required sections are correct. `git status` shows that the new CI workflow file exists as an untracked or modified file in `.github/workflows/` - confirms the file was actually created.

Expected result: docs check passes and CI workflow file exists in `.github/workflows/`.

Current expected result:

```text
Parent workflow exists for docs/Terraform.
Backend workflow exists in the backend repo.
No deploy workflow exists yet.
```

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports running dev resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
