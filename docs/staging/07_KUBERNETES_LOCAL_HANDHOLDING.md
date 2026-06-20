# Local Kubernetes Handholding Guide

Use this after Docker works.

## Goal

Run the backend container in local Kubernetes.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root so that `kubectl` commands can reference `infra/k8s/dev/` with relative paths.

Create all Kubernetes YAML files under:

```text
infra/k8s/dev
```

**What this directory is:** the folder that holds all Kubernetes manifest files for the local dev cluster. Files created here are applied with `kubectl apply -f infra/k8s/dev/`.

Run every `kubectl` command in this guide from the repo root.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Local Kubernetes manifests: `infra/k8s/dev/`
- Create or edit every YAML file in this guide under `infra/k8s/dev/`.
- Run `kubectl` commands from the main workspace unless the step explicitly says otherwise.

## Step 1: Create Folder

Create this folder:

```text
infra/k8s/dev/
```

## Step 2: Namespace

Create `infra/k8s/dev/namespace.yaml`:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: skin-lesion-dev
```

**What this YAML does:** creates a Kubernetes namespace called `skin-lesion-dev`. A namespace is a logical partition inside the cluster - pods, services, and deployments in this namespace are isolated from other namespaces. All resources in this guide live inside `skin-lesion-dev`.

Run from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/namespace.yaml
kubectl get namespace skin-lesion-dev
```

**What these commands do:** `kubectl apply -f` reads the YAML file and creates the namespace in the cluster if it does not exist. `kubectl get namespace skin-lesion-dev` confirms the namespace was created and shows its status (should be `Active`).

## Step 3: Deployment

Create `infra/k8s/dev/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: skin-lesion-backend
  template:
    metadata:
      labels:
        app: skin-lesion-backend
    spec:
      containers:
        - name: backend
          image: skin-lesion-backend:local
          imagePullPolicy: Never
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
```

**What this YAML does:**

- `kind: Deployment` - tells Kubernetes to manage a set of identical pods and keep the desired replica count running.
- `replicas: 1` - run one pod. If it crashes, Kubernetes restarts it automatically.
- `selector.matchLabels` and `template.metadata.labels` - both must have `app: skin-lesion-backend`. The Deployment uses these labels to know which pods it owns.
- `image: skin-lesion-backend:local` - the locally built Docker image (from the Docker guide). Not pulled from a registry.
- `imagePullPolicy: Never` - tells Kubernetes not to try pulling this image from the internet. Required when using a locally built image with a local cluster (Docker Desktop, minikube, kind).
- `containerPort: 8080` - documents that the container listens on port 8080 (matches what FastAPI binds to).
- `readinessProbe` - Kubernetes polls `GET /health` on port 8080. The pod only receives traffic after this probe succeeds. Prevents traffic from reaching a pod that is still starting up.
- `livenessProbe` - Kubernetes polls the same endpoint continuously while the pod is running. If it fails repeatedly, Kubernetes kills and restarts the pod.

Run from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/deployment.yaml
kubectl get pods -n skin-lesion-dev
```

**What these commands do:** `kubectl apply -f` creates the Deployment in the `skin-lesion-dev` namespace. `kubectl get pods -n skin-lesion-dev` lists the pods in that namespace - the pod should go from `Pending` to `Running` as Kubernetes pulls the image and starts the container. If readiness fails, it stays in `0/1 Running` with the Ready column showing `0`.

## Step 4: Service

Create `infra/k8s/dev/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-dev
spec:
  selector:
    app: skin-lesion-backend
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: http
```

**What this YAML does:**

- `kind: Service` - creates a stable network name for pods so callers do not need to know individual pod IPs (which change on restart).
- `selector: app: skin-lesion-backend` - routes traffic to any pod with this label. Matches the label from the Deployment.
- `port: 8080` - the port the Service listens on. Other pods in the cluster connect to this port.
- `targetPort: 8080` - the port on the pod that traffic is forwarded to. This matches `containerPort: 8080` in the Deployment.
- `protocol: TCP` - the network protocol. HTTP runs over TCP.
- `name: http` - a name for this port. Useful when a Service exposes multiple ports.

Run from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/service.yaml
kubectl port-forward -n skin-lesion-dev service/skin-lesion-backend 8080:8080
```

**What these commands do:** `kubectl apply -f` creates the Service in the `skin-lesion-dev` namespace. `kubectl port-forward` opens a tunnel from `localhost:8080` on your machine to port 8080 on the Service inside the cluster, which then forwards to port 8080 on the pod. This is a development-only workaround - no Ingress or load balancer is needed.

In another terminal:

```powershell
curl http://localhost:8080/health
```

**What this does:** sends an HTTP GET through the port-forward tunnel to the pod's `/health` endpoint. If the pod is healthy and the Service is configured correctly, this returns `{"status":"ok"}`.

## Kubernetes Checks

```powershell
kubectl get all -n skin-lesion-dev
kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend
kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend
```

**What these commands do:**

- `kubectl get all -n skin-lesion-dev` - lists every resource in the namespace: the Deployment, ReplicaSet, Pod, and Service. Good quick-status view.
- `kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend` - prints the stdout/stderr output from the running container. Use this to see FastAPI startup messages or request logs.
- `kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend` - watches the rollout and blocks until all replicas are ready. Returns `successfully rolled out` when done, or reports a failure if pods cannot start.

Expected result:

```text
The namespace contains the backend Deployment and Service, logs are readable, and rollout status completes successfully.
```

**What this means:** all three checks pass - the namespace has the right resources, the log output is readable, and the rollout finished without error. If `rollout status` hangs or fails, check `kubectl describe pod` for image pull or probe errors.

Why: local Kubernetes proves manifests, probes, service routing, logs, and rollout behavior before paying for EKS.

## Stop Point

Only move to EKS after local Kubernetes works.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports what dev cloud resources are currently running and their cost state. `make cloud-pause ENV=dev` scales pods to zero to stop compute charges. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources - use this at the end of a work session to avoid overnight charges.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it came back healthy before you continue work.

If this guide was local-only, no cloud shutdown is needed.
