# Docker Compose Handholding Guide

Use this after the backend, frontend, and local database guides work separately.

Docker Compose is the bridge between local commands and staging-style containers. It is not Kubernetes and it is not cloud deployment.

## Goal

Run local services together:

```text
backend container
frontend dev server or frontend container
PostgreSQL container
```

What these services mean: Compose will eventually run the API, frontend, and database together on your machine so you can test service-to-service behavior.

Start small. Add only one service at a time and check it before adding the next.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this does: moves your terminal to the main workspace where the `infra/compose/` folder belongs.

Create Docker Compose files in:

```text
infra/compose
```

What this path means: Compose is infrastructure coordination, so it lives under `infra/` instead of inside only the backend or frontend repo.

Run every command in this guide from the main workspace.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Compose files: `infra/compose/` under the main workspace.
- Backend Docker context: `Skin_Lesion_Classification_backend/`.
- Frontend Docker context, when added later: `Skin_Lesion_Classification_frontend/`.
- Run `docker compose -f infra/compose/...` commands from the main workspace unless a step explicitly changes directory.

## Step 1: Create The Compose Folder

Create:

```text
infra/compose/
```

What this creates: the folder that will hold local Compose files.

Check:

```powershell
Test-Path infra/compose
```

What this checks: confirms the folder exists.

Expected result:

```text
True
```

**What this confirms:** the `infra/compose` folder was created successfully and is visible to PowerShell.

Why: Compose belongs under `infra/` because it coordinates multiple repos.

## Step 2: Add PostgreSQL Only

Create:

```text
infra/compose/docker-compose.local.yml
```

**What this path is:** the local Compose file. It lives under `infra/compose/` instead of inside a single repo because it coordinates the backend, database, and cache together.

Paste:

```yaml
services:
  postgres:
    image: postgres:16
    container_name: skin-lesion-postgres-local
    environment:
      POSTGRES_DB: skin_lesion
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    volumes:
      - skin_lesion_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d skin_lesion"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  skin_lesion_postgres_data:
```

What this Compose file does:

- Defines one `postgres` service using the official Postgres 16 image.
- Sets local database name, username, and password.
- Maps host port `5432` to container port `5432`.
- Stores database files in a named Docker volume.
- Adds a healthcheck so other services can wait until Postgres is ready.

Run:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up postgres
```

What this does: starts only the Postgres service from the local Compose file.

In a second terminal:

```powershell
docker ps --filter "name=skin-lesion-postgres-local"
```

What this checks: lists the running container with the expected local Postgres name.

Expected result:

```text
Postgres container is running and healthy.
```

**What this confirms:** the Postgres container started and its healthcheck passed - `pg_isready` is returning success inside the container.

Why: database state must work before backend container orchestration matters.

## Step 3: Add Redis

Redis is required for the activation cache (prevents sticky-session footguns when ECS runs more than one task).
Add it before the backend so the backend can depend on it.

Extend `infra/compose/docker-compose.local.yml`:

Paste this `redis:` block under the top-level `services:` section, aligned with `postgres:`. Do not paste it under the top-level `volumes:` section.

```yaml
  redis:
    image: redis:7-alpine
    container_name: skin-lesion-redis-local
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru --requirepass redislocal
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redislocal", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
```

What this Redis service does:

- Uses a lightweight Redis image.
- Caps memory at `256mb`.
- Uses `allkeys-lru` eviction for volatile cache behavior.
- Requires the local password `redislocal`.
- Adds a healthcheck based on `redis-cli ping`.

Test Redis is up:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up postgres redis -d
docker exec skin-lesion-redis-local redis-cli -a redislocal ping
```

What this does:

- Starts Postgres and Redis in the background.
- Executes `redis-cli ping` inside the Redis container.

Expected:

```text
PONG
```

**What this confirms:** Redis is running inside the container and accepting authenticated commands.

Why `--maxmemory-policy allkeys-lru`: the activation cache is volatile. LRU eviction is correct here.
Why 256 MB cap: enough for ~200 concurrent CAM activations at ~1 MB each. Tune up if you see evictions.

## Step 4: Create an env_file For Compose

Create `infra/compose/.env.local`:

```text
POSTGRES_DB=skin_lesion
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
DATABASE_URL=postgresql+psycopg://postgres:postgres@postgres:5432/skin_lesion
REDIS_URL=redis://:redislocal@redis:6379/0
ENVIRONMENT=local
```

What this env file does:

- Stores local database credentials for Compose.
- Uses `postgres` and `redis` as hostnames because containers talk by service name.
- Keeps local environment values out of the YAML service definitions.

Add to `.gitignore` (or `infra/compose/.gitignore`):

```text
.env.local
.env.staging
.env.prod
```

What this ignore rule does: prevents local, staging, and production environment files from being committed.

## Step 5: Add Backend Container

This step has two file locations:

```text
Skin_Lesion_Classification_backend/
infra/compose/
```

What this means: the backend Docker files go inside the backend repo because they describe how to package the FastAPI app. The Compose file stays in `infra/compose/` because it coordinates Postgres, Redis, and the backend together.

Do not run the backend Compose command until:

```text
Skin_Lesion_Classification_backend/Dockerfile exists
Skin_Lesion_Classification_backend/.dockerignore exists
the local image skin-lesion-backend:local exists
infra/compose/docker-compose.local.yml contains the backend service block
```

### Step 5A: Create Backend Docker Files

First, check whether the backend Docker files exist:

```powershell
Test-Path Skin_Lesion_Classification_backend\Dockerfile
Test-Path Skin_Lesion_Classification_backend\.dockerignore
```

Expected result:

```text
True
True
```

If either command returns `False`, create the backend Docker files before running `docker build`.

Create or edit:

```text
Skin_Lesion_Classification_backend/Dockerfile
```

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

What this Dockerfile does:

- Uses Python 3.12 slim as the backend runtime.
- Installs the small Linux libraries needed by OpenCV and image-processing imports.
- Installs Python dependencies from `requirements.txt`.
- Copies the FastAPI app into the image.
- Starts Uvicorn on container port `8080`.

Create:

```text
Skin_Lesion_Classification_backend/.dockerignore
```

Paste:

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

What this ignore file does: keeps local virtual environments, caches, model weights, Git metadata, and generated graph files out of the Docker build context.

Check from the main workspace:

```powershell
Test-Path Skin_Lesion_Classification_backend\Dockerfile
Test-Path Skin_Lesion_Classification_backend\.dockerignore
```

Expected result:

```text
True
True
```

### Step 5B: Build The Backend Image

Build the backend image from the backend repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
docker build -t skin-lesion-backend:local .
docker images skin-lesion-backend
```

Expected result: Docker lists an image named `skin-lesion-backend` with tag `local`.

Important: this image can be large because the current `requirements.txt` installs Torch, TorchVision, MLflow, OpenCV, Grad-CAM, and other ML packages. A first build can take several minutes.

Then return to the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

If you see this error:

```text
pull access denied for skin-lesion-backend, repository does not exist or may require 'docker login'
```

it usually means you have not built the local backend image yet. Docker Compose looked for `skin-lesion-backend:local` on your machine, did not find it, and then tried to pull it from Docker Hub as if it were a public image.

### Step 5C: Add The Backend Service To Compose

Extend `infra/compose/docker-compose.local.yml` with an `env_file` reference instead of inline env:

```yaml
  backend:
    image: skin-lesion-backend:local
    container_name: skin-lesion-backend-local
    env_file:
      - .env.local
    ports:
      - "8000:8080"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
```

What this backend service does:

- Runs the previously built backend image.
- Loads environment variables from `.env.local`.
- Maps local port `8000` to container port `8080`.
- Waits for healthy Postgres and Redis before starting.

Check the Compose file shape:

```powershell
docker compose -f infra/compose/docker-compose.local.yml config
```

Expected result: the output includes `postgres`, `redis`, and `backend` under `services`. It must not report YAML validation errors.

### Step 5D: Run Backend Through Compose

Run:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up postgres redis backend -d
```

What this does: starts the database, cache, and backend services in the background.

In a second terminal:

```powershell
Invoke-RestMethod http://localhost:8000/health
Invoke-RestMethod http://localhost:8000/api/v1/ready
```

What this checks: confirms the backend container is reachable from your machine.

Expected:

```json
{"status":"ok"}
{"status":"ready"}
```

**What this confirms:** the backend container started, connected to Postgres and Redis using their Compose service names, and is responding to health checks on port 8000.

Why: containers talk to each other by Compose service name. The backend uses `postgres` and `redis` as hostnames, not `localhost`.

Windows PowerShell note: use `Invoke-RestMethod` or `curl.exe`, not plain `curl`. In Windows PowerShell, `curl` can be an alias for `Invoke-WebRequest` and may fail with an Internet Explorer parsing error.

## Step 6: Full Local Stack (complete docker-compose.local.yml)

After all individual services work, replace `infra/compose/docker-compose.local.yml` with the complete file:

```yaml
services:
  postgres:
    image: postgres:16
    container_name: skin-lesion-postgres-local
    env_file:
      - .env.local
    ports:
      - "5432:5432"
    volumes:
      - skin_lesion_postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d skin_lesion"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    container_name: skin-lesion-redis-local
    command: redis-server --maxmemory 256mb --maxmemory-policy allkeys-lru --requirepass redislocal
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "redislocal", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: skin-lesion-backend:local
    container_name: skin-lesion-backend-local
    env_file:
      - .env.local
    ports:
      - "8000:8080"
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

volumes:
  skin_lesion_postgres_data:
```

What this complete Compose file does: runs Postgres, Redis, and the backend together with healthchecks, environment-file loading, port mappings, and persistent database storage.

Bring everything up:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up -d
docker compose -f infra/compose/docker-compose.local.yml ps
```

What this does:

- `up -d` starts all services in the background.
- `ps` shows service status and health.

Expected: all three containers show `(healthy)`.

## Step 7: Add Frontend Later

Add the frontend only after the normal local frontend works.

Use:

```text
NEXT_PUBLIC_API_BASE_URL=http://localhost:8000
```

What this value does: points browser code running in the frontend at the backend exposed on your machine.

Do not put backend secrets into frontend Compose environment values.

## Step 8: Stop Cleanly

Stop services:

```powershell
docker compose -f infra/compose/docker-compose.local.yml down
```

What this does: stops and removes the Compose containers while keeping the named Postgres volume.

Keep the database volume for normal development.

Remove the database volume only when you intentionally want to reset local data:

```powershell
docker compose -f infra/compose/docker-compose.local.yml down -v
```

What this does: stops containers and deletes the named volumes, including local database data.

## Stop Point

Do not move to Kubernetes until:

```text
backend image builds
PostgreSQL container runs
backend container can reach PostgreSQL
/health works through Compose
```

What this stop-point checklist means: do not add Kubernetes until the same backend works as a container with its local database dependencies.

## Concepts You Just Touched

- [Immutable Infrastructure (6.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#65-immutable-infrastructure) - Compose is the first place you treat services as immutable artifacts
- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service) - state lives in named volumes, not in containers
- [Defense In Depth (8.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#83-defense-in-depth) - container network is one layer; image hygiene is another
- [Connection Pooling (4.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#44-connection-pooling) - backend ↔ postgres in compose teaches the pool tuning

## Questions You Should Be Able To Answer

1. Why is Docker Compose the right intermediate step between local Python/Node and Kubernetes?
2. What is a named volume vs a bind mount? Which one holds your local Postgres data and why?
3. If you `docker compose down -v`, what happens to the database? When is `-v` the right flag and when is it the wrong one?
4. Why does the backend `depends_on` Postgres but Postgres does not `depends_on` anything?
5. What is the difference between `compose.yml` and the production Kubernetes manifests, in terms of what they each guarantee?

If you cannot answer Q1-Q3, re-read the Compose basics section.
If you cannot answer Q4-Q5, read [System Design Patterns: 6.5 Immutable Infra](../reference/09_SYSTEM_DESIGN_PATTERNS.md#65-immutable-infrastructure).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Backend cannot connect to Postgres | hostname wrong; should be the service name, not `localhost` | `DATABASE_URL` env var |
| Compose down wipes data | `-v` flag included | drop the flag for routine stops |
| Port already in use | another local Postgres on 5432 | change the host-side port mapping |
| Image stays huge | every `RUN` creates a new layer | combine commands; use multi-stage |
| `compose up` hangs forever | unhealthy dependency loop | check `depends_on` with `condition: service_healthy` |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** report status, pause compute, and optionally destroy all dev cloud resources to stop costs.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** recreate and verify the dev environment before continuing.

If this guide was local-only, no cloud shutdown is needed.
