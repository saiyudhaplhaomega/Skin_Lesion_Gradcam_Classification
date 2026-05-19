# Backend API Handholding Guide

Use this after `docs/local-dev/01_LOCAL_BACKEND_FIRST.md`.

The backend subrepo also has a longer guide:

```text
Skin_Lesion_Classification_backend/BUILD_BACKEND.md
```

This root guide tells you the exact learning order and the checks to run.

## Goal

Build a FastAPI backend that starts simple and grows into the API used by the frontend, workers, and future Kubernetes deployment.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Step 1 then navigates into the backend repo. Starting here keeps all relative paths consistent.

After Step 1, run every command in this guide from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** all Python commands, pytest, and uvicorn in this guide run from inside the backend repo directory, not the workspace root. Python needs to be in the directory that contains `app/` to resolve `from app.main import app`.

Every file path in this guide is relative to `Skin_Lesion_Classification_backend`.

## Local Backend Server Rule

When a guide starts Uvicorn, use two PowerShell terminals:

- Terminal 1 runs the backend server and stays open.
- Terminal 2 runs `curl.exe` checks.

Start Uvicorn only from this exact directory:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Use the backend virtual environment's Python executable:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

When you are done with a manual server check, return to Terminal 1 and press:

```text
Ctrl+C
```

Expected:

```text
INFO:     Shutting down
INFO:     Application shutdown complete.
```

Why: leaving an old Uvicorn process running can make later guides call a stale app that does not include newly added routes.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...` and `tests/...` path in this guide under `Skin_Lesion_Classification_backend/`.
- Run backend commands only after `cd Skin_Lesion_Classification_backend` and activating the backend `.venv`.

When a command says `pytest`, run it from this exact directory:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Do not run backend `pytest` from:

- the workspace root, `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- the `app/` folder
- the frontend folder

If PowerShell says `pytest : The term 'pytest' is not recognized`, the backend virtual environment is not active in that terminal. Run this from `Skin_Lesion_Classification_backend`:

```powershell
.\.venv\Scripts\Activate.ps1
pytest
```

If activation is blocked by PowerShell policy, use the direct virtual-environment command:

```powershell
.\.venv\Scripts\python.exe -m pytest
```

## Step 1: Enter The Backend Folder

```powershell
cd Skin_Lesion_Classification_backend
```

What this does: moves your terminal into the backend repo so Python can import the local `app/` package and pytest can find the backend tests.

Why: keep backend Python files inside the backend repo, not in the project root.

## Step 2: Create The Local Environment

Check that Python 3.13 is installed:

```powershell
py -0p
```

**What this does:** lists all Python versions registered with the Windows Python Launcher, with their paths. Use this to confirm Python 3.13 is installed before creating the virtual environment. If only 3.14 appears, install 3.13 first.

Expected: one of the listed interpreters is Python 3.13.

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

What this does:

- `py -3.13 -m venv .venv` creates a Python 3.13 virtual environment in the backend folder.
- `.\.venv\Scripts\Activate.ps1` makes this terminal use `.venv` for `python`, `pip`, `pytest`, and `uvicorn`.
- `python -m pip install --upgrade pip` updates pip inside the virtual environment.
- `python -m pip install -r requirements-dev.txt` installs runtime dependencies plus local development tools.

Why: local development installs `requirements-dev.txt` because it already includes `requirements.txt`, then adds pytest, linting, notebooks, and plotting tools. Do not install with Python 3.14 while `requirements.txt` pins `torch==2.6.0`.

Check:

```powershell
python --version
pip list
```

**What these verify:** `python --version` confirms the virtual environment uses Python 3.13, not system Python. `pip list` shows all installed packages in the active environment - check that `torch`, `fastapi`, and `pytest` appear in the output.

Expected: `python --version` starts with `Python 3.13`.

## Step 3: Build Only `/health`

Create this shape inside `Skin_Lesion_Classification_backend`:

```text
app/
  __init__.py
  main.py
tests/
  test_health.py
```

**What this structure does:** `app/__init__.py` makes `app` a Python package so other files can do `from app.main import app`. `main.py` defines the FastAPI application. `tests/test_health.py` is where pytest finds and runs the health check test.

`app/main.py`:

```python
from fastapi import FastAPI

app = FastAPI(title="Skin Lesion API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

What this code does:

- `FastAPI` creates the backend application object.
- `title="Skin Lesion API"` labels the generated API docs.
- `@app.get("/health")` exposes a simple liveness endpoint.
- `return {"status": "ok"}` creates the JSON response that tests, curl, and later infrastructure checks can rely on.

`tests/test_health.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health_returns_ok() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

What this test does:

- `TestClient(app)` calls the FastAPI app directly in memory.
- `client.get("/health")` sends a test request to the route.
- The first assertion checks the HTTP status code.
- The second assertion checks the exact JSON contract.

Run from this exact command location:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Your PowerShell prompt should end with:

```text
\Skin_Lesion_Classification_backend>
```

and, after activation, should usually start with `(.venv)`.

Run:

```powershell
.\.venv\Scripts\Activate.ps1
pytest
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

What this does:

- `.\.venv\Scripts\Activate.ps1` makes this terminal use the backend virtual environment.
- `pytest` runs the backend tests.
- `.\.venv\Scripts\python.exe -m uvicorn ... --port 8000` starts the FastAPI app through the backend virtual environment, from `app/main.py`, and reloads when files change.

If `pytest` is not recognized, run the same test through the backend virtual environment directly:

```powershell
.\.venv\Scripts\python.exe -m pytest
```

In another terminal:

```powershell
curl.exe http://127.0.0.1:8000/health
```

**What this does:** sends an HTTP GET request to the running FastAPI server's health endpoint. This proves the route is registered and uvicorn is responding to external traffic, not just the in-process test client.

Expected:

```json
{"status":"ok"}
```

**What this confirms:** the JSON response matches the contract defined in `test_health.py`. If the response is empty or returns a connection error, check the uvicorn terminal for errors.

If you are continuing to Step 4 now, keep this Uvicorn terminal running. Step 4 uses the same server for `/api/v1/ready`.

When all manual checks in this guide are finished, go back to the terminal running Uvicorn and press:

```text
Ctrl+C
```

Expected:

```text
INFO:     Shutting down
INFO:     Application shutdown complete.
```

**What this does:** stops the local backend server so it does not keep using port `8000` in the background.

## Step 4: Add API Versioning

Create:

```text
app/api/v1/
  __init__.py
  router.py
```

**What this structure is:** a sub-package under `app/api/v1/`. The `__init__.py` makes the directory a Python package. `router.py` defines the versioned routes that will be attached to the main app. Grouping routes under `v1/` means the frontend and other callers can pin to the current API version while a future `v2/` is developed.

Why: `/api/v1/...` lets you change the API later without breaking old clients.

`app/api/v1/router.py`:

```python
from fastapi import APIRouter

router = APIRouter(prefix="/api/v1")


@router.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready"}
```

What this code does:

- `APIRouter` groups related API routes before they are attached to the main app.
- `prefix="/api/v1"` means every route in this router starts with `/api/v1`.
- `@router.get("/ready")` registers `GET /api/v1/ready`.
- `ready()` returns a readiness response. Later this endpoint can check dependencies such as the database or model registry.

Update `app/main.py`:

```python
from fastapi import FastAPI

from app.api.v1.router import router as v1_router

app = FastAPI(title="Skin Lesion API")
app.include_router(v1_router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

What changed:

- `from app.api.v1.router import router as v1_router` imports the versioned API router.
- `app.include_router(v1_router)` attaches every route from that router to the main FastAPI app.
- `/health` stays outside `/api/v1` because infrastructure checks should stay stable even when API versions change.

Update `tests/test_health.py` so the whole file looks like this:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_health_returns_ok() -> None:
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_ready_returns_ready() -> None:
    response = client.get("/api/v1/ready")

    assert response.status_code == 200
    assert response.json() == {"status": "ready"}
```

What this file does:

- `from fastapi.testclient import TestClient` imports FastAPI's in-memory test client.
- `from app.main import app` imports the backend application from `app/main.py`.
- `client = TestClient(app)` creates the shared test client used by both tests.
- `test_health_returns_ok` keeps the original `/health` contract covered.
- `test_ready_returns_ready` proves the versioned router is connected to the app and that `/api/v1/ready` returns the expected JSON contract.

Run from this exact command location:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Run:

```powershell
.\.venv\Scripts\Activate.ps1
pytest
curl.exe http://127.0.0.1:8000/api/v1/ready
```

**What these verify:** `.\.venv\Scripts\Activate.ps1` makes `pytest` available in this PowerShell terminal. `pytest` runs both `test_health_returns_ok` and `test_ready_returns_ready`. `curl.exe` confirms the versioned route works through the real uvicorn server, not just in the test client.

If `pytest` is not recognized, run:

```powershell
.\.venv\Scripts\python.exe -m pytest
curl.exe http://127.0.0.1:8000/api/v1/ready
```

## Step 5: Stop Point

Do not add database, Docker, Kubernetes, or AWS until this passes:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
pytest
curl.exe http://127.0.0.1:8000/health
curl.exe http://127.0.0.1:8000/api/v1/ready
```

**What this gate means:** all three commands must return successful results before moving to the next guide. `pytest` confirms the code is tested. The two `curl` commands confirm the server runs correctly outside the test environment. Only when all three pass is the API contract stable enough to layer infrastructure on top.

You now have the smallest backend foundation.

## Concepts You Just Touched

- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service)
- [Idempotency Keys (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys) - design space, even before you enforce it
- [Connection Pooling (4.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#44-connection-pooling)
- [RED And USE Metrics (10.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#101-red-and-use-metrics)
- [Structured Logging (10.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#102-structured-logging)
- [Defense In Depth (8.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#83-defense-in-depth) - the API is one layer

## Questions You Should Be Able To Answer

1. What is the difference between `/health` and `/api/v1/ready`? When should each return non-200?
2. Why does FastAPI's response model matter for the API contract, not just runtime validation?
3. If a POST creates a database row and the client retries on timeout, what makes the second call safe?
4. Why must every endpoint have an explicit timeout on every external call it makes?
5. What does a structured log line for one `/analysis` request look like, end-to-end?

If you cannot answer Q1-Q2, re-read the "/health vs /ready" section above.
If you cannot answer Q3-Q5, read [System Design Patterns: 3.1 Idempotency Keys](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys) and [10.2 Structured Logging](../reference/09_SYSTEM_DESIGN_PATTERNS.md#102-structured-logging).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `422 Unprocessable Entity` on every request | Pydantic model field type mismatch | check the FastAPI auto-docs at `/docs` |
| `/ready` returns 200 but DB is down | readiness probe does not actually check the DB | add a `SELECT 1` to the readiness handler |
| Request hangs forever | no client-side timeout on a downstream call | grep for `httpx.get(`, `requests.get(`, `boto3` without `timeout=` |
| 500 errors with no trace | uncaught exception not logged with context | add a global FastAPI exception handler |
| Tests pass, runtime fails | tests do not exercise the real DB | add at least one integration test |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** `make cloud-status ENV=dev` reports running dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
