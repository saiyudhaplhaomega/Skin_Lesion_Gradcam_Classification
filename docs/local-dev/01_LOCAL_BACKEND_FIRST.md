# Local Backend First

Start here when you are ready to write code.

## Goal

Establish the smallest FastAPI backend with a `/health` endpoint that works locally before introducing Docker, Kubernetes, or cloud complexity.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. This is where the Makefile and all sub-repos live. Running commands from here first ensures relative paths in later steps work correctly.

After Step 1, every command in this guide runs from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** all backend commands - virtual environment activation, pip installs, pytest, and uvicorn - must be run from inside this directory, not from the workspace root. Running them from the wrong directory causes "ModuleNotFoundError: app" because Python cannot find the `app/` package.

## Why This Comes First

Everything depends on the backend contract. If `/health` does not work locally, Docker, Kubernetes, AWS, and CI/CD will only create more confusing errors.

## Step 1: Go To The Backend Repo

```powershell
cd Skin_Lesion_Classification_backend
```

**What this does:** enters the backend repository. All subsequent commands in this guide - virtual environment creation, pip installs, pytest, uvicorn - run from here.

Check where you are:

```powershell
Get-Location
Get-ChildItem
```

**What these do:** `Get-Location` prints the current working directory so you can confirm you are inside `Skin_Lesion_Classification_backend` and not the workspace root. `Get-ChildItem` lists the directory contents - seeing `requirements.txt`, `Makefile`, and `app/` confirms you are in the right place.

You should see files like:

```text
requirements.txt
README.md
Makefile
```

**What this confirms:** these three files indicate the root of the backend repo. If you see the frontend or workspace-root files instead, you ran `cd` from the wrong starting directory.

## Step 2: Create A Virtual Environment

Check that Python 3.13 is installed before creating the virtual environment:

```powershell
py -0p
```

**What this does:** the Python Launcher (`py`) lists all installed Python versions and their full paths. This tells you which Python versions are available before you create the virtual environment, so you can confirm 3.13 is present.

Expected: one of the listed interpreters is Python 3.13, for example:

```text
 -V:3.13          C:\Users\saiyu\AppData\Local\Programs\Python\Python313\python.exe
```

**What this shows:** the `-V:3.13` tag and the `Python313` path confirm Python 3.13 is installed and the launcher knows about it. If only Python 3.14 appears here, stop and install Python 3.13 from python.org before continuing.

If `py -0p` only lists Python 3.14, stop and install Python 3.13 first. Do not continue with `python -m venv .venv`, because `python` will use the newest installed Python on this machine.

Do not use Python 3.14 for this backend yet. The backend pins a scientific ML stack (`torch==2.6.0`, `torchvision==0.21.0`, `numpy==2.2.2`, and `grad-cam==1.5.5`). Wheels for these pinned packages are not consistently available for Python 3.14.

Do not run this command for this backend:

```powershell
python -m venv .venv
```

**Why not:** on this machine, `python` resolves to Python 3.14 (the newest installed version). Running `python -m venv .venv` would create a 3.14 environment. Then `pip install torch==2.6.0` fails because the pinned Torch and Grad-CAM wheels are not available for 3.14 yet. Use `py -3.13` instead to pin the interpreter explicitly.

On this machine, that creates a Python 3.14 virtual environment and causes package resolution errors such as Torch or Grad-CAM not being found.

Create the backend virtual environment with the Python launcher so it uses exactly Python 3.13:

```powershell
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
```

What this does:

- `py -3.13 -m venv .venv` creates a local Python 3.13 environment in `Skin_Lesion_Classification_backend/.venv`.
- `.\.venv\Scripts\Activate.ps1` tells this terminal to use the backend virtual environment instead of global Python.
- `python -m pip install --upgrade pip` upgrades pip inside `.venv`, not on the whole machine.
- `python -m pip install -r requirements-dev.txt` installs the backend runtime packages plus local testing and development tools.

Why: this isolates backend dependencies from your system Python. `requirements.txt` is the runtime dependency file. `requirements-dev.txt` includes `requirements.txt` with `-r requirements.txt`, then adds test, lint, notebook, and plotting tools. For local development, install `requirements-dev.txt` only.

Check:

```powershell
python --version
python -m pip show torch
pip list
python -m pytest --version
```

**What these verify:** `python --version` confirms the virtual environment is using 3.13, not system Python. `python -m pip show torch` confirms Torch is installed at the expected version - if this returns "WARNING: Package(s) not found", the install failed. `pip list` shows everything installed, useful for spotting version conflicts. `python -m pytest --version` confirms pytest is available and importable inside the environment.

Expected:

```text
Python 3.13.x
Name: torch
Version: 2.6.0
pytest 8.3.4
```

**What this confirms:** all four values together prove the environment is using the correct Python version and that the three most critical packages (Torch, pip, pytest) are installed at the expected versions.

If you already created `.venv` with Python 3.14 and saw `ERROR: Could not find a version that satisfies the requirement torch==2.6.0`, delete only the backend virtual environment and recreate it:

```powershell
deactivate
Remove-Item -Recurse -Force .venv
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
python --version
python -m pip show torch
```

What this does:

- `deactivate` leaves the broken virtual environment if it is currently active.
- `Remove-Item -Recurse -Force .venv` deletes only the backend dependency sandbox, not your source code.
- The next four commands recreate the sandbox with Python 3.13 and reinstall the backend dependencies.
- `python --version` and `python -m pip show torch` prove the recreated environment is using the expected Python and ML package versions.

Expected: `python --version` starts with `Python 3.13`, `python -m pip show torch` reports `Version: 2.6.0`, and `python -m pip show grad-cam` reports `Version: 1.5.5`.

If you see this error:

```text
ERROR: Could not find a version that satisfies the requirement pytorch-grad-cam==1.5.1
```

**What this means:** the package name `pytorch-grad-cam` does not exist on PyPI under that exact name. The correct PyPI package name is `grad-cam` (no `pytorch-` prefix). The Python import name is `pytorch_grad_cam` (with underscores), which can cause confusion - the import name and the PyPI install name are different. Fix `requirements.txt` to use `grad-cam==1.5.5`, then re-run the pip install.

The package name is wrong for PyPI. This project installs `grad-cam==1.5.5`, while Python code imports it as `pytorch_grad_cam`.

## Step 3: Create The Smallest App

Create these files inside `Skin_Lesion_Classification_backend`:

```text
app/
  __init__.py
  main.py
tests/
  test_health.py
```

**What this structure means:** `app/` is a Python package - `__init__.py` (even if empty) tells Python to treat this folder as importable. `main.py` holds the FastAPI app object. `tests/` is where pytest discovers test files. Keeping application code and tests in separate top-level directories is the standard FastAPI project layout.

`Skin_Lesion_Classification_backend/app/main.py`:

```python
from fastapi import FastAPI

app = FastAPI(title="Skin Lesion API")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

What this code does:

- `from fastapi import FastAPI` imports the web framework class used to create the backend app.
- `app = FastAPI(title="Skin Lesion API")` creates the ASGI application that uvicorn will run. The title appears later in the generated API docs.
- `@app.get("/health")` registers a `GET /health` endpoint.
- `def health() -> dict[str, str]` defines the function FastAPI calls for that endpoint and documents that it returns a string-to-string JSON object.
- `return {"status": "ok"}` sends the smallest useful health response. Keep this endpoint fast and simple; do not load the ML model or call the database here.

`Skin_Lesion_Classification_backend/tests/test_health.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


def test_health() -> None:
    client = TestClient(app)
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
```

What this test does:

- `TestClient` lets the test call the FastAPI app in memory without starting a real server.
- `from app.main import app` imports the same app object uvicorn will serve.
- `client.get("/health")` exercises the real route.
- `assert response.status_code == 200` proves the endpoint returns success.
- `assert response.json() == {"status": "ok"}` locks the response contract so later changes do not silently break frontend or infrastructure checks.

## Step 4: Run The Check

```powershell
pytest
```

What this does: `pytest` discovers and runs tests in the backend repo, including `tests/test_health.py`.

Then start the server from the backend repo. Do not run `uvicorn app.main:app` from the workspace root, because Python will not see the backend `app/` package from there.

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
Get-Location
uvicorn app.main:app --reload
```

What this does:

- `cd ...\Skin_Lesion_Classification_backend` puts the terminal in the package root where `app/` exists.
- `.\.venv\Scripts\Activate.ps1` activates the backend dependencies.
- `Get-Location` proves the terminal is in the correct folder before starting the server.
- `uvicorn app.main:app --reload` runs the `app` object from `app/main.py` and restarts automatically when backend files change.

Expected `Get-Location` result:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

**What this confirms:** the terminal is inside the backend repo, not the workspace root. If `Get-Location` shows the workspace root path, uvicorn will fail with `ModuleNotFoundError: app` because it cannot find the `app/` package from that level.

Open another terminal from any directory:

```powershell
curl http://localhost:8000/health
```

What this does: `curl` sends an HTTP request to the local FastAPI server. This proves the endpoint works outside the test runner.

Expected:

```json
{"status":"ok"}
```

**What this confirms:** FastAPI is running, the route is registered, and uvicorn is accepting connections. If `curl` returns a connection refused error, check the uvicorn terminal for startup errors or try port 8000 explicitly with `curl http://localhost:8000/health`.

## Stop Point

Stop here until this works. Do not create Docker, Terraform, Kubernetes, or GitHub Actions yet.

## Concepts You Just Touched

- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service)
- [RED And USE Metrics (10.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#101-red-and-use-metrics) - `/health` is the first place RED matters
- [Structured Logging (10.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#102-structured-logging) - design intent for later

## Questions You Should Be Able To Answer

1. Why does `/health` need to return fast and never block on a downstream call (DB, S3, model)?
2. What is the difference between liveness and readiness probes? Which one does this `/health` map to today?
3. If you scale to 4 FastAPI workers, what state must NOT live in process memory? Where does it go instead?
4. What HTTP status should `/health` return when the ML model is still loading at startup (~120s)?
5. Why is FastAPI's `TestClient` a safer first test than starting uvicorn and curling the endpoint?

If you cannot answer Q1-Q2, re-read the "Why This Comes First" section.
If you cannot answer Q3-Q5, read [System Design Patterns: Family 1 - State And Session](../reference/09_SYSTEM_DESIGN_PATTERNS.md#family-1---state-and-session).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `ERROR: Could not find a version that satisfies the requirement torch==2.6.0` | `.venv` was created with Python 3.14 instead of Python 3.13 | run `python --version`; recreate `.venv` with `py -3.13 -m venv .venv` |
| `ERROR: Could not find a version that satisfies the requirement pytorch-grad-cam==1.5.1` | old or wrong package name; PyPI package is `grad-cam` | update `requirements.txt`, then run `python -m pip install -r requirements-dev.txt` |
| `pytest` fails with `ModuleNotFoundError: app` | virtualenv not activated, or `pytest` running from wrong directory | check `Get-Location` and `.venv` activation |
| `uvicorn app.main:app` fails with `ModuleNotFoundError: app` | uvicorn was started from the workspace root instead of the backend folder | run `cd Skin_Lesion_Classification_backend`, then `uvicorn app.main:app --reload --port 8000` |
| `curl: (7) Failed to connect to localhost port 8000` | uvicorn not running, or running on a different host | check the uvicorn terminal output |
| `/health` returns 500 | import error at module load | look at the uvicorn console; the traceback is there |
| `/health` slow (>100ms) | something synchronous added during import | search `app/main.py` for blocking I/O at module level |
| Tests pass locally but fail in CI | wrong working directory | CI must `cd Skin_Lesion_Classification_backend` first |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** `make cloud-status ENV=dev` shows what dev cloud resources are currently running. `make cloud-pause ENV=dev` scales pods to zero to stop per-hour compute charges without destroying the infrastructure. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` tears everything down completely.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** `make cloud-start ENV=dev` recreates or resumes the dev environment from Terraform state. `make cloud-status ENV=dev` confirms all resources are healthy before continuing with the next guide.

If this guide was local-only, no cloud shutdown is needed.
