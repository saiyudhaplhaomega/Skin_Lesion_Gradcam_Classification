# Upload And Mock Prediction Handholding Guide

Use this after `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`.

## Goal

Build the user-facing prediction API without real AI first.

Why: the frontend and API contract can be learned before model loading, GPU issues, or Grad-CAM.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

**What these commands do:** navigate from the workspace root into the backend repo, then activate the virtual environment so pytest and uvicorn use the backend dependencies.

Run every command in this guide from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** all file creation, pytest runs, and uvicorn starts happen inside the backend repo. Python cannot find the `app/` package if you run these from the workspace root.

Every file path in this guide is relative to `Skin_Lesion_Classification_backend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...` and `tests/...` path in this guide under `Skin_Lesion_Classification_backend/`.
- Run upload API checks from `Skin_Lesion_Classification_backend/` unless the step says to use a second terminal.

## Endpoint

```text
POST /api/v1/analysis
```

**What this endpoint is:** the primary entry point for image analysis. The frontend sends an image here and gets back a prediction. In this guide it returns a hard-coded mock result - the same URL and response shape the real model will use later.

It should accept one image file and return a fake result.

## Step 1: Create Schemas

Create this file:

```text
app/schemas/analysis.py
```

**What this path is:** `app/schemas/` holds Pydantic models for request and response shapes. Separating schemas from route handlers means the same response type can be used across multiple endpoints and is easy to find when the API contract needs to change.

Paste:

```python
from pydantic import BaseModel, Field


class AnalysisResponse(BaseModel):
    case_id: str
    prediction: str = Field(examples=["benign"])
    confidence: float = Field(ge=0, le=1)
    explanation_available: bool
```

What this schema does:

- `BaseModel` creates a typed response model that FastAPI can serialize to JSON.
- `case_id` is the identifier the frontend can use later to fetch the case or explanation.
- `prediction` is the mock label returned before real inference exists.
- `Field(examples=["benign"])` documents an example value in the API docs.
- `confidence: float = Field(ge=0, le=1)` restricts confidence to the 0-to-1 probability range.
- `explanation_available` tells the frontend whether a Grad-CAM explanation exists yet.

## Step 2: Add Router Function

In `app/api/v1/router.py`, add:

```python
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.schemas.analysis import AnalysisResponse

router = APIRouter(prefix="/api/v1")


@router.get("/ready")
def ready() -> dict[str, str]:
    return {"status": "ready"}


@router.post("/analysis", response_model=AnalysisResponse)
async def analyze_image(image: UploadFile = File(...)) -> AnalysisResponse:
    if image.content_type not in {"image/jpeg", "image/png"}:
        raise HTTPException(status_code=400, detail="Only JPEG and PNG images are supported")

    return AnalysisResponse(
        case_id=str(uuid4()),
        prediction="benign",
        confidence=0.82,
        explanation_available=False,
    )
```

What this route does:

- `uuid4()` creates a temporary unique case ID for the mock response.
- `File` and `UploadFile` tell FastAPI to expect a multipart file upload.
- `HTTPException` creates a controlled API error instead of an unhandled crash.
- `response_model=AnalysisResponse` makes the endpoint return the documented schema.
- `image.content_type` rejects unsupported uploads before any model logic runs.
- `AnalysisResponse(...)` returns a stable fake result so the frontend can be built before real AI is wired in.

Why: this proves file upload, validation, and response shape.

## Step 3: Test Bad File Type

Create `tests/test_analysis.py`:

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_analysis_rejects_text_file() -> None:
    response = client.post(
        "/api/v1/analysis",
        files={"image": ("bad.txt", b"hello", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Only JPEG and PNG images are supported"
```

What this test does:

- `client.post(..., files=...)` sends a fake multipart upload to the endpoint.
- `("bad.txt", b"hello", "text/plain")` simulates a non-image file.
- The assertions prove the API rejects unsupported file types with a clear `400` error.

Run:

```powershell
pytest
```

**What this verifies:** pytest runs `test_analysis_rejects_text_file`. The test should pass because the route handler checks `image.content_type` before doing anything else. If it fails with a 200 instead of 400, the content type check is missing or wrong.

## Step 4: Test Successful Mock Upload

Update the whole file so it contains both tests and the shared `client` setup:

```text
Skin_Lesion_Classification_backend/tests/test_analysis.py
```

**What this path is:** the existing test file from Step 3. Keeping both tests in the same file keeps all `POST /api/v1/analysis` checks together. The `client = TestClient(app)` line is required because both tests use `client.post(...)`.

```python
from fastapi.testclient import TestClient

from app.main import app


client = TestClient(app)


def test_analysis_rejects_text_file() -> None:
    response = client.post(
        "/api/v1/analysis",
        files={"image": ("bad.txt", b"hello", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json()["detail"] == "Only JPEG and PNG images are supported"


def test_analysis_accepts_png() -> None:
    response = client.post(
        "/api/v1/analysis",
        files={"image": ("sample.png", b"fake-image-bytes", "image/png")},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == "benign"
    assert data["confidence"] == 0.82
    assert data["explanation_available"] is False
```

What this test does:

- Sends fake PNG bytes with an `image/png` content type.
- Confirms the mock endpoint accepts the upload.
- Checks the response contract the frontend will depend on.
- Verifies `explanation_available` is `False` because Grad-CAM is not wired in yet.

Run:

```powershell
pytest
```

**What this verifies:** runs both `test_analysis_rejects_text_file` and `test_analysis_accepts_png`. Both must pass before moving to the manual check step.

## Step 5: Manual Check

Use two PowerShell terminals.

### Terminal 1: Start The Backend Server

Run from this exact directory:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Commands:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

What this does:

- `cd ...\Skin_Lesion_Classification_backend` moves into the backend repo that contains `app/main.py`.
- `.\.venv\Scripts\Activate.ps1` activates the backend virtual environment.
- `.\.venv\Scripts\python.exe -m uvicorn ... --port 8010` starts Uvicorn through the backend virtual environment on port `8010`.
- Port `8010` is used for this manual check so an old server still listening on port `8000` cannot hide your new route.

Leave this terminal running. Do not type the curl command in Terminal 1 while Uvicorn is running.

### Terminal 2: Call The Upload API

Open a second PowerShell terminal.

Run from this exact directory:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Commands:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

Confirm the running server has the analysis route:

```powershell
curl.exe http://127.0.0.1:8010/openapi.json | Select-String "/api/v1/analysis"
```

Expected:

```text
/api/v1/analysis
```

**What this verifies:** the running Uvicorn process has loaded the updated router with `POST /api/v1/analysis`. If this prints nothing, the server you are hitting is stale or was started before Step 2 was added.

If the route is missing, stop Terminal 1 with `Ctrl+C`, then restart it from the backend folder:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

Then run the OpenAPI check again before trying the upload.

Run with a real local image:

```powershell
curl.exe -X POST http://127.0.0.1:8010/api/v1/analysis -F "image=@ml\data\processed\raw\images\ISIC_0024306.jpg"
```

What this does:

- `curl.exe` calls the real Windows curl program. In PowerShell, plain `curl` is an alias for `Invoke-WebRequest` and does not support curl's `-X` and `-F` flags.
- `-X POST` sends a POST request.
- The URL targets the local analysis endpoint on port `8010`, the clean manual-check server started in Terminal 1.
- `-F "image=@ml\data\processed\raw\images\ISIC_0024306.jpg"` uploads one real local image from the backend `ml/` folder as the multipart form field named `image`, matching the route parameter.

If that exact file is not present, pick any `.jpg` from:

```text
Skin_Lesion_Classification_backend/ml/data/processed/raw/images/
```

For example:

```powershell
Get-ChildItem ml\data\processed\raw\images -Filter *.jpg | Select-Object -First 5 Name
```

Expected shape:

```json
{
  "case_id": "...",
  "prediction": "benign",
  "confidence": 0.82,
  "explanation_available": false
}
```

**What this confirms:** the mock endpoint returns a valid JSON response with the expected field names and types. `case_id` will be a different UUID each time. This is the exact shape the frontend in guide 02 is coded to parse.

If the response is:

```json
{"detail":"Not Found"}
```

the server is reachable, but the running app on port `8010` does not have `POST /api/v1/analysis` registered. Stop Terminal 1 with `Ctrl+C`, restart the exact Terminal 1 command from this guide, then re-run the OpenAPI check before trying the upload again.

When this manual check is finished, return to Terminal 1 and press:

```text
Ctrl+C
```

Expected:

```text
INFO:     Shutting down
INFO:     Application shutdown complete.
```

**What this does:** stops the local Uvicorn server for this guide so it does not keep using port `8010` in the background.

## Stop Point

Now the frontend can be built against this mock API.

## Concepts You Just Touched

- [Idempotency Keys (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys) - the upload POST is the canonical place to enforce them
- [Backpressure (2.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#25-backpressure) - what happens when 50 patients upload at once
- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - end-to-end budget for `/analysis`
- [Signed URLs (8.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#85-signed-urls) - design space, you will use them for S3 later
- [PHI Tokenization (11.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#111-phi-tokenization) - the patient identifier in the request is a token, not an email

## Questions You Should Be Able To Answer

1. Why is the prediction "mocked" before the real model goes in? What does this teach you?
2. What is the maximum size of an upload your API should accept, and what is the response when it is exceeded?
3. If the same image is uploaded twice in a row (network retry), should you create two prediction records or one? How do you enforce that?
4. What is the end-to-end latency budget for `/analysis`? Where does each part go (multipart parse, store, model, return)?
5. Why is rejecting overload at the API layer better than queueing forever?

If you cannot answer Q1-Q3, re-read the steps above and the API contract section.
If you cannot answer Q4-Q5, read [System Design Patterns: 2.4 Timeout Budget](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) and [2.5 Backpressure](../reference/09_SYSTEM_DESIGN_PATTERNS.md#25-backpressure).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `413 Request Entity Too Large` | nginx/uvicorn body limit too low | uvicorn config or reverse proxy |
| Upload succeeds but no record in DB | exception swallowed in route handler | check structured logs for the request_id |
| Same image creates two prediction rows on retry | no idempotency key | add `Idempotency-Key` header support |
| `/analysis` slow (>10s) on a small image | model loading on first request | warm the model at startup |
| Multipart parse fails for some clients | content-type missing boundary | log the raw headers in dev |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** report status, pause compute, and optionally destroy all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** recreate and verify the dev environment before continuing.

If this guide was local-only, no cloud shutdown is needed.
