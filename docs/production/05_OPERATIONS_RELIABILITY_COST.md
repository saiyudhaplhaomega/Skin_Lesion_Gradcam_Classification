# Operations, Reliability, And Cost

This guide explains how the finished project should behave when things fail.

## Reliability Questions

For each service, ask:

```text
What if it crashes?
What if it gets slow?
What if its dependency is down?
What if the deploy is bad?
What if the queue has old messages?
```

**What these questions mean:**

- `What if it crashes?` - every service should have a restart strategy and liveness probes. Kubernetes restarts crashed pods, but application-level state may be lost. Plan for it.
- `What if it gets slow?` - a slow service is often worse than a crashed one, because traffic keeps arriving and queuing. Timeout budgets and backpressure protect downstream services.
- `What if its dependency is down?` - services that call databases, S3, or LLMs need circuit breakers to degrade gracefully instead of cascading failure upstream.
- `What if the deploy is bad?` - every deploy needs a rollback path. For Kubernetes: `kubectl rollout undo`. For models: promote the previous registry version.
- `What if the queue has old messages?` - SQS retains messages for up to 14 days. A dead-letter queue catches messages that fail processing repeatedly. Without a DLQ, you will not know about stuck messages until they expire.

## Auto Healing

Kubernetes helps with:

- crashed backend pods
- crashed worker pods
- unhealthy containers
- keeping replicas running

Cloud services help with:

- SQS message durability
- S3 object durability
- managed database backups
- CloudWatch alarms

You still need application-level handling for:

- invalid states
- duplicate events
- failed approvals
- partial writes
- bad migrations

## Observability

Add these slowly:

1. structured logs
2. request IDs
3. health endpoints
4. worker logs
5. queue depth metric
6. error rate alarm
7. latency alarm
8. deployment rollback notes

## Cost Efficiency

For dev, prefer resources that can be stopped or deleted.

Write shutdown notes for:

- EKS dev cluster
- NAT Gateway
- database
- load balancer
- unused ECR images
- CloudWatch logs retention

## Operational Excellence

Before automating deployment, prove manual operation:

```text
run tests
build image
run container
deploy locally
check health
view logs
rollback manually
```

**What this manual operations checklist means:**

- `run tests` - prove the code change is correct before it gets packaged.
- `build image` - `docker build` produces a tagged image artifact. If it builds successfully, the Docker layer cache and build config are validated.
- `run container` - `docker run` the built image locally and confirm the app starts. Problems at this step are easier to debug than problems in Kubernetes.
- `deploy locally` - apply a Kubernetes manifest against your local cluster. Confirm the pod becomes Ready before sending any traffic.
- `check health` - hit the `/health` and `/api/v1/ready` endpoints. A Ready pod does not always mean a healthy application.
- `view logs` - `kubectl logs` confirms the app booted correctly and there are no error messages at startup.
- `rollback manually` - practice `kubectl rollout undo deployment/<name>` so you know exactly how to revert before you are under pressure during an incident.

Only then add CI/CD.

## Sustainability

Sustainability in this project mostly means not running idle cloud resources.

Use:

- dev shutdown checklist
- short log retention in dev
- small instance choices
- delete unused images
- avoid always-on resources until needed

## Learning Check

Before calling the architecture production-style, document:

```text
How do I deploy?
How do I roll back?
How do I know it is broken?
How do I recover?
How do I shut it down to save money?
```

**What this learning check means:**

- `How do I deploy?` - you should be able to state the exact commands or pipeline steps that move new code to the running environment.
- `How do I roll back?` - you should be able to revert to the previous version within a few minutes without losing data.
- `How do I know it is broken?` - CloudWatch alarms, SLO breach, DLQ depth, or an alert page tells you something is wrong before users report it.
- `How do I recover?` - each runbook step should be written down, not memorized, so a team member can execute recovery without the original author.
- `How do I shut it down to save money?` - every cloud resource has a teardown path. If you cannot cleanly stop a resource, you will keep paying for it by accident.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports dev resource state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag is a deliberate safety guard.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms the environment is healthy.

If this guide was local-only, no cloud shutdown is needed.
