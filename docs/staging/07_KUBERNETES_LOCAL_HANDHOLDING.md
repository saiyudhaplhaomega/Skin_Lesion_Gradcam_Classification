# Local Kubernetes Verification Handholding Guide

Use this after `docs/staging/06_KUBERNETES_AFTER_DOCKER.md` completes successfully.

Guide 06 creates the local Kubernetes namespace, Deployment, and Service. This guide does **not** repeat those setup steps. It is the checkpoint that confirms the manifests are stable, local-only, and ready to adapt for ECR/EKS in guide 08.

## Goal

Prove that the local Kubernetes files created in guide 06 are complete enough to become the base for the cloud deployment path.

At the end of this guide you should know:

- the backend image exists locally
- Docker Desktop Kubernetes is running
- `infra/k8s/dev/namespace.yaml` exists and applies cleanly
- `infra/k8s/dev/deployment.yaml` uses the local image intentionally
- `infra/k8s/dev/service.yaml` routes to the backend pod
- `kubectl port-forward` can reach `GET /health`
- no AWS, ECR, EKS, Ingress, ALB, WAF, or autoscaling work has started yet

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace. Every command in this guide runs from this directory unless a step explicitly says otherwise.

The files checked or edited in this guide are:

```text
infra/k8s/dev/namespace.yaml
infra/k8s/dev/deployment.yaml
infra/k8s/dev/service.yaml
```

**What these files are:** the local Kubernetes manifests created in guide 06. They are the source of truth for the local cluster before guide 08 copies the pattern to EKS with an ECR image.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Local Kubernetes manifests: `infra/k8s/dev/`
- Backend Docker context: `Skin_Lesion_Classification_backend/`
- Do not create cloud manifests in this guide.
- Do not create `infra/k8s/staging/`, Ingress, ALB, EKS, or WAF files in this guide.

## Account And Identity Map

This guide is **local-only**.

No AWS Console access is needed. No AWS SSO login is needed. No Terraform commands are run. No ECR image is pushed.

## Prerequisites

Complete guide 06 first:

```text
docs/staging/06_KUBERNETES_AFTER_DOCKER.md
```

Guide 06 should already have created these files:

```text
infra/k8s/dev/namespace.yaml
infra/k8s/dev/deployment.yaml
infra/k8s/dev/service.yaml
```

Run from the repo root:

```powershell
Test-Path infra/k8s/dev/namespace.yaml
Test-Path infra/k8s/dev/deployment.yaml
Test-Path infra/k8s/dev/service.yaml
```

Expected result:

```text
True
True
True
```

**What this confirms:** guide 06 created the local Kubernetes files. If any value is `False`, stop and return to guide 06. Do not recreate the same files from this guide.

Why: this guide is a verification and hardening gate, not a second Kubernetes setup path. Keeping one setup guide prevents the sequence from splitting.

## Step 1: Confirm Docker And Kubernetes Are Available

Run from the repo root:

```powershell
docker version
kubectl version --client
kubectl config current-context
kubectl get nodes
```

Expected result:

```text
docker version prints both Client and Server information.
kubectl version --client prints a client version.
kubectl config current-context prints docker-desktop.
kubectl get nodes shows a Ready node.
```

**What these commands do:**

- `docker version` confirms Docker Desktop is running.
- `kubectl version --client` confirms the Kubernetes CLI is installed.
- `kubectl config current-context` confirms which cluster your commands will target.
- `kubectl get nodes` confirms the local Kubernetes control plane is reachable.

Why: if the context is not `docker-desktop`, you might accidentally apply local dev manifests to another cluster.

Do not continue until the current context is:

```text
docker-desktop
```

## Step 2: Confirm The Local Backend Image Exists

Run from the repo root:

```powershell
docker images skin-lesion-backend:local
```

Expected result:

```text
REPOSITORY            TAG     IMAGE ID       CREATED       SIZE
skin-lesion-backend   local   <image-id>     <time>        <size>
```

If the image is missing, rebuild it from the backend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
docker build -t skin-lesion-backend:local .
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

Check again:

```powershell
docker images skin-lesion-backend:local
```

**What this does:** confirms the image tag that the local Kubernetes Deployment references exists in Docker Desktop's local image cache.

Why: guide 08 will push an ECR-tagged copy later, but guide 07 should still use the local image only.

## Step 3: Harden The Deployment Manifest For Local Image Use

Open this file:

```text
infra/k8s/dev/deployment.yaml
```

Make sure it contains this exact container block:

```yaml
      containers:
        - name: skin-lesion-backend
          image: skin-lesion-backend:local
           imagePullPolicy: Never
           ports:
             - containerPort: 8080
          startupProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 0
            periodSeconds: 10
            failureThreshold: 18
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
          resources:
            requests:
              cpu: 250m
              memory: 1Gi
            limits:
              cpu: 1000m
              memory: 2Gi
```

If `imagePullPolicy: Never` is missing, add it directly under:

```yaml
          image: skin-lesion-backend:local
```

Run from the repo root:

```powershell
kubectl apply --dry-run=client -f infra/k8s/dev/deployment.yaml
```

Expected result:

```text
deployment.apps/skin-lesion-backend configured (dry run)
```

**What this does:** checks the Deployment YAML locally without changing the cluster.

Why: `imagePullPolicy: Never` makes the local intent explicit. Kubernetes should use the Docker Desktop image cache and should not try to pull `skin-lesion-backend:local` from a registry.

The memory limit is intentionally `2Gi` for local Kubernetes. The backend image includes a Python, ML, and API stack, and a `512Mi` limit can cause Kubernetes to restart the container with `OOMKilled` before `/health` is ready.

The `startupProbe` gives the backend up to 180 seconds to load its ML model before readiness and liveness checks begin. Without it, the normal model initialization period can look like a crash.

## EKS Manifest Update: ServiceAccount, Scaling, And Network Boundaries

The local `infra/k8s/dev/` manifests remain deliberately small. The EKS manifest folders now have the production-like objects that local Docker Desktop does not need:

```text
infra/k8s/eks-dev/
infra/k8s/eks-staging/
infra/k8s/eks-prod/
```

Each EKS folder includes a `serviceaccount.yaml` for `skin-lesion-backend`. The Deployment references it with `serviceAccountName: skin-lesion-backend`. Its annotation is intentionally a placeholder:

```yaml
eks.amazonaws.com/role-arn: "REPLACE_WITH_TERRAFORM_OUTPUT_dsql_workload_role_arn"
```

After Terraform applies DSQL, replace that text with the matching `terraform output dsql_workload_role_arn` value before applying the EKS manifests. Do not put the placeholder or an AWS ARN in the local `infra/k8s/dev/` Deployment.

The same EKS folders now also include these resources:

- `hpa.yaml` scales on CPU. Dev and staging allow 1 to 4 replicas, while prod allows 2 to 6.
- `pdb.yaml` keeps at least one backend pod available during a voluntary disruption.
- `networkpolicy.yaml` allows ingress from the AWS Load Balancer Controller and from pods in the same namespace, then blocks other pod ingress.

Check an EKS environment from the repo root after applying its manifests:

```powershell
kubectl get serviceaccount,hpa,pdb,networkpolicy -n skin-lesion-staging
```

Expected result: Kubernetes lists the dedicated ServiceAccount, one HPA, one PodDisruptionBudget, and one NetworkPolicy for the backend.

Why: the ServiceAccount is the narrow identity boundary for DSQL, while the other resources make rollouts, load changes, and network access safer in EKS.

## Step 4: Apply The Existing Local Manifests

Run from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/namespace.yaml
kubectl apply -f infra/k8s/dev/deployment.yaml
kubectl apply -f infra/k8s/dev/service.yaml
```

Expected result:

```text
namespace/skin-lesion-dev configured
deployment.apps/skin-lesion-backend configured
service/skin-lesion-backend configured
```

**What this does:** applies the same three local manifests created in guide 06. If the resources already exist, Kubernetes updates them in place.

Why: re-applying the existing files confirms they are idempotent. You should be able to run the command more than once without creating duplicate resources.

## Step 5: Check Namespace, Pod, Deployment, And Service

Run from the repo root:

```powershell
kubectl get namespace skin-lesion-dev
kubectl get deployment -n skin-lesion-dev skin-lesion-backend
kubectl get pods -n skin-lesion-dev -l app=skin-lesion-backend
kubectl get service -n skin-lesion-dev skin-lesion-backend
```

Expected result:

```text
The namespace is Active.
The deployment shows 1/1 ready.
The pod shows Running and Ready.
The service shows TYPE ClusterIP and PORT 8080/TCP.
```

**What these commands do:** inspect each resource by type so you can see exactly which layer is broken if something is wrong.

Why: EKS troubleshooting later uses the same mental model: namespace first, then deployment, pod, and service.

## Step 6: Confirm Rollout And Logs

Run from the repo root:

```powershell
kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend
kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend --tail=50
```

Expected result:

```text
deployment "skin-lesion-backend" successfully rolled out
```

The log command should print backend startup or request logs.

**What these commands do:**

- `kubectl rollout status` waits until the Deployment has a ready pod.
- `kubectl logs` proves you can read container logs through Kubernetes.

Why: deployment status and logs are the first two checks you will use when the same app runs in EKS.

## Step 7: Test The Service With Port Forwarding

Open **Terminal A** from the repo root:

```powershell
kubectl port-forward -n skin-lesion-dev service/skin-lesion-backend 8080:8080
```

Expected result:

```text
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

Keep Terminal A open.

Open **Terminal B** from the repo root:

```powershell
curl http://127.0.0.1:8080/health
```

Expected result:

```json
{"status":"ok"}
```

**What this does:** sends a local HTTP request through the Kubernetes Service to the backend pod.

Why: this proves the local manifest chain works from your laptop to Service to pod to FastAPI.

When the check passes, return to Terminal A and press:

```text
Ctrl+C
```

## Step 8: Record The Local-To-EKS Differences

Do not change files in this step. Read the differences below so guide 08 makes sense.

| Local guide 07 | Cloud guide 08 |
|---|---|
| Uses `skin-lesion-backend:local` | Uses an ECR image URI |
| Uses `imagePullPolicy: Never` | Pulls from ECR |
| Uses Docker Desktop context `docker-desktop` | Uses an EKS kubeconfig context |
| Uses `kubectl port-forward` | Later uses cloud networking and ingress |
| Creates no AWS resources | Creates or uses ECR and EKS resources |

Expected result:

```text
You understand which values must change before deploying to EKS.
```

Why: local Kubernetes and EKS use the same Kubernetes object model, but the image source and cluster context change.

## Final Check

Run from the repo root:

```powershell
kubectl config current-context
kubectl apply --dry-run=client -f infra/k8s/dev
kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend
curl http://127.0.0.1:8080/health
```

Important: the `curl` command only works while `kubectl port-forward` from Step 7 is still running in another terminal.

Expected result:

```text
Current context is docker-desktop.
The dry run accepts all files in infra/k8s/dev.
The rollout completes successfully.
The health endpoint returns {"status":"ok"} through the port-forward tunnel.
```

## Stop Point

Do not create EKS, Ingress, ALB, WAF, autoscaling, or cloud Kubernetes manifests until this local check passes.

Next guide:

```text
docs/staging/08_ECR_AND_EKS_HANDHOLDING.md
```

## Cleanup

If you want to remove the local Kubernetes resources after testing, run from the repo root:

```powershell
kubectl delete -f infra/k8s/dev
```

Expected result:

```text
namespace "skin-lesion-dev" deleted
deployment.apps "skin-lesion-backend" deleted
service "skin-lesion-backend" deleted
```

**What this does:** removes the local namespace, Deployment, and Service from Docker Desktop Kubernetes. It does not delete the YAML files from the repo.

Why: cleanup frees local Kubernetes resources while preserving the manifests for the next session.

## Record What Was Verified

After this guide succeeds, record the result in your notes or commit message:

```text
Guide 07 verified local Kubernetes:
- docker-desktop context
- local backend image
- namespace/deployment/service manifests
- explicit imagePullPolicy: Never
- rollout status
- pod logs
- service health through port-forward
```

## Cost Pause / Resume

This guide is **local-only**. It uses Docker Desktop's built-in Kubernetes cluster on your machine.

No AWS resources are created. No cloud shutdown is needed.

If you are done for the day:

1. Stop the port-forward terminal with `Ctrl+C`.
2. Optionally remove local Kubernetes resources:

```powershell
kubectl delete -f infra/k8s/dev
```

3. Optionally disable Kubernetes in Docker Desktop to save local memory.

Before starting guide 08, re-enable Docker Desktop Kubernetes if needed and rerun:

```powershell
kubectl config current-context
kubectl get nodes
kubectl apply -f infra/k8s/dev
kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend
```

Expected result:

```text
docker-desktop is the active context, the node is Ready, the manifests apply, and the backend deployment rolls out.
```
