# Kubernetes After Docker

Do not start Kubernetes until the backend Docker image runs locally.

## Clean State Setup

This guide starts from a clean state. Each prerequisite below is **verified first**, then **rebuilt only if missing**. Running this section is safe even if everything is already built — each check is idempotent.

You will use **two PowerShell terminals** in this section:

- **Terminal A** (Docker terminal) — runs from `Skin_Lesion_Classification_backend/` for Docker build and run commands.
- **Terminal B** (Kubernetes terminal) — runs from the repo root for `kubectl` commands and health checks.

Keep both terminals open through Step 4.

### Check 1: Backend Dockerfile Exists

The backend `Dockerfile` was created in guide 01. Verify it is present:

```powershell
Test-Path C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend\Dockerfile
```

**What this does:** returns `True` if the file exists, `False` if it is missing.

Expected result:

```text
True
```

If the result is `False`, go back to guide 01 (`docs/staging/01_DOCKER_HANDHOLDING.md`) Step 1 and create the `Dockerfile`. Do not continue until this check returns `True`.

### Check 2: Backend `.dockerignore` Exists

The backend `.dockerignore` was created in guide 01. Verify it is present:

```powershell
Test-Path C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend\.dockerignore
```

Expected result:

```text
True
```

If the result is `False`, go back to guide 01 Step 2 and create `.dockerignore`. Do not continue until this check returns `True`.

### Check 3: Docker Desktop Is Running

```powershell
docker version
```

**What this does:** asks the Docker CLI and Docker engine for their versions. The CLI can be installed even when the Docker engine is stopped, so this check confirms both pieces are ready.

Expected result:

```text
Client version prints.
Server version prints.
```

If you see only the client version and then a connection error:

```text
failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine
```

Docker Desktop is installed but not running. Open Docker Desktop from the Start menu, wait until it says the engine is running, then rerun `docker version`. Do not continue until both client and server versions print.

### Check 4: Docker Image `skin-lesion-backend:local` Exists

```powershell
docker images skin-lesion-backend:local
```

**What this does:** lists Docker images whose name matches `skin-lesion-backend`. Confirms the image was built (in guide 01) and is available for Kubernetes to use.

Expected result:

```text
IMAGE                       ID             DISK USAGE   CONTENT SIZE
skin-lesion-backend:local   <hash>         <size>       <size>
```

If the image does **not** appear, build it now in **Terminal A**:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
docker build -t skin-lesion-backend:local .
```

**What this does:** builds the image from the `Dockerfile` in the current directory and tags it as `skin-lesion-backend:local`. If the image already exists, Docker rebuilds only the layers that changed since the last build, so this is fast on a re-run. The first build can take several minutes because Torch, TorchVision, MLflow, OpenCV, and Grad-CAM are large. On this Windows workspace the image is about 10.8 GB.

Wait for the build to finish, then rerun `docker images skin-lesion-backend:local` and confirm the image appears. Do not continue until this check passes.

### Check 5: No Container Is Already Using Port 8080

Kubernetes will eventually bind port 8080 through `kubectl port-forward`. If a Docker container from a previous run is still holding port 8080, the port-forward will fail.

```powershell
docker ps --filter ancestor=skin-lesion-backend:local
```

**What this does:** lists currently running containers using the `skin-lesion-backend:local` image.

Expected result (good state — no container is running):

```text
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS   PORTS     NAMES
```

**What this means:** the column headers print but the table is empty. Port 8080 is free.

If the table shows a running container, stop it before continuing:

```powershell
docker stop $(docker ps -q --filter ancestor=skin-lesion-backend:local)
```

**What this does:** stops and removes the running container so port 8080 becomes free. Rerun `docker ps --filter ancestor=skin-lesion-backend:local` and confirm the table is empty. Do not continue until this check passes.

### Check 6: Docker Container Runs And Health Endpoint Responds

In **Terminal A**, start the container:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
docker run --rm -p 8080:8080 skin-lesion-backend:local
```

**What this does:** starts a container from the `skin-lesion-backend:local` image. `--rm` removes the container automatically when it stops. `-p 8080:8080` maps port 8080 on your machine to port 8080 inside the container.

Expected startup output (do not close Terminal A — the container is running):

```text
INFO:     Started server process [1]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8080 (Press CTRL+C to quit)
```

In **Terminal B**, test the health endpoint:

```powershell
curl http://localhost:8080/health
```

Expected result:

```json
{"status":"ok"}
```

**What this result means:** the FastAPI app is running inside the container and responding. The backend's health endpoint is defined at `Skin_Lesion_Classification_backend/app/main.py:34` as `@app.get("/health")`.

If you see `Connection refused` or `Empty reply from server`:
1. Wait 10 seconds — the first request after startup can be slow because the FastAPI app is still warming up.
2. Check Terminal A — the `Application startup complete` line should appear before the curl will succeed.
3. If the container exits immediately, scroll up in Terminal A and read the error message. Common issues: port 8080 already in use, image is corrupt, or missing dependency.

If the health endpoint returns `404 Not Found`, you are hitting an older backend image. Rebuild with `docker build -t skin-lesion-backend:local . --no-cache` in Terminal A and retest.

If curl works, leave the container running in Terminal A. You will stop it later in this guide before running `kubectl port-forward` (because both processes need port 8080).

### Check 7: `kubectl` Is Installed

In **Terminal B**:

```powershell
kubectl version --client
```

Expected result:

```text
Client Version: v1.XX.X
Kustomize Version: vX.X.X
```

If `kubectl` is not found:

```powershell
choco install kubernetes-cli -y
```

**What this does:** installs the Kubernetes CLI into Chocolatey's system package location and puts `kubectl` on `PATH`. Requires an Administrator terminal for first-time install.

Do not continue until `kubectl version --client` prints a version.

### Check 8: Docker Desktop Kubernetes Is Enabled

In **Terminal B**:

```powershell
kubectl config current-context
```

Expected result:

```text
docker-desktop
```

If you see `docker-desktop`, Kubernetes is running inside Docker Desktop and you are ready to continue.

If you see an error or a different context, enable Kubernetes in Docker Desktop:

1. Open Docker Desktop.
2. Click the **gear icon** (Settings) in the top-right corner.
3. In the left sidebar, click `Kubernetes`.
4. Check the box next to `Enable Kubernetes`.
5. Click `Apply & Restart`.
6. Wait for Docker Desktop to restart and for the Kubernetes icon in the bottom-left corner to turn green.
7. Rerun `kubectl config current-context` and confirm it says `docker-desktop`.

### Check 9: Kubernetes Control Plane Node Is Ready

In **Terminal B**:

```powershell
kubectl get nodes
```

Expected result:

```text
NAME                    STATUS   ROLES           AGE    VERSION
desktop-control-plane   Ready    control-plane   XXm    v1.XX.X
```

**What the columns mean:**

- `NAME` - the Kubernetes node. With Docker Desktop, there is always exactly one node named `desktop-control-plane`.
- `STATUS` - `Ready` means the node is healthy and can run pods. `NotReady` means Docker Desktop Kubernetes is still starting or has a problem.
- `ROLES` - `control-plane` means this node runs the Kubernetes control plane (the API server, scheduler, etc.). With Docker Desktop this is the only role.
- `AGE` - how long ago the node was created.
- `VERSION` - the Kubernetes version (for example `v1.34.3`).

If `STATUS` is `NotReady`, wait 30 seconds and rerun. If it is still `NotReady` after a minute, restart Kubernetes in Docker Desktop: Settings → Kubernetes → `Apply & Restart`. Do not continue until `STATUS` is `Ready`.

### What You Should Have Now

After all 9 checks pass:

| Resource | State | Where |
|----------|-------|-------|
| `Skin_Lesion_Classification_backend/Dockerfile` | exists | verified in Check 1 |
| `Skin_Lesion_Classification_backend/.dockerignore` | exists | verified in Check 2 |
| Docker Desktop | running | verified in Check 3 |
| Docker image `skin-lesion-backend:local` | exists | verified in Check 4 |
| Port 8080 | free before container start, then held by the container from Check 6 | verified in Check 5, then claimed by Check 6 |
| Docker container running `skin-lesion-backend:local` | running in Terminal A, mapped to port 8080 | started in Check 6 |
| `curl http://localhost:8080/health` | returns `{"status":"ok"}` | verified in Check 6 Terminal B |
| `kubectl` | installed | verified in Check 7 |
| Docker Desktop Kubernetes | enabled, context is `docker-desktop` | verified in Check 8 |
| Kubernetes control plane node | `Ready` | verified in Check 9 |

If any check fails, fix that one item and rerun only the failed check. Do not move to the steps below until all 9 checks pass.

Note: this section does **not** create the `infra/k8s/` directory. Step 1 below creates it fresh.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Docker commands run from the backend repo; `kubectl` commands run from the repo root where `infra/k8s/` lives.

Docker build commands run from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the Docker build context is the backend repo directory. Run `cd Skin_Lesion_Classification_backend` before `docker build`.

Kubernetes file creation and `kubectl apply -f infra/k8s/dev` commands run from the repo root.

## Repo And File Map

Main workspace:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

Every file this guide creates, in the order the steps create them:

| Step | Action | Full file path | What goes in it |
|------|--------|---------------|-----------------|
| 1 | Create new file | `infra/k8s/dev/namespace.yaml` | 1 `Namespace` manifest named `skin-lesion-dev` |
| 2 | Create new file | `infra/k8s/dev/deployment.yaml` | 1 `Deployment` manifest that runs the `skin-lesion-backend:local` image with 1 replica |
| 3 | Create new file | `infra/k8s/dev/service.yaml` | 1 `Service` manifest that exposes the deployment on port 8080 |

Files this guide does **not** touch:

```text
Skin_Lesion_Classification_backend/Dockerfile  — created in guide 01, do not modify
infra/terraform/                                — created in guides 02-05, do not modify
```

Do not create Ingress, ALB, WAF, autoscaling, or EKS manifests in this guide.

## Account And Identity Map

This guide is **local-only**. No AWS Console access is needed. No SSO login is needed. No Terraform commands are run.

```text
ENTER: Local terminal (no AWS account needed)
```

You stay in the local terminal for the entire guide.

## Why

Kubernetes runs containers. If your container does not work, Kubernetes will only show pod errors. That is why the Docker guide comes first — you confirmed the container starts and responds before wrapping it in Kubernetes.

## Goal

Run the backend container in a local Kubernetes cluster (Docker Desktop) before moving to cloud Kubernetes (EKS). Learn the three baseline Kubernetes manifests: namespace, deployment, and service.

## Step 1: Create The Namespace

Create this file:

```text
infra/k8s/dev/namespace.yaml
```

**How to create this file in VS Code:**

1. Open VS Code.
2. If the workspace is not already open, click `File` > `Open Folder` and select:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
   ```
3. In the VS Code Explorer panel on the left, expand the `infra` folder.
4. Right-click the `infra` folder.
5. Click `New Folder...`.
6. Type exactly:
   ```text
   k8s
   ```
7. Press `Enter`.
8. Right-click the `k8s` folder.
9. Click `New Folder...`.
10. Type exactly:
   ```text
   dev
   ```
11. Press `Enter`.
12. Right-click the `dev` folder.
13. Click `New File...`.
14. Type exactly:
   ```text
   namespace.yaml
   ```
15. Press `Enter`. VS Code creates the file and opens it in the editor tab. The file is empty.
16. Copy the YAML block below and paste it into the `namespace.yaml` editor tab.
17. Press `Ctrl+S` to save the file.

**What to paste into the file:**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: skin-lesion-dev
  labels:
    app: skin-lesion-backend
    environment: dev
```

**What each line does:**

- `apiVersion: v1` - the Kubernetes API version for Namespace resources. Namespaces are a core Kubernetes resource, so they use the stable `v1` API.
- `kind: Namespace` - tells Kubernetes this manifest defines a Namespace, not a Deployment or Service.
- `metadata.name: skin-lesion-dev` - the name of the namespace. All resources in this guide are created inside this namespace so they are isolated from other apps running in the same cluster.
- `metadata.labels` - attaches `app` and `environment` labels so you can filter resources with `kubectl get pods -l app=skin-lesion-backend`.

**How to create this file in a plain text editor (Notepad):**

1. Open Notepad.
2. Copy the YAML block above and paste it into Notepad.
3. Click `File` > `Save As`.
4. Navigate to:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra
   ```
5. Create the `k8s` folder and inside it the `dev` folder if they do not exist.
6. In the `Save as type` dropdown, choose `All Files (*.*)`.
7. In the `File name` field, type exactly:
   ```text
   namespace.yaml
   ```
8. Click `Save`.

Check from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/namespace.yaml
```

**What this does:** creates the `skin-lesion-dev` namespace in the local Kubernetes cluster.

Expected result:

```text
namespace/skin-lesion-dev created
```

If you see `namespace/skin-lesion-dev configured` instead of `created`, the namespace already existed from a previous run. This is fine.

Verify:

```powershell
kubectl get namespaces
```

**What this does:** lists all namespaces in the cluster.

Expected result (you should see `skin-lesion-dev` in the list):

```text
NAME              STATUS   AGE
default           Active   XXm
docker-desktop    Active   XXm
kube-system       Active   XXm
skin-lesion-dev   Active   XXs
```

## Step 2: Create The Deployment

Create this file:

```text
infra/k8s/dev/deployment.yaml
```

**How to create this file in VS Code:**

1. In the VS Code Explorer panel, right-click the `dev` folder inside `infra/k8s/`.
2. Click `New File...`.
3. Type exactly:
   ```text
   deployment.yaml
   ```
4. Press `Enter`. The file opens empty.
5. Copy the YAML block below and paste it into the editor tab.
6. Press `Ctrl+S` to save the file.

**What to paste into the file:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-dev
  labels:
    app: skin-lesion-backend
    environment: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: skin-lesion-backend
  template:
    metadata:
      labels:
        app: skin-lesion-backend
        environment: dev
    spec:
      containers:
        - name: skin-lesion-backend
          image: skin-lesion-backend:local
          ports:
            - containerPort: 8080
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
              cpu: 100m
              memory: 256Mi
            limits:
              cpu: 500m
              memory: 512Mi
```

**What each section does:**

- `apiVersion: apps/v1` - the Kubernetes API version for Deployment resources. Deployments use the `apps/v1` API because they are part of the workload management group.
- `kind: Deployment` - tells Kubernetes this manifest defines a Deployment, which manages one or more identical pods.
- `metadata.namespace: skin-lesion-dev` - places this Deployment inside the namespace created in Step 1. Resources in different namespaces are isolated from each other.
- `metadata.name: skin-lesion-backend` - the name of the Deployment. This name appears in `kubectl get deployments -n skin-lesion-dev`.
- `spec.replicas: 1` - tells Kubernetes to run exactly 1 pod. For local learning, 1 replica is enough. Production guides cover scaling.
- `spec.selector.matchLabels.app: skin-lesion-backend` - tells the Deployment which pods it owns. The Deployment manages pods that have the label `app: skin-lesion-backend`. This label must match `spec.template.metadata.labels.app` below.
- `spec.template.metadata.labels` - labels applied to every pod this Deployment creates. The `app` label must match the selector above so the Deployment can find its own pods.
- `spec.template.spec.containers` - the container definition:
  - `name: skin-lesion-backend` - the container name inside the pod.
  - `image: skin-lesion-backend:local` - the Docker image built in guide 01. The `:local` tag matches the tag you used in `docker build -t skin-lesion-backend:local .`. Kubernetes pulls this image from the local Docker Desktop image cache, not from a remote registry.
  - `ports.containerPort: 8080` - the port the FastAPI app listens on inside the container. This matches the port in the Dockerfile (`EXPOSE 8080`) and the `uvicorn` command.
  - `readinessProbe` - Kubernetes checks `/health` every 10 seconds. The pod is marked "ready" only when this endpoint returns HTTP 200. Kubernetes routes traffic to the pod only when it is ready. `initialDelaySeconds: 5` gives the app 5 seconds to start before the first probe.
  - `livenessProbe` - Kubernetes checks `/health` every 20 seconds. If this endpoint fails, Kubernetes restarts the pod. `initialDelaySeconds: 15` gives the app more time before liveness checks start, so a slow startup does not trigger a premature restart.
  - `resources.requests` - the minimum CPU and memory Kubernetes reserves for this pod. `100m` means 0.1 CPU core. `256Mi` means 256 megabytes.
  - `resources.limits` - the maximum CPU and memory this pod can use. If the pod exceeds these limits, Kubernetes may throttle or restart it.

**Why the readiness and liveness probes use `/health`:** the backend's FastAPI app exposes the health endpoint at `/health` (defined at `Skin_Lesion_Classification_backend/app/main.py:34` as `@app.get("/health")`). You confirmed this earlier with `curl http://localhost:8080/health` returning `{"status":"ok"}`. If the probe path is wrong, Kubernetes marks the pod as unhealthy and keeps restarting it.

Check from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/deployment.yaml
```

**What this does:** creates the Deployment in the `skin-lesion-dev` namespace. Kubernetes starts pulling the image and creating the pod.

Expected result:

```text
deployment.apps/skin-lesion-backend created
```

Verify the pod is running:

```powershell
kubectl get pods -n skin-lesion-dev
```

**What this does:** lists all pods in the `skin-lesion-dev` namespace.

Expected result:

```text
NAME                                   READY   STATUS    RESTARTS   AGE
skin-lesion-backend-XXXXX-XXXXX        1/1     Running   0          XXs
```

**What the columns mean:**

- `NAME` - the pod name. Kubernetes generates this from the Deployment name plus a random suffix.
- `READY` - `1/1` means 1 of 1 containers in the pod is ready. If you see `0/1`, the pod is still starting or the readiness probe has not passed yet. Wait 15 seconds and check again.
- `STATUS` - `Running` means the container is running. If you see `ImagePullBackOff`, Kubernetes cannot find the `skin-lesion-backend:local` image — confirm Docker Desktop is running and the image exists with `docker images | grep skin-lesion-backend`.
- `RESTARTS` - the number of times Kubernetes restarted this pod. `0` is normal. If this keeps increasing, the liveness probe is failing — check the pod logs with `kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend`.
- `AGE` - how long ago the pod was created.

If the pod is not running, check its logs:

```powershell
kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend
```

**What this does:** prints the container's stdout output. If the FastAPI app failed to start, the error message appears here.

## Step 3: Create The Service

Create this file:

```text
infra/k8s/dev/service.yaml
```

**How to create this file in VS Code:**

1. In the VS Code Explorer panel, right-click the `dev` folder inside `infra/k8s/`.
2. Click `New File...`.
3. Type exactly:
   ```text
   service.yaml
   ```
4. Press `Enter`. The file opens empty.
5. Copy the YAML block below and paste it into the editor tab.
6. Press `Ctrl+S` to save the file.

**What to paste into the file:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: skin-lesion-backend
  namespace: skin-lesion-dev
  labels:
    app: skin-lesion-backend
    environment: dev
spec:
  type: ClusterIP
  selector:
    app: skin-lesion-backend
  ports:
    - port: 8080
      targetPort: 8080
      protocol: TCP
      name: http
```

**What each section does:**

- `apiVersion: v1` - the Kubernetes API version for Service resources. Services are a core Kubernetes resource.
- `kind: Service` - tells Kubernetes this manifest defines a Service, which gives pods a stable network name.
- `metadata.namespace: skin-lesion-dev` - places this Service inside the same namespace as the Deployment.
- `metadata.name: skin-lesion-backend` - the name of the Service. Other pods in the cluster can reach the backend at `http://skin-lesion-backend.skin-lesion-dev.svc.cluster.local:8080`.
- `spec.type: ClusterIP` - creates an internal-only IP address for the Service. This means the Service is reachable from inside the cluster but not from outside. You will use `kubectl port-forward` to reach it from your machine.
- `spec.selector.app: skin-lesion-backend` - tells the Service which pods to route traffic to. This must match the `app` label on the Deployment's pod template. The Service finds pods with the label `app: skin-lesion-backend` and forwards traffic to them.
- `spec.ports.port: 8080` - the port the Service listens on. Other pods in the cluster connect to this port.
- `spec.ports.targetPort: 8080` - the port on the pod that traffic is forwarded to. This matches `containerPort: 8080` in the Deployment.
- `spec.ports.protocol: TCP` - the network protocol. HTTP runs over TCP.
- `spec.ports.name: http` - a name for this port. Useful when a Service exposes multiple ports.

**Why `port` and `targetPort` are both 8080:** the container listens on 8080 (matching the Dockerfile and uvicorn command). The Service also exposes 8080. There is no port translation needed. In production, you might have the Service listen on 80 and forward to a different container port, but for local learning, keeping them the same is simpler.

Check from the repo root:

```powershell
kubectl apply -f infra/k8s/dev/service.yaml
```

**What this does:** creates the Service in the `skin-lesion-dev` namespace.

Expected result:

```text
service/skin-lesion-backend created
```

Verify:

```powershell
kubectl get services -n skin-lesion-dev
```

**What this does:** lists all services in the `skin-lesion-dev` namespace.

Expected result:

```text
NAME                  TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
skin-lesion-backend   ClusterIP   10.96.XXX.XXX   <none>        8080/TCP   XXs
```

**What the columns mean:**

- `TYPE` - `ClusterIP` means the Service is internal to the cluster.
- `CLUSTER-IP` - the internal IP address Kubernetes assigned to the Service. This IP is reachable from inside the cluster only.
- `EXTERNAL-IP` - `<none>` because this is a ClusterIP Service, not a LoadBalancer. You will use port-forwarding to reach it from your machine.
- `PORT(S)` - `8080/TCP` confirms the Service is listening on port 8080 using TCP.

## Step 4: Test The Pod Through The Service

Now that the namespace, deployment, and service all exist, test that you can reach the backend pod through the Service.

Run from the repo root:

```powershell
kubectl port-forward service/skin-lesion-backend -n skin-lesion-dev 8080:8080
```

**What this does:** creates a tunnel from `localhost:8080` on your machine to port 8080 of the `skin-lesion-backend` Service inside the `skin-lesion-dev` namespace. The terminal stays open while the tunnel is active.

Expected result:

```text
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080
```

**Important:** this terminal must stay open. Open a **second** PowerShell terminal for the next command. Do not close the first terminal.

In the second terminal, run:

```powershell
curl http://localhost:8080/health
```

**What this does:** sends an HTTP GET to the health endpoint through the port-forward tunnel. The request goes from your machine to the Service, which routes it to the pod.

Expected result:

```json
{"status":"ok"}
```

**What this result means:** the request traveled from your machine through the port-forward tunnel, hit the Service, was routed to the pod, and the FastAPI app responded with a healthy status. The full Kubernetes pod-to-service flow works.

If you see `Connection refused` or `curl: (52) Empty reply`:

1. Go back to the first terminal and check the port-forward is still running.
2. Verify the pod is running: `kubectl get pods -n skin-lesion-dev` — the pod should show `1/1 Running`.
3. If the pod is not ready, check its logs: `kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend`.
4. If port 8080 is already in use (from the Docker container running earlier), stop the Docker container first: `docker stop $(docker ps -q --filter ancestor=skin-lesion-backend:local)` — then retry the port-forward.

**Why you might need to stop the Docker container:** if you ran `docker run --rm -p 8080:8080 skin-lesion-backend:local` earlier (from guide 01), that container is still holding port 8080 on your machine. The `kubectl port-forward` command also needs port 8080. Only one process can listen on a given port at a time. Stop the Docker container, then retry the port-forward.

To stop the Docker container, run in a terminal:

```powershell
docker ps --filter ancestor=skin-lesion-backend:local
```

**What this does:** lists the running container using the `skin-lesion-backend:local` image.

Then stop it:

```powershell
docker stop <CONTAINER_ID from the previous command output>
```

Or stop all containers from that image:

```powershell
docker stop $(docker ps -q --filter ancestor=skin-lesion-backend:local)
```

Then retry the port-forward in the first terminal and the curl in the second terminal.

## Step 5: Apply All Manifests At Once

Now that each file works individually, apply all three at once to learn the batch command.

First, clean up the individual resources you just created:

```powershell
kubectl delete -f infra/k8s/dev/service.yaml
kubectl delete -f infra/k8s/dev/deployment.yaml
kubectl delete -f infra/k8s/dev/namespace.yaml
```

**What this does:** deletes the Service, Deployment, and Namespace in reverse order. The namespace deletion also deletes everything inside it (the Deployment and its pods).

Expected result:

```text
service "skin-lesion-backend" deleted
deployment.apps "skin-lesion-backend" deleted
namespace "skin-lesion-dev" deleted
```

Now apply the entire directory at once:

```powershell
kubectl apply -f infra/k8s/dev
```

**What this does:** applies all YAML files in the `infra/k8s/dev/` directory. Kubernetes creates the namespace, deployment, and service in the correct order (namespace first, then deployment, then service).

Expected result:

```text
namespace/skin-lesion-dev created
deployment.apps/skin-lesion-backend created
service/skin-lesion-backend created
```

Verify everything is running:

```powershell
kubectl get all -n skin-lesion-dev
```

**What this does:** lists all resources (pods, services, deployments) in the `skin-lesion-dev` namespace.

Expected result:

```text
NAME                                       READY   STATUS    RESTARTS   AGE
pod/skin-lesion-backend-XXXXX-XXXXX        1/1     Running   0          XXs

NAME                                  READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/skin-lesion-backend   1/1     1            1           XXs

NAME                          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
service/skin-lesion-backend    ClusterIP   10.96.XXX.XXX   <none>        8080/TCP   XXs
```

Test the health endpoint again through port-forward:

```powershell
kubectl port-forward service/skin-lesion-backend -n skin-lesion-dev 8080:8080
```

In a second terminal:

```powershell
curl http://localhost:8080/health
```

Expected result:

```json
{"status":"ok"}
```

## Stop Point

Do not create Ingress, ALB, WAF, autoscaling, or EKS until this basic pod/service flow works.

Next guide:

```text
docs/staging/07_KUBERNETES_LOCAL_HANDHOLDING.md
```

## Cleanup

When you are done with this guide and want to remove the Kubernetes resources from your local cluster:

```powershell
kubectl delete -f infra/k8s/dev
```

**What this does:** deletes the namespace, deployment, and service. The namespace deletion also removes all resources inside it.

Expected result:

```text
namespace "skin-lesion-dev" deleted
deployment.apps "skin-lesion-backend" deleted
service "skin-lesion-backend" deleted
```

Verify cleanup:

```powershell
kubectl get all -n skin-lesion-dev
```

Expected result:

```text
No resources found in skin-lesion-dev namespace.
```

If the namespace is stuck in `Terminating` status, wait 30 seconds and check again. Kubernetes finalizers sometimes take a moment to complete.

## Record What Was Created

After this guide succeeds, these Kubernetes manifests exist in the repo:

```text
infra/k8s/dev/namespace.yaml    - Namespace: skin-lesion-dev
infra/k8s/dev/deployment.yaml   - Deployment: skin-lesion-backend (1 replica, port 8080)
infra/k8s/dev/service.yaml      - Service: skin-lesion-backend (ClusterIP, port 8080)
```

The Docker image `skin-lesion-backend:local` is used by the Deployment. It was built in guide 01 and is stored in the local Docker Desktop image cache.

## Cost Pause / Resume

This guide is **local-only**. It uses Docker Desktop's built-in Kubernetes cluster, which runs on your machine. No AWS resources are created. No cloud shutdown is needed.

If you are done for the day, stop the port-forward tunnel by pressing `Ctrl+C` in the terminal where it is running. Clean up the Kubernetes resources with:

```powershell
kubectl delete -f infra/k8s/dev
```

You can also disable Kubernetes in Docker Desktop to save memory:
1. Open Docker Desktop.
2. Click the **gear icon** (Settings).
3. Click `Kubernetes` in the left sidebar.
4. Uncheck `Enable Kubernetes`.
5. Click `Apply & Restart`.

Re-enable it the same way when you need Kubernetes again.