# Cloud Infrastructure Path

This guide explains the cloud path. Do not build all of it in one Terraform lesson.

## Final Infrastructure Areas

| Area | Purpose |
|---|---|
| VPC | Network boundary |
| Public subnets | Load balancers and public entry points |
| Private app subnets | Backend and workers |
| Private data subnets | Database and internal data services |
| ECR | Stores Docker images |
| EKS | Runs Kubernetes workloads |
| S3 | Stores uploads, logs, and training data |
| SQS | Durable work queues |
| EventBridge | Routes events |
| Secrets Manager | Stores secrets |
| CloudWatch | Logs, metrics, alarms |
| WAF later | Basic web protection |
| KMS later | Encryption keys |

## Why Start With Empty Terraform

A full Terraform stack creates too many errors at once.

Use this learning loop:

```text
one resource -> fmt -> validate -> plan -> explain plan -> follow the next documented step
```

**What this learning loop means:**

- `one resource` - add a single AWS resource to your Terraform config before moving on.
- `fmt` - run `terraform fmt` to auto-format so syntax errors don't hide real problems.
- `validate` - run `terraform validate` to check that provider references and variable types are correct before touching any real cloud account.
- `plan` - run `terraform plan` to preview exactly what AWS would create or change; nothing is deployed yet at this step.
- `explain plan` - read the plan output and understand every resource it lists before applying. If a resource is unfamiliar, look it up first.
- `follow the next documented step` - only move to the next guide step after the plan output matches expectations.

This loop prevents a common mistake where beginners apply a large Terraform config all at once and spend hours debugging cascading errors.

## Network Build Order

1. Provider only.
2. One S3 bucket for Terraform practice.
3. VPC.
4. Public subnet.
5. Private app subnet.
6. Private data subnet.
7. Route tables.
8. Internet gateway for public subnet.
9. NAT gateway only if needed.
10. VPC endpoints later to reduce NAT dependency.

## Public And Private Subnets

Use public subnets for things that must receive internet traffic:

- public load balancer

Use private subnets for internal workloads:

- backend pods
- workers
- database
- cache

Why: private services should not be directly reachable from the internet.

## Cost Rule

Before adding any AWS resource, write:

```text
What does this cost while idle?
How do I shut it down?
What command proves it exists?
What command proves it is gone?
```

**What this checklist means:**

- `What does this cost while idle?` - some AWS resources charge even when nothing is using them. NAT Gateways, RDS instances, and EKS clusters all cost money while stopped or unused, not just while handling traffic.
- `How do I shut it down?` - every resource added must have a known teardown path so you can stop billing immediately.
- `What command proves it exists?` - you need to confirm a resource actually got created, not just that Terraform reported success.
- `What command proves it is gone?` - you need to confirm destruction actually happened, not just that `terraform destroy` ran without error.

This is especially important for NAT Gateway, EKS, and databases.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks the current state of dev cloud resources.
- `make cloud-pause ENV=dev` pauses resources that support pausing without destroying them.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the `CONFIRM_DESTROY=YES` flag is a deliberate safety guard against accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms the environment is healthy before you start work.

If this guide was local-only, no cloud shutdown is needed.
