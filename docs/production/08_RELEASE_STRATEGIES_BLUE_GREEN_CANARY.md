# Release Strategies: Blue-Green, Canary, And AppConfig

Use this after staging deployment is reliable and rollback is manual but understood.

This guide integrates the ideas from the old `blue-green`, `canary`, and `appconfig` modules.

## Goal

Learn release safety after basic deployment works:

```text
manual release -> blue-green -> canary -> feature flags
```

**What this progression means:**

- `manual release` - you deploy by hand, know every step, and can manually roll back. This must work reliably before adding automation.
- `blue-green` - two identical production environments (blue and green) exist simultaneously. You shift traffic to the new version all at once, keeping the old version alive for instant rollback.
- `canary` - you shift a small percentage of traffic (e.g., 5%) to the new version and watch metrics before shifting more. Safer than blue-green for high-traffic services.
- `feature flags` - runtime toggles that enable or disable features without a deployment. Lets you separate code deployment from feature activation.

Do not add these before staging works.

## Parameters You Must Set First

```text
ENVIRONMENT=staging
APP_PORT=8080
HEALTH_PATH=/health
BLUE_SLOT=blue
GREEN_SLOT=green
CANARY_START_PERCENT=5
FEATURE_FLAG_PROFILE=feature-flags
```

**What these parameters mean:**

- `ENVIRONMENT=staging` - scope all release operations to staging, not production.
- `APP_PORT=8080` - the port the container listens on inside the pod or task.
- `HEALTH_PATH=/health` - the path used to determine whether a newly deployed version is healthy before shifting traffic.
- `BLUE_SLOT=blue` and `GREEN_SLOT=green` - identifiers for the two deployment targets. One is active, one is inactive at any time.
- `CANARY_START_PERCENT=5` - start canary deployments at 5% traffic to the new version. Monitor before shifting further.
- `FEATURE_FLAG_PROFILE=feature-flags` - the AppConfig profile name used to read runtime feature flag values.

## ECS/ALB Blue-Green Concept

Blue-green uses two target groups:

```text
blue target group
green target group
active-slot SSM parameter
ALB listener points to active slot
```

**What these components mean:**

- `blue target group` and `green target group` - two ALB target groups, each pointing to different container instances. Only one is live at a time.
- `active-slot SSM parameter` - an SSM Parameter Store value (e.g., `/skin-lesion/staging/active-slot`) that stores which slot is currently receiving traffic. Scripts read this to determine which slot is inactive for the next deploy.
- `ALB listener points to active slot` - the ALB listener forwarding rule sends 100% of traffic to whichever target group is designated active.

Release flow:

```text
deploy new version to inactive slot
run health checks
switch ALB listener
watch alarms
keep old slot ready for rollback
```

**What this release flow means:**

- `deploy new version to inactive slot` - push the new image to the blue or green slot that is currently not serving traffic.
- `run health checks` - hit the health endpoint on the inactive slot and confirm it responds correctly before shifting any traffic.
- `switch ALB listener` - update the ALB forwarding rule to point to the previously inactive slot. The switch happens atomically from a traffic perspective.
- `watch alarms` - monitor CloudWatch alarms for error rate, latency, and health check failures in the minutes after the switch.
- `keep old slot ready for rollback` - do not redeploy the old slot immediately. Keep it alive so you can switch the ALB listener back if alarms fire.

## Canary Concept

Canary uses weighted routing:

```text
baseline target group
canary target group
canary-weight SSM parameter
traffic shifts 5 -> 25 -> 50 -> 100
```

**What these canary components mean:**

- `baseline target group` - serves the existing stable version and receives the majority of traffic throughout the canary deployment.
- `canary target group` - serves the new version and receives only the canary percentage of traffic.
- `canary-weight SSM parameter` - stores the current traffic percentage sent to the canary target group (e.g., 5). Scripts read this to determine whether to increase or abort the rollout.
- `traffic shifts 5 -> 25 -> 50 -> 100` - a staged increase. At each step, you wait and watch metrics before proceeding. If alarms fire at any step, you abort and shift 100% back to baseline.

For EKS, use Kubernetes rollouts, Ingress, the AWS Load Balancer Controller, or a service mesh after the basic rollout path works. For ECS/ALB, use target group weighted forwarding.

Read the EKS-specific follow-up:

```text
docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
```

**What this guide covers:** EKS-native auto-healing using liveness probes, HPA, and `kubectl rollout undo`. The patterns are the same as above but implemented through Kubernetes resources instead of ALB target groups.

## AppConfig Concept

AppConfig is for feature flags and runtime configuration:

```text
new_heatmap_method
rag_explanation_v2
vlm_cross_check
canary_batch_percent
backward_compat_mode
async_report_generation
patient_memory_beta
```

**What these feature flags mean:**

- `new_heatmap_method` - toggles between the current Grad-CAM++ implementation and a new heatmap algorithm without redeployment.
- `rag_explanation_v2` - enables a new RAG-based explanation pipeline for a subset of users while the old pipeline stays active.
- `vlm_cross_check` - enables a vision-language model cross-check on the Grad-CAM output.
- `canary_batch_percent` - controls what percentage of inference batches use the canary model path.
- `backward_compat_mode` - keeps a compatibility shim active while downstream consumers migrate to a new API response shape.
- `async_report_generation` - switches PDF report generation from synchronous (blocking the request) to asynchronous (SQS-backed worker).
- `patient_memory_beta` - enables the patient memory/history feature for beta users only.

Use feature flags for behavior changes, not secrets.

Use the implementation guide:

```text
docs/production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md
```

**What this guide covers:** how to define flags in AWS AppConfig, fetch them at runtime from the backend, and gate code paths on flag values.

## Checks

Before using release automation, prove:

```text
manual deploy works
manual rollback works
health checks are reliable
alarms are meaningful
audit trail records deployment changes
```

**What this pre-automation checklist means:**

- `manual deploy works` - you can deploy a new version by following documented steps without the automation script.
- `manual rollback works` - you can revert to the previous version manually within a few minutes.
- `health checks are reliable` - health endpoints return accurate status; they do not return 200 when the app is actually broken.
- `alarms are meaningful` - CloudWatch alarms fire when something is genuinely wrong, not on every minor fluctuation.
- `audit trail records deployment changes` - every deployment, slot switch, and rollback is logged with timestamp and actor.

Expected result:

```text
release strategy adds safety, not complexity before the app can be operated.
```

**What this means:** release automation should make deployment safer, not more confusing. If you cannot operate the app manually, automation will make failures harder to diagnose, not easier.

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
- `make cloud-status ENV=dev` confirms it is healthy before work begins.

If this guide was local-only, no cloud shutdown is needed.
