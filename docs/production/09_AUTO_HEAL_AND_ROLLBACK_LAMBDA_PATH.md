# ECS Auto-Heal And Auto-Rollback Lambda Path

Use this only after manual rollback, alarms, and release slots are proven.

This guide integrates the ideas from:

```text
auto-heal-lambda
auto-rollback-lambda
former lambda/auto_heal.py
former lambda/auto_rollback.py
```

**What these names refer to:** former Terraform module names and Lambda source files that handled ECS service health and ALB target-group rollback. The Terraform modules were removed after the project switched to EKS; the Lambda source files were also deleted after their behavior was documented here.

Important: this is the ECS/ALB reference path. It is not the EKS main path.

For EKS, use:

```text
docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
```

**What this guide covers:** Kubernetes-native auto-healing with liveness probes, HPA, and `kubectl rollout undo`, replacing the Lambda-based ECS approach documented here.

## Goal

Automate only the actions you already trust manually:

```text
CloudWatch alarm -> SNS -> Lambda -> limited remediation -> notification
```

**What this automation flow means:**

- `CloudWatch alarm` fires when a metric (CPU, memory, latency, health check failure) breaches its threshold.
- `SNS` (Simple Notification Service) receives the alarm event and fans it out to subscribers.
- `Lambda` is subscribed to the SNS topic and receives the alarm payload. It decides what limited action to take.
- `limited remediation` means the Lambda does only a narrow, safe action: restart a task, redirect traffic, or scale up. It does not delete data or make schema changes.
- `notification` means every automated action sends a message to the ops channel or email so a human knows what happened.

## ECS Auto-Heal Behavior

The old auto-heal Lambda handled ECS service remediation:

```text
high memory -> increase desired task count
high CPU -> increase desired task count
failed health checks -> force new deployment
high latency -> stop one running task
unknown alarm -> notify only
```

**What these remediation actions mean:**

- `high memory -> increase desired task count` - adds more ECS tasks to spread the memory load. This is horizontal scaling, not a memory leak fix.
- `high CPU -> increase desired task count` - adds more ECS tasks when CPU utilization is high.
- `failed health checks -> force new deployment` - triggers a fresh ECS task deployment when the running tasks fail ALB health checks.
- `high latency -> stop one running task` - stops a single ECS task, hoping that ECS starts a fresh one that restores normal behavior. This is a last resort.
- `unknown alarm -> notify only` - for any alarm state the Lambda does not recognize, it sends a notification without taking any action. Failing safe means doing nothing when uncertain.

It calls ECS APIs:

```text
ecs.describe_services
ecs.update_service
ecs.stop_task
```

**What these API calls do:**

- `ecs.describe_services` reads the current state of the ECS service (running count, desired count, deployment status).
- `ecs.update_service` updates the desired task count or triggers a new deployment.
- `ecs.stop_task` stops a specific running task, which ECS will then replace automatically.

Do not wire this Lambda to EKS alarms. EKS healing is probes, HPA, Deployment rollout, and `kubectl rollout undo`.

## Auto-Rollback Behavior

The old auto-rollback Lambda handled:

```text
read active slot from SSM
select the inactive blue/green target group
modify ALB listener
write new active slot to SSM
send SNS notification
```

**What this auto-rollback sequence means:**

- `read active slot from SSM` - the Lambda starts by reading which blue/green slot is currently active from Parameter Store. This avoids hardcoding and makes the slot state observable.
- `select the inactive blue/green target group` - whichever slot is not active is the rollback target. Traffic is shifted to the previously stable slot.
- `modify ALB listener` - the Lambda calls `elbv2.modify_listener` to update the ALB forwarding rule, shifting 100% of traffic to the stable slot.
- `write new active slot to SSM` - updates the SSM parameter to reflect the new active slot, keeping the state machine consistent.
- `send SNS notification` - notifies the ops team that an automatic rollback occurred, including the reason and timestamp.

This only belongs after blue-green target groups and ALB listener switching are understood.

For EKS, rollback is Kubernetes rollout state, not ECS target group switching.

## Parameters You Must Set First

```text
ENVIRONMENT=staging
SNS_TOPIC_ARN=...
ALB_ARN=...
BLUE_TG_ARN=...
GREEN_TG_ARN=...
ACTIVE_SLOT_SSM=/skin-lesion/staging/active-slot
MAX_AUTO_SCALE_COUNT=6
```

**What these parameters mean:**

- `ENVIRONMENT=staging` - scope all remediation to staging only. Never run this against production automatically until it has been proven in staging.
- `SNS_TOPIC_ARN` - the SNS topic that receives alarm events from CloudWatch and forwards them to the Lambda.
- `ALB_ARN` - the Application Load Balancer that the auto-rollback Lambda will modify.
- `BLUE_TG_ARN` and `GREEN_TG_ARN` - the ARNs of the two target groups for the blue-green deployment. The Lambda needs both to switch between them.
- `ACTIVE_SLOT_SSM` - the SSM Parameter Store path that tracks which target group is currently active. The Lambda reads this before and writes it after the rollback.
- `MAX_AUTO_SCALE_COUNT=6` - a hard cap on how many tasks the auto-heal Lambda is allowed to scale to. Without a cap, a bug could trigger unlimited scaling and a large bill.

## Safety Rules

Auto-remediation must:

```text
log every action
send notification
have maximum limits
avoid destructive data actions
fail closed to notify-only
be disabled in early dev
be tested in staging first
```

**What these safety rules mean:**

- `log every action` - the Lambda must write a structured log entry for every action it takes, including the alarm name, action taken, and timestamp.
- `send notification` - every action triggers an SNS notification to the ops channel. No silent automatic changes.
- `have maximum limits` - scaling limits (like `MAX_AUTO_SCALE_COUNT`) prevent runaway remediation caused by a feedback loop or bug.
- `avoid destructive data actions` - the Lambda must never delete, modify, or move data. It can only restart services or redirect traffic.
- `fail closed to notify-only` - if the Lambda does not recognize an alarm or encounters an error, it must send a notification and stop. Taking an unknown action could make things worse.
- `be disabled in early dev` - do not wire up automatic remediation while you are still debugging the base application. Automation hides problems during development.
- `be tested in staging first` - trigger a test alarm in staging and verify the Lambda's response before enabling it in any higher environment.

Do not use auto-heal to hide broken deployments. Fix the app or rollback.

## Checks

Before enabling:

```text
manual rollback succeeds
alarms are not noisy
SNS notification works
Lambda has least-privilege IAM
staging test alarm triggers expected behavior
rollback leaves audit trail
runtime is ECS/ALB, or the EKS guide is used instead
```

**What this pre-enable checklist means:**

- `manual rollback succeeds` - you must prove you can roll back by hand before trusting automation to do it.
- `alarms are not noisy` - if alarms fire frequently for non-issues, the Lambda will take unwanted actions constantly. Clean up alarm thresholds first.
- `SNS notification works` - test that notifications reach the ops channel before automation is live.
- `Lambda has least-privilege IAM` - the Lambda IAM role must only allow the specific ECS and ALB API calls it needs. No `AdministratorAccess`.
- `staging test alarm triggers expected behavior` - manually fire a test alarm in staging and verify the Lambda takes the right action.
- `rollback leaves audit trail` - the SSM state update, log entry, and SNS notification together form the audit record.
- `runtime is ECS/ALB, or the EKS guide is used instead` - this Lambda code is ECS-specific. If your runtime is EKS, use `10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md`.

Expected result:

```text
automation performs a narrow, reversible action that an operator already understands.
```

**What this means:** the automation should do exactly one thing the operator would do manually. If you could not describe in one sentence what the Lambda does, it is doing too much.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the dev environment state.
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
- `make cloud-status ENV=dev` confirms it is healthy before you begin.

If this guide was local-only, no cloud shutdown is needed.
