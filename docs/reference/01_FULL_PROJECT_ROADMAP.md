# Full Project Roadmap

This guide explains the full project without asking you to build everything at once.

The target project state is:

```text
frontend -> backend API -> database state -> event queues/workers -> training bucket
                         -> model inference -> Grad-CAM explanation
                         -> Kubernetes/EKS runtime
                         -> Terraform-managed cloud infrastructure
```

**What this architecture diagram means:**

- `frontend -> backend API` - the Next.js browser app sends requests to the FastAPI backend.
- `database state` - the backend writes all decisions (consent, review status, training eligibility) to PostgreSQL as the single source of truth.
- `event queues/workers` - when a state changes (e.g., admin approves training eligibility), a message is published to SQS so a worker can process the next step asynchronously.
- `training bucket` - approved, consented training cases are written to a dedicated S3 bucket. Only this bucket feeds the retraining pipeline.
- `model inference -> Grad-CAM explanation` - the ResNet50 model produces a classification and the Grad-CAM++ layer produces a heatmap explanation from the same forward pass.
- `Kubernetes/EKS runtime` - containers run inside Kubernetes pods on EKS (after Docker and local Kubernetes are understood).
- `Terraform-managed cloud infrastructure` - VPC, subnets, S3, ECR, EKS, SQS, and other AWS resources are defined in Terraform and reproduced consistently.

## Final Shape

| Layer | Final choice | Why |
|---|---|---|
| Frontend | Next.js | Good for upload, result, review, and dashboard screens |
| Backend | FastAPI | Simple Python API that fits ML workflows |
| Local database | Postgres | Easy local development before Aurora DSQL staging validation |
| Cloud database target | Aurora DSQL | Planned cloud database path after local migrations work |
| Long workflows | Database state plus events | Better than trying to make Kubernetes run business approval flows |
| Event tools | SQS, EventBridge, worker process | Simple, durable, and easier than Airflow for this project |
| Runtime | Kubernetes locally, then EKS | You want to learn Kubernetes and service healing |
| Infrastructure | Terraform | Repeatable cloud setup, built one resource at a time |
| CI/CD | GitHub Actions later | Only useful after local tests and builds exist |

## Learning Rule

Each final architecture piece has two stages:

```text
learn locally -> prove with a check -> move to cloud later
```

**What this learning rule means:**

- `learn locally` - every cloud technology has a local equivalent. Learn the concept without cloud billing and without network complexity.
- `prove with a check` - run a specific check command (e.g., `curl`, `pytest`, `kubectl get pods`) that proves the step works. Do not move on without the check passing.
- `move to cloud later` - only after the local check passes do you translate the same concept to AWS. The failure modes are much cheaper to debug locally.

Example:

```text
local FastAPI /health -> Docker image -> local Kubernetes -> EKS
```

**What this example progression means:**

- `local FastAPI /health` - build and test the health endpoint with just Python, no containers.
- `Docker image` - package the app into a Docker container and confirm it runs correctly.
- `local Kubernetes` - deploy the container to a local Kubernetes cluster (kind or minikube) and confirm probes, rollout, and logs work.
- `EKS` - push the same image to ECR and deploy the same manifests to an AWS EKS cluster. The concepts learned locally apply directly.

## Do Not Skip The Local Stage

Cloud services hide too many problems at once. If the backend cannot pass local tests, EKS will only make the error harder to understand.

## Full Build Order

1. Local backend health endpoint.
2. Local mock analysis endpoint.
3. Local frontend upload flow.
4. Docker for backend.
5. Local Kubernetes.
6. Terraform provider only.
7. Terraform one small resource.
8. VPC and private/public subnet learning.
9. ECR and image push.
10. EKS dev cluster.
11. Database state model.
12. Event workflow with queues/workers.
13. Security and compliance controls.
14. Reliability, observability, RTO, and RPO.
15. CI/CD checks.
16. Deployment automation.
17. Multi-region learning.

## What Makes This A Full Project

The project is full because it includes:

- app code
- ML inference
- explainability
- user workflow
- security controls
- cloud infrastructure
- Kubernetes deployment
- event-driven processing
- reliability thinking
- cost controls
- operational checks

You will still build it part by part.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks the dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
