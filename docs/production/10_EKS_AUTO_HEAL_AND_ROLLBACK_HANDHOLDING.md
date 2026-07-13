# EKS Auto-Heal And Rollback Handholding Guide

Use this after staging EKS deployment, Ingress, CloudWatch alarms, and manual rollback work.

The former Lambda files under `infra/terraform/lambda` were ECS/ALB-specific. They were deleted after their behavior was preserved in the ECS reference guide. They do not auto-heal EKS workloads.

## Goal

Use Kubernetes-native healing for the EKS main path:

```text
probes -> pod restart -> Deployment rollout -> HPA scaling -> manual rollback -> alarm-assisted rollback later
```

**What this EKS healing sequence means:**

- `probes` - liveness and readiness probes are the first layer. Kubernetes uses them automatically to restart unhealthy pods and remove unready pods from traffic.
- `pod restart` - when a liveness probe fails, Kubernetes kills the container and restarts it. No human action needed.
- `Deployment rollout` - when you push a new image, Kubernetes rolls out the new pods gradually. If the rollout fails health checks, it stops.
- `HPA scaling` - the Horizontal Pod Autoscaler adds or removes pods automatically based on CPU or memory metrics.
- `manual rollback` - `kubectl rollout undo` reverts to the previous Deployment revision. You must know how to do this before adding automation.
- `alarm-assisted rollback later` - after manual rollback is proven, a CloudWatch alarm can notify a runbook or trigger a limited automation.

ECS Lambda code remains an alternate runtime reference only.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal to the main workspace root so `kubectl` and Makefile commands use the right context and relative paths.

Kubernetes manifests belong under:

```text
infra/k8s/overlays/staging
```

**What this path means:** Kubernetes manifests are organized with Kustomize overlays. The `staging` overlay holds manifests that are specific to the staging environment, separate from `base` definitions shared across environments.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Kubernetes manifests: `infra/k8s/overlays/staging/`
- Terraform/IAM files, if a step creates alarm integration: `infra/terraform/`
- Operational scripts, if a step creates them: `scripts/` under the main workspace.
- Run Kubernetes commands from the main workspace and Terraform commands from `infra/terraform/` only when a step explicitly enters Terraform.

## Parameters You Must Set First

```text
NAMESPACE=skin-lesion-staging
DEPLOYMENT_NAME=skin-lesion-backend
MIN_REPLICAS=2
MAX_REPLICAS=6
CPU_TARGET_PERCENT=70
MEMORY_TARGET_PERCENT=75
HEALTH_PATH=/health
READY_PATH=/api/v1/ready
ROLLBACK_REVISION=<previous known-good rollout revision>
```

**What these parameters mean:**

- `NAMESPACE=skin-lesion-staging` - the Kubernetes namespace where staging resources live. All `kubectl` commands in this guide use `-n skin-lesion-staging`.
- `DEPLOYMENT_NAME=skin-lesion-backend` - the name of the Kubernetes Deployment to manage. Use this consistently in rollout and HPA commands.
- `MIN_REPLICAS=2` - keep at least 2 pods running at all times. A single-replica setup has no failover during a pod restart.
- `MAX_REPLICAS=6` - the HPA will not scale beyond 6 pods. This caps cloud cost from unexpected scaling events.
- `CPU_TARGET_PERCENT=70` - the HPA scales up when average CPU across pods exceeds 70%. Tune this after observing real traffic.
- `MEMORY_TARGET_PERCENT=75` - the HPA may also scale on memory if configured.
- `HEALTH_PATH=/health` - the endpoint the liveness probe checks. Must return 200 when the app is running correctly.
- `READY_PATH=/api/v1/ready` - the endpoint the readiness probe checks. Must return 200 only when the app is ready to serve traffic (database connected, model loaded).
- `ROLLBACK_REVISION` - the specific revision number from `kubectl rollout history` to roll back to. Find it before an incident, not during one.

## Step 1: Probes Are The First Auto-Heal

Create or edit:

```text
infra/k8s/overlays/staging/deployment.yaml
```

**What this file is:** the Kubernetes Deployment manifest that defines the container spec, resource limits, environment variables, and probes for the backend service.

Add:

```yaml
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /api/v1/ready
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10
  timeoutSeconds: 5
  failureThreshold: 3
```

**What these probe fields do:**

- `livenessProbe` - Kubernetes checks this to decide if the container is still alive. A failing liveness probe triggers a container restart.
- `readinessProbe` - Kubernetes checks this to decide if the container is ready to serve traffic. A failing readiness probe removes the pod from the Service's endpoints until it recovers.
- `httpGet.path` - the HTTP endpoint to GET for the health check response. Must return HTTP 200 to pass.
- `httpGet.port` - the port the probe connects to. Must match the port the container listens on.
- `initialDelaySeconds` - how many seconds to wait after container start before the first probe check. The liveness probe waits 30s to give the model time to load; readiness waits only 10s.
- `periodSeconds` - how frequently the probe checks. Readiness checks every 10s; liveness checks every 20s.
- `timeoutSeconds: 5` - if the probe does not get a response within 5 seconds, the attempt counts as failed.
- `failureThreshold: 3` - the probe must fail 3 consecutive times before Kubernetes takes action (restart for liveness, remove from traffic for readiness).

Check:

```powershell
kubectl apply -f infra/k8s/overlays/staging/deployment.yaml
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
kubectl describe pod -n skin-lesion-staging -l app=skin-lesion-backend
```

**What these commands do:**

- `kubectl apply -f ...` applies the updated manifest to the cluster. If the Deployment already exists, Kubernetes compares the new spec to the existing one and rolls out changes.
- `kubectl rollout status ...` waits and prints progress as the rollout completes. It exits with a non-zero code if the rollout fails, making it useful in scripts.
- `kubectl describe pod ... -l app=skin-lesion-backend` shows detailed pod information including probe configuration, recent events, and restart count. The Events section is where you look if probes are failing.

Expected result:

```text
Pods have liveness and readiness probes.
Bad pods are restarted by Kubernetes.
Unready pods are removed from Service traffic.
```

## Step 2: Add Horizontal Pod Autoscaling

Create:

```text
infra/k8s/overlays/staging/hpa.yaml
```

**What this file is:** the Kubernetes HorizontalPodAutoscaler manifest that tells Kubernetes when to add or remove pod replicas automatically.

Paste:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-staging
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: skin-lesion-backend
  minReplicas: 2
  maxReplicas: 6
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

**What this HPA manifest does:**

- `apiVersion: autoscaling/v2` uses the v2 autoscaling API, which supports multiple metrics and more flexible scaling behavior than v1.
- `kind: HorizontalPodAutoscaler` tells Kubernetes this resource controls horizontal scaling (adding pods), not vertical scaling (changing pod resource limits).
- `scaleTargetRef` points to the Deployment named `skin-lesion-backend` in the same namespace. The HPA scales the pods in that Deployment.
- `minReplicas: 2` ensures at least 2 pods always run. Kubernetes will not scale below this even under very low load.
- `maxReplicas: 6` caps scaling at 6 pods. This prevents runaway scaling that could create unexpectedly large cloud bills.
- `metrics.resource.name: cpu` and `averageUtilization: 70` - when the average CPU across all pods exceeds 70%, the HPA adds pods to bring the average back down.

Check:

```powershell
kubectl apply -f infra/k8s/overlays/staging/hpa.yaml
kubectl get hpa -n skin-lesion-staging
```

**What these commands do:**

- `kubectl apply -f ...` creates or updates the HPA resource in the cluster.
- `kubectl get hpa -n skin-lesion-staging` shows the HPA status including current replica count, minimum, maximum, and current metric values.

Expected result:

```text
HPA exists and targets the backend Deployment.
```

Why: for EKS, scaling is a Kubernetes object, not an ECS `update_service` Lambda call.

## Step 3: Manual Rollback Command

Before automatic rollback exists, prove manual rollback.

Check rollout history:

```powershell
kubectl rollout history deployment/skin-lesion-backend -n skin-lesion-staging
```

**What this does:** lists the revision history for the Deployment. Each revision corresponds to a specific container image and pod spec. Note the revision number you want to roll back to - you will need it if you need to skip past the most recent revision.

Rollback:

```powershell
kubectl rollout undo deployment/skin-lesion-backend -n skin-lesion-staging
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
```

**What these commands do:**

- `kubectl rollout undo ...` reverts the Deployment to its previous revision. This is the most common rollback path during an incident. Add `--to-revision=N` to roll back to a specific numbered revision instead of just the previous one.
- `kubectl rollout status ...` waits for the rollback to complete and reports success or failure. Do not assume the rollback succeeded until this command exits cleanly.

Expected result:

```text
The Deployment returns to the previous ReplicaSet and /health works.
```

## Step 4: Alarm-Assisted Rollback Later

Only after manual rollback is proven, wire CloudWatch alarm notifications to a controlled rollback process.

For EKS, the safe first automation is notification plus runbook:

```text
CloudWatch alarm -> SNS -> on-call/runbook -> kubectl rollout undo
```

**What this alarm-assisted rollback flow means:**

- `CloudWatch alarm` triggers when a metric (error rate, latency, pod restart count) breaches a threshold.
- `SNS` delivers the alarm event to the on-call channel or email.
- `on-call/runbook` - a human reads the alarm, opens the linked runbook, and decides whether to roll back.
- `kubectl rollout undo` - the human runs the rollback command manually after verifying the cause.

This is safer than full automation because a human makes the rollback decision based on context the alarm metric cannot capture.

Do not start with a Lambda that mutates the cluster.

If you later build an EKS rollback Lambda, it must call the Kubernetes API or trigger a deployment controller. It must not call:

```text
ecs.describe_services
ecs.update_service
ecs.stop_task
elbv2.modify_listener for ECS target groups
```

**What these ECS API calls are:** AWS APIs that control ECS services, task counts, and ALB target groups. They have no effect on EKS workloads. Calling them from an EKS alarm handler would silently do nothing or fail.

## ECS Lambda Boundary

These deleted reference files were ECS/ALB-specific:

```text
infra/terraform/lambda/auto_heal.py
infra/terraform/lambda/auto_rollback.py
```

**What these files were:** Lambda functions that automated ECS service scaling and ALB listener rollback. They were deleted after the project moved to EKS and their behavior was documented in `09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md`.

The behavior they represented applies only to:

```text
ECS service
ALB target groups
ECS desired count
ECS forceNewDeployment
```

**What these targets mean:** the old Lambda code understood ECS constructs: services, desired task counts, and ALB target group ARNs. None of these exist in an EKS environment. EKS uses Deployment replicas, pods, and Ingress - entirely different API surfaces.

They are not valid EKS auto-heal code.

## Completion Gate

EKS auto-heal is complete only when:

```text
liveness probe restarts bad pods
readiness probe removes bad pods from traffic
HPA scales replicas under load
manual kubectl rollout undo works
CloudWatch alarm points to a documented runbook
ECS-only Lambda code is not wired to EKS alarms
```

**What this gate means:**

- `liveness probe restarts bad pods` - test this by deploying a container that crashes after 30 seconds. Kubernetes should restart it.
- `readiness probe removes bad pods from traffic` - test this by deploying a container where `/api/v1/ready` returns 503. No traffic should reach it.
- `HPA scales replicas under load` - test by generating CPU load. The replica count should increase automatically.
- `manual kubectl rollout undo works` - do this at least once in staging before any incident.
- `CloudWatch alarm points to a documented runbook` - every alarm must have a linked runbook. An alarm with no runbook is noise.
- `ECS-only Lambda code is not wired to EKS alarms` - verify no Lambda subscriptions exist on EKS-related CloudWatch alarms.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports dev environment state.
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
- `make cloud-status ENV=dev` confirms it is healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
