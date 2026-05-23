# Docker Handholding Guide

Use this after the backend works locally.

## Goal

Run the backend inside a container.

Why: Kubernetes runs containers. Docker is the bridge between local Python and Kubernetes.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. You will then `cd` into the backend repo for the Docker build commands.

Create Docker files in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the `Dockerfile` and `.dockerignore` live inside the backend repo, not the main workspace root. They belong to the backend application.

Run Docker build and run commands from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the Docker build context is the backend repo directory. Running `docker build .` from there sends the backend's file tree to the Docker daemon.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo and Docker context: `Skin_Lesion_Classification_backend/`
- Create backend Docker files such as `Dockerfile` and `.dockerignore` under `Skin_Lesion_Classification_backend/`.
- Run `docker build` and backend container commands from `Skin_Lesion_Classification_backend/`.

## Step 1: Create Backend Dockerfile

Create in `Skin_Lesion_Classification_backend/`:

```text
Dockerfile
```

**What this file is:** the recipe Docker uses to build the container image for the backend. Every instruction adds a layer to the final image.

Paste:

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libgl1 \
        libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

EXPOSE 8080

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8080"]
```

**What each instruction does:**

- `FROM python:3.12-slim` - starts from the official Python 3.12 slim base image. `slim` removes unnecessary build tools, keeping the image smaller.
- `PYTHONDONTWRITEBYTECODE` and `PYTHONUNBUFFERED` - avoid `.pyc` files and make container logs show up immediately.
- `WORKDIR /app` - sets `/app` as the working directory inside the container. All subsequent paths are relative to this.
- `apt-get install ... libgl1 libglib2.0-0` - installs Linux runtime libraries needed by OpenCV and image-processing packages inside the slim image.
- `COPY requirements.txt .` - copies only the requirements file first. This layer is cached separately so dependency installs do not re-run when only app code changes.
- `RUN pip install --no-cache-dir -r requirements.txt` - installs dependencies. `--no-cache-dir` prevents pip from storing a download cache in the image, keeping the size down.
- `COPY app ./app` - copies the application code. This comes after the dependency install so a code change invalidates only this layer.
- `EXPOSE 8080` - documents that the container listens on port 8080. It does not actually publish the port - that is done at `docker run` time.
- `CMD ["uvicorn", "app.main:app", ...]` - the command that starts the FastAPI app when the container launches. `--host 0.0.0.0` binds to all network interfaces inside the container so it is reachable from the host.

## Step 2: Create `.dockerignore`

Create this file:

```text
Skin_Lesion_Classification_backend/.dockerignore
```

**What this file is:** the list of files and directories Docker excludes from the build context. Docker reads this before sending files to the daemon.

```text
.venv
__pycache__
.pytest_cache
*.pyc
models
mlruns
graphify-out
.git
.claude
```

**What each entry excludes:**

- `.venv` - the local virtual environment. Packages are installed inside the container from `requirements.txt`, not copied from your local venv.
- `__pycache__` and `*.pyc` - Python bytecode cache files. They are regenerated inside the container anyway.
- `.pytest_cache` - test framework cache. Not needed in production containers.
- `models` - local model weight files. The container loads models from S3 or MLflow at runtime.
- `mlruns` and `graphify-out` - local generated outputs that do not belong in the image.
- `.git` and `.claude` - repository metadata and local assistant memory that are not needed at runtime.

Why: do not copy local environments, caches, or model weights into every image.

## Step 3: Build

```powershell
cd Skin_Lesion_Classification_backend
docker build -t skin-lesion-backend:local .
```

**What this does:**

- `cd Skin_Lesion_Classification_backend` - moves into the backend repo where the `Dockerfile` lives.
- `docker build -t skin-lesion-backend:local .` - builds the image from the `Dockerfile` in the current directory (`.`). The `-t` flag tags the image as `skin-lesion-backend:local` so you can reference it by name.

Check:

```powershell
docker images skin-lesion-backend
```

**What this does:** lists Docker images whose name matches `skin-lesion-backend`. Confirms the build succeeded and shows the image size and creation time.

Expected result: Docker lists `skin-lesion-backend:local`.

Important: this image can be large because the current `requirements.txt` installs Torch, TorchVision, MLflow, OpenCV, Grad-CAM, and other ML packages. A first build can take several minutes.

## Step 4: Run

```powershell
docker run --rm -p 8080:8080 skin-lesion-backend:local
```

**What this does:**

- `docker run` - starts a container from the specified image.
- `--rm` - removes the container automatically when it stops. Keeps your local Docker environment clean.
- `-p 8080:8080` - maps port 8080 on your host machine to port 8080 inside the container. Required to reach the app from your browser or `curl`.

In another terminal:

```powershell
Invoke-RestMethod http://localhost:8080/health
```

**What this does:** sends an HTTP GET request to the health check endpoint on the running container. If the app started correctly, it returns a `200 OK` response.

Expected:

```json
{"status":"ok"}
```

**What this result means:** the FastAPI app is running inside the container and responding to HTTP requests. The health check endpoint is working correctly.

Windows PowerShell note: use `Invoke-RestMethod` or `curl.exe`, not plain `curl`. In Windows PowerShell, `curl` can be an alias for `Invoke-WebRequest` and may fail with an Internet Explorer parsing error.

## Stop Point

Do not start Kubernetes until this works.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of dev cloud resources.
- `make cloud-pause ENV=dev` scales pods to zero to reduce cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` creates or resumes the dev environment.
- `make cloud-status ENV=dev` confirms the environment is healthy.

If this guide was local-only, no cloud shutdown is needed.
