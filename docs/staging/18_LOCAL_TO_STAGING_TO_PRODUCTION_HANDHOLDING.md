# Local To Staging To Production Handholding Guide

Use this after the local app, Docker image, local Kubernetes deployment, and basic cloud guides work individually.

## Current Project Implementation

Guide 18 is now aligned with the current staged build path:

```text
local checks -> local Docker/Compose -> local Kubernetes -> EKS dev -> DSQL/SQS gates -> staging -> production readiness
```

Files or folders that currently support the path:

```text
Makefile
infra/compose/docker-compose.local.yml
infra/compose/docker-compose.mlflow.yml
infra/k8s/dev/
infra/k8s/eks-dev/
infra/terraform/
.github/workflows/docs-terraform-ci.yml
Skin_Lesion_Classification_backend/.github/workflows/backend-ci.yml
```

Current gate status:

```text
Docs and Terraform validate locally.
Focused backend workflow/security/analytics tests pass locally.
EKS dev manifests parse with kubectl client dry-run.
Live AWS dev/staging gates still need AWS SSO and explicit apply approval.
Power BI and Azure app registration still need console approval.
```

Why: promotion should use evidence from each environment. This guide is the map; it does not create live staging or production resources by itself.

## Goal

Turn separate guides into one smooth promotion path:

```text
local dev -> local Docker -> local Kubernetes -> AWS dev -> staging -> production readiness -> production
```

**What this progression means:** each arrow is a gate. Local dev proves the code works. Local Docker proves the container works. Local Kubernetes proves the manifest, probes, and service routing work. AWS dev proves cloud wiring works cheaply. Staging proves it works in a production-like environment with real migrations and monitoring. Production readiness proves the operating model (backup, rollback, alerts) is documented. Only then does production traffic start.

Do not skip directly from local code to production. Each environment proves one extra risk at a time.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Most commands in this guide run from here or from a subdirectory named in the step.

Use these repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
infra/terraform
infra/k8s
```

**What these paths are:** each directory is a separate concern. The backend and frontend repos hold application code. `infra/terraform` holds infrastructure-as-code. `infra/k8s` holds Kubernetes manifests. Each step names which directory its commands belong to.

## Step 1: Local Dev Gate

Run local checks from the main workspace:

```powershell
make backend-test
make frontend-build
make docs-check
```

**What these commands do:** `make backend-test` runs the full backend test suite. `make frontend-build` runs the Expo/React Native build to check for TypeScript errors and missing dependencies. `make docs-check` verifies documentation ordering and required sections are present. All three must pass before any cloud steps begin.

Expected result:

```text
backend tests pass
frontend builds
docs-check ok
```

**What this means:** the local code is in a known good state. Cloud deploy failures can then be attributed to infrastructure or configuration, not code bugs.

Why: cloud deployment should not be used to discover basic code errors.

## Step 2: Local Docker Gate

Run from:

```text
Skin_Lesion_Classification_backend
```

Command:

```powershell
cd Skin_Lesion_Classification_backend
docker build -t skin-lesion-backend:local .
docker run --rm -p 8080:8080 skin-lesion-backend:local
```

**What these commands do:** `docker build` creates the container image from the Dockerfile in the backend directory. `docker run --rm` starts the container and removes it automatically when it stops. `-p 8080:8080` maps the container's port 8080 to your machine's port 8080 so you can reach it from localhost.

In a second terminal from the main workspace:

```powershell
curl http://localhost:8080/health
```

**What this does:** sends an HTTP GET to the running container's health endpoint to confirm the FastAPI app started and is responding.

Expected result:

```json
{"status":"ok"}
```

**What this means:** the container image is built correctly and the app starts inside it. If this fails, fix the Docker issue before any Kubernetes or cloud steps.

Why: staging and production should run the same container shape that works locally.

## Step 3: Local Kubernetes Gate

Run from the main workspace:

```powershell
kubectl apply -f infra/k8s/dev
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
kubectl port-forward -n skin-lesion-dev service/skin-lesion-backend 8080:80
```

**What these commands do:** `kubectl apply -f infra/k8s/dev` creates the namespace, deployment, and service from the YAML manifests. `kubectl rollout status` waits until all pods are ready and the readiness probe passes. `kubectl port-forward` opens a local tunnel to the service so you can test without a load balancer.

In a second terminal:

```powershell
curl http://localhost:8080/health
```

**What this does:** tests the health endpoint through the port-forward tunnel to confirm the pod is running and serving traffic correctly through the Kubernetes Service.

Expected result:

```text
the pod is running and /health returns ok through the Kubernetes service
```

**What this means:** local Kubernetes works end-to-end. The manifests, probes, service routing, and container image are all correctly configured.

Why: EKS is easier after pods, services, probes, logs, and rollout checks make sense locally.

## Step 4: AWS Dev Gate

Use dev for cheap, disposable learning.

Create or verify:

```text
ECR repository
dev VPC
private app subnet
private data subnet
dev Kubernetes namespace
dev object storage bucket
dev database endpoint when needed
dev secrets
```

**What these resources are:** the minimum cloud infrastructure needed for a dev environment. ECR stores the Docker image. The VPC and subnets provide network isolation. The namespace keeps dev resources separate inside the EKS cluster. Object storage holds uploaded images. The database and secrets are created only when a specific guide requires them.

Run Terraform checks from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before any `terraform` command. The plan runs from this directory.

Commands:

```powershell
cd infra/terraform
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** `terraform fmt` formats all `.tf` files. `terraform validate` checks syntax and resource references. `terraform plan` previews what Terraform will create - review this output to confirm only dev resources appear and nothing production-scale is in the plan.

Expected result:

```text
the plan is understandable and does not include production resources
```

**What this means:** you can explain every resource in the plan in plain terms. If you cannot explain a resource, remove it before applying.

Why: dev proves cloud wiring without pretending to be a production release.

Current note:

```text
terraform validate can run without AWS credentials.
terraform plan needs the configured S3 backend credentials and therefore requires AWS SSO first.
```

## Step 5: AWS Staging Gate

Use staging as the first production-like environment.

Staging must have:

```text
separate namespace or cluster
separate database
separate storage buckets
separate secrets
realistic migrations
realistic monitoring
no real patient data unless explicitly approved
```

Current staging blocker:

```text
Staging cannot be claimed live until DSQL, EKS rollout, Power BI/Azure secrets, Redis, and MLflow are explicitly enabled and checked in AWS/Azure.
```

**What each requirement means:** separate namespace or cluster prevents staging changes from affecting dev. Separate database means a staging-specific Aurora DSQL cluster or RDS instance - never shared with dev. Separate storage buckets ensures staging uploads do not mix with dev test data. Separate secrets means staging credentials are distinct from dev credentials. Realistic migrations means all Alembic migrations run against the staging database. Realistic monitoring means CloudWatch alarms and GuardDuty are active. No real patient data is a compliance boundary - staging uses synthetic or anonymized data only.

Checks:

```powershell
make backend-test
make frontend-build
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
curl https://STAGING_BACKEND_URL/health
```

**What these commands do:** `make backend-test` runs the full test suite one more time against the staging build. `make frontend-build` confirms the frontend still builds. `kubectl rollout status` confirms the staging pod is running and healthy. `curl` tests the health endpoint through the real ALB hostname (not port-forward) to confirm public traffic routing works.

Expected result:

```text
staging deploys the same tested image and passes health checks
```

**What this means:** the image that passed local tests is the same image running in staging. No differences in code, only in environment configuration.

Why: staging catches environment and migration issues before production users see them.

## Step 6: Production Readiness Gate

Before production, document and test:

```text
backup and restore
rollback
audit logging
secret rotation
least-privilege IAM
database migration plan
object storage privacy
monitoring alerts
cost shutdown rules for non-prod
RTO and RPO
incident contact path
```

**What each item means:** `backup and restore` means you have tested restoring from a database snapshot, not just created one. `rollback` means you have run `kubectl rollout undo` at least once and confirmed it works. `audit logging` means CloudTrail is active and logs are confirmed present. `secret rotation` means the plan for rotating database passwords and JWT secrets is documented. `least-privilege IAM` means each IAM role has been reviewed against what it actually needs. `database migration plan` means you know how to run a zero-downtime migration. `object storage privacy` means all S3 buckets have public access block confirmed. `monitoring alerts` means at least one alarm has been triggered and confirmed to send a notification. `cost shutdown rules for non-prod` means the shutdown procedure is written and tested. `RTO and RPO` means the numbers are agreed and documented. `incident contact path` means you know who to call and how if something breaks in production.

Check:

```powershell
make docs-check
```

**What this does:** runs the documentation readiness checks to verify all required sections and guide ordering are correct. Pass this check before claiming the production readiness gate is complete.

Expected result:

```text
the production path is documented before automation exists
```

**What this means:** the operating model (how to run, monitor, and recover the system) is written down and verified before the first production deployment. Documentation is not optional here - it is a prerequisite.

Why: production is not only a bigger deploy target. It is an operating model.

## Step 7: Production Release Gate

Only after manual staging deployment works, add deployment automation.

Release order:

```text
build image
push immutable image tag
run tests
deploy to staging
run staging health checks
approve production
deploy to production
run production health checks
watch logs and alerts
keep rollback ready
```

**What this release order enforces:** `push immutable image tag` uses the git commit SHA as the Docker tag so each release is traceable. Tests run before any deployment, not after. Staging deploys and passes health checks before the production approval step is unlocked. `approve production` is a manual human decision - not automated. Production health checks run immediately after deploy so failures are caught within seconds of the release.

Do not add:

```text
automatic production apply
blue/green release
canary release
multi-region active-active
```

**What this restriction means:** each of these adds significant operational complexity. Blue/green and canary require traffic splitting and rollback automation that must be thoroughly tested before trusting with production traffic. Multi-region active-active requires distributed transaction handling and conflict resolution. All of them are correct eventually - just not before the simple single-region release is repeatable and well understood.

until simple production release is understood and repeatable.

Current repo follows this rule: no production deployment automation was added in Guide 17.

## Stop Point

Production is ready to discuss only after:

```text
local tests pass
local Docker works
local Kubernetes works
AWS dev deploy works
staging deploy works
rollback is documented
monitoring exists
security controls are checked
```

**What this stop point means:** all eight conditions must be true, not just most of them. Each one closes a specific failure mode. `rollback is documented` and `monitoring exists` are often skipped under schedule pressure - they are listed here as blocking requirements specifically because of that tendency.

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
