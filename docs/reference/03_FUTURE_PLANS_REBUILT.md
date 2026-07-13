# Professional Later-Sequence Plans Rebuilt

This file rebuilds the later-sequence ideas that should not be lost.

Later-sequence does not mean optional. It means the feature needs earlier API, database, model, or UI contracts before it can be built cleanly.

## Command Location

This guide has no build commands.

Read it from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal to the main workspace root. This guide has no build commands, but the `cd` ensures any Makefile or script calls in later sessions start from the correct directory.

## Near-Term Product Blocks

After the local app works:

- real model inference
- Grad-CAM explanation endpoint
- frontend result viewer
- consent checkbox
- doctor review screen
- admin approval screen
- local worker for training eligibility
- image quality and retake guidance
- clinical safety triage
- lesion profile and timeline
- 2D body mapping
- safe LLM explanation

## Cloud Path

After Docker and local Kubernetes work:

- Terraform VPC
- ECR repository
- EKS dev cluster
- S3 upload bucket
- S3 training bucket
- SQS queue
- EventBridge rules
- CloudWatch logs and alarms

## Database Path

Start with:

- local Postgres
- Alembic migrations
- SQLAlchemy models

Then evaluate:

- Aurora DSQL as the planned cloud database target
- Aurora PostgreSQL only as fallback if DSQL blocks progress

Keep fallback:

```text
If Aurora DSQL compatibility, cost, tooling, or operations are blocking, use Aurora PostgreSQL temporarily and document the blocker.
```

**What this fallback rule means:** Aurora DSQL is the planned cloud database target because of its distributed SQL capabilities. But it is newer than Aurora PostgreSQL and may have compatibility gaps (e.g., with specific SQLAlchemy features, Alembic migration commands, or transaction semantics). If you hit a genuine blocker, switching to Aurora PostgreSQL temporarily is allowed - but document the blocker so you can return to DSQL when the blocker is resolved.

## Multi-Region Path

Do this after local, Docker, Kubernetes, and single-region deployment checks work.

Study:

- Route 53 routing
- regional failover
- active-active writes
- database conflict behavior
- S3 replication
- secrets replication
- RTO and RPO

## Orchestration Path

Current choice:

```text
Kubernetes for runtime orchestration.
SQS/EventBridge/workers for business workflow orchestration.
```

**What this separation means:**

- `Kubernetes for runtime orchestration` - Kubernetes manages where containers run, how many replicas exist, and how to restart crashed pods. It does not track business state.
- `SQS/EventBridge/workers for business workflow orchestration` - the patient consent -> doctor validation -> admin approval -> training bucket sequence involves human decisions over hours or days. SQS queues hold the work durably while workers process each step independently and retry on failure.

Airflow is not first in the sequence.

Use Airflow later only if scheduled data pipelines, retraining DAGs, or batch jobs become more complex than queues and workers.

## Product Path

Possible product expansion:

- patient portal
- doctor portal
- admin portal
- audit dashboard
- model monitoring dashboard
- 3D body map after 2D body map and lesion fields exist
- mobile app after web/API contracts stabilize
- research-to-production model promotion
- MLflow later for experiment/model registry
- multi-model ensemble
- synthetic/demo mode
- fairness evaluation
- active learning

## Rule

Do not build later-sequence items before their prerequisites. Keep this as a map so every discussed feature remains in the implementation plan.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks the current dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources with explicit confirmation.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before work begins.

If this guide was local-only, no cloud shutdown is needed.
