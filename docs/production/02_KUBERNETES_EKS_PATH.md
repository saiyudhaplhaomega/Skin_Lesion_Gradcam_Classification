# Kubernetes And EKS Path

Kubernetes is the runtime orchestrator for services in this project.

That means Kubernetes handles:

- running containers
- restarting failed pods
- rolling out new versions
- health checks
- service discovery
- scaling pods

Kubernetes should not own long business approval workflows.

## What Kubernetes Is Good For

Use Kubernetes for:

- backend API
- worker process
- scheduled jobs later
- health checks
- rollout and rollback
- horizontal scaling

## What Kubernetes Is Not Good For

Do not use Kubernetes alone for:

```text
patient consents -> doctor validates -> admin approves -> write to training bucket
```

**What this flow means:**

- Each step in this sequence may happen hours or days apart, which is far too long for a single HTTP request to stay open.
- A Kubernetes pod restart between steps would lose all progress unless the state is persisted elsewhere.
- Durable state means: every step's outcome is written to the database immediately. The workflow can be reconstructed by reading the database even after a crash.
- Events means: instead of one service calling another directly, each step publishes a message to a queue so the next step picks it up independently.

That workflow needs durable state and events.

Use:

- database rows for status
- outbox table for reliable event creation
- SQS queues for work
- worker pods for processing

## Local Kubernetes First

Before EKS, learn:

1. namespace
2. deployment
3. service
4. health checks
5. logs
6. rollout status
7. rollback

## EKS Later

Move to EKS after:

- backend Docker image works
- local Kubernetes works
- Terraform basics are understood
- ECR image push works

## Auto Healing

Kubernetes gives basic auto healing through:

- restarting crashed containers
- replacing unhealthy pods
- keeping desired replica count
- rolling back if you configure deployment discipline

It does not automatically fix bad business data, bad database migrations, or wrong IAM permissions.

## Learning Check

For every Kubernetes manifest, answer:

```text
What object is this?
What does it run?
How does Kubernetes know it is healthy?
How do I view logs?
How do I roll back?
```

**What this checklist means:**

- `What object is this?` - Kubernetes has Deployments, Services, ConfigMaps, Secrets, Ingresses, and more. Knowing the object type tells you what it controls and how to manage it.
- `What does it run?` - every Deployment specifies a container image. If you do not know which image version a Deployment runs, you cannot reason about what code is live.
- `How does Kubernetes know it is healthy?` - every Pod should declare a liveness probe and a readiness probe. Without them, Kubernetes will send traffic to crashed or unready containers.
- `How do I view logs?` - `kubectl logs <pod>` retrieves stdout/stderr. Knowing this before something breaks saves time.
- `How do I roll back?` - `kubectl rollout undo deployment/<name>` reverts to the previous stable revision. Practice this before a real incident.

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
- `make cloud-pause ENV=dev` pauses resources that can be stopped without destruction.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev cloud resources; `CONFIRM_DESTROY=YES` is required to prevent accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms the environment is ready before beginning work.

If this guide was local-only, no cloud shutdown is needed.
