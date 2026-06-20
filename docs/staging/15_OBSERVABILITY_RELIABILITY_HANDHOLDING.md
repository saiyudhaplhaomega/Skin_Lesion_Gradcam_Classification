# Observability And Reliability Handholding Guide

Use this after the backend can run locally and in Kubernetes.

## Current Project Implementation

The backend already exposes the two health endpoints this guide requires, and the EKS manifests from Guides 08/09 include probes for the backend deployment path.

Existing files:

```text
Skin_Lesion_Classification_backend/app/main.py
Skin_Lesion_Classification_backend/app/api/v1/router.py
Skin_Lesion_Classification_backend/tests/test_health.py
infra/k8s/eks-dev/deployment.yaml
```

New reliability pieces from Guides 12/13/16:

```text
Local outbox worker: Skin_Lesion_Classification_backend/app/workers/training_bucket_worker.py
SQS consumer shell: Skin_Lesion_Classification_backend/app/workers/sqs_consumer.py
Queue-depth alarms: infra/terraform/security_observability.tf
```

Check commands:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_health.py tests/test_training_workflow.py -v
```

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
kubectl apply --dry-run=client -f infra\k8s\eks-dev
```

Expected result:

```text
/health and /api/v1/ready tests pass.
The local worker handles pending outbox events.
Kubernetes manifests parse with readiness and liveness probes.
```

## Goal

Know when the system is broken and how to recover.

Why: reliability work needs measurable health, logs, rollback commands, and shutdown rules before production-style operations.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Kubernetes commands run from here.

Backend logging and health endpoint changes belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** health endpoint routes, log middleware, and structured logging config are Python code that lives in the backend repo. `cd Skin_Lesion_Classification_backend` before editing or testing those files.

Kubernetes checks run from the repo root after Kubernetes manifests exist.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Kubernetes manifests: `infra/k8s/`
- Create or edit backend logging, health, and readiness code under `Skin_Lesion_Classification_backend/`.
- Create or edit Kubernetes probes and rollout settings under the exact `infra/k8s/...` path named by the step.

## Step 1: Health Endpoints

Keep:

```text
GET /health
GET /api/v1/ready
```

**What these endpoints do:** `/health` answers "is the process running?" - it should respond instantly even if the database is down. Kubernetes uses this for the liveness probe: if it fails, the pod is killed and restarted. `/ready` answers "are the dependencies reachable?" - it checks the database connection and any other required services. Kubernetes uses this for the readiness probe: if it fails, traffic is not routed to the pod but the pod is not killed.

`/health` means the process is alive.

`/ready` means dependencies are ready.

## Step 2: Structured Logs

Log:

- request id
- path
- status code
- case id when available
- error type

Do not log:

- raw secrets
- full patient image data
- access tokens

## Step 3: Worker Reliability

Worker must handle:

- duplicate message
- missing case
- wrong status
- S3 failure
- retry limit

Current local worker behavior:

```text
pending -> processing before work starts
attempts increments before work starts
published is set only after successful queue/training state handling
failed is set after the retry limit
```

## Step 4: Kubernetes Reliability

Use:

- readiness probe
- liveness probe
- rollout status
- logs
- rollback

Checks:

```powershell
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
kubectl logs deployment/skin-lesion-backend -n skin-lesion-dev
kubectl rollout undo deployment/skin-lesion-backend -n skin-lesion-dev
```

**What these commands do:**

- `kubectl rollout status` - watches the deployment until all replicas are ready, then prints `successfully rolled out`. Blocks the terminal until done or fails with an error.
- `kubectl logs deployment/skin-lesion-backend` - streams stdout/stderr from all pods in the deployment. Add `-f` to follow continuously. Add `--previous` to see logs from a crashed pod.
- `kubectl rollout undo` - rolls the deployment back to the previous image version. Kubernetes keeps revision history so this is a fast, safe recovery step when a bad deploy is caught quickly.

## Step 5: RTO And RPO

For learning:

```text
dev RTO: hours
dev RPO: can recreate test data
production-style patient workflow RTO: minutes
production-style patient workflow RPO: near zero
```

**What RTO and RPO mean:** RTO (Recovery Time Objective) is how long the system can be down before it becomes a problem. RPO (Recovery Point Objective) is how much data loss is acceptable. For dev, hours of downtime and losing test data are acceptable. For a production-style patient workflow, downtime must be in minutes (not hours), and patient consent and case data cannot be lost - hence "near zero" RPO requiring database backups or multi-AZ replication.

## Step 6: Cost Shutdown

Keep a shutdown checklist for:

- EKS dev cluster
- NAT Gateway
- load balancer
- database
- unused ECR images
- old CloudWatch logs

## Cost Pause / Resume

Expected result:

```text
Health endpoints, structured logs, worker retry behavior, Kubernetes checks, and RTO/RPO targets are documented before production operations.
```

**What this means:** the observability foundation is in place - you know how to detect failures, read logs, and recover. These are prerequisites before adding production traffic or more complex automation.

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
