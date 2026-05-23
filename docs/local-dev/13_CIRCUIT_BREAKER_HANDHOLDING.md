# Circuit Breaker Handholding Guide

Use this after the model service stub works (after `docs/local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md`).

This closes High Priority Gap: "No circuit breaker on ML inference - hung CAM generation can exhaust the thread pool."

## Goal

Wrap the inference endpoint in a circuit breaker so a hung or slow model call does not cascade into the rest of the API.

## Why This Matters

Grad-CAM on CPU can take 2-5 seconds per image. If 10 users upload simultaneously, 10 threads block on inference. FastAPI's thread pool is exhausted. Now `/health` is also slow. The whole API appears down. The circuit breaker prevents this cascade.

Pattern reference: `docs/reference/09_SYSTEM_DESIGN_PATTERNS.md` - Circuit Breaker and Bulkhead families.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

What this does: moves into the backend repo and activates the Python environment where FastAPI, pytest, and model dependencies are installed.

All file paths are relative to `Skin_Lesion_Classification_backend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...` and `tests/...` path in this guide under `Skin_Lesion_Classification_backend/`.
- Run all Python, pytest, and backend service commands from `Skin_Lesion_Classification_backend/`.

## Step 1: Confirm No New Dependency Is Needed

Do not add a new package for this local circuit breaker.

Check from the backend repo:

```powershell
Select-String -Path requirements.txt -Pattern "tenacity|circuitbreaker|pybreaker"
```

Expected result:

```text
No output.
```

What this confirms: the local circuit breaker uses the Python standard library (`threading`, `time`, and `asyncio`) and does not add another runtime dependency.

Why: retries can amplify load when inference is already slow or failing. This guide adds fail-fast protection and a bulkhead limit, not automatic retries.

If you already added `tenacity==9.0.0` while following an older version of this guide, remove it from `requirements.txt`, then run:

```powershell
pip install -r requirements.txt
```

Expected result: dependency installation completes without adding a circuit-breaker package.

## Step 2: Create Circuit Breaker Module

Create `app/core/circuit_breaker.py`:

```python
"""
Thread-safe circuit breaker and bulkhead primitives for ML inference.

States:
  CLOSED  - normal; calls go through
  OPEN    - tripped; calls fail fast with 503 (do not call model)
  HALF-OPEN - one test call allowed; if it succeeds, circuit closes
"""
from __future__ import annotations

import asyncio
import logging
import threading
import time
from enum import Enum

logger = logging.getLogger(__name__)

# Limit to 4 concurrent inference calls - tune based on your GPU/CPU capacity
INFERENCE_SEMAPHORE = asyncio.Semaphore(4)


class CircuitState(Enum):
    CLOSED = "closed"
    OPEN = "open"
    HALF_OPEN = "half_open"


class CircuitBreaker:
    """
    Protect a single callable (ML inference) from cascading failures.

    Args:
        failure_threshold: consecutive failures before opening circuit
        recovery_timeout: seconds to wait before trying HALF-OPEN
        half_open_max_calls: how many test calls in HALF-OPEN state
    """

    def __init__(
        self,
        failure_threshold: int = 3,
        recovery_timeout: float = 30.0,
        half_open_max_calls: int = 1,
    ) -> None:
        self._failure_threshold = failure_threshold
        self._recovery_timeout = recovery_timeout
        self._half_open_max_calls = half_open_max_calls

        self._state = CircuitState.CLOSED
        self._failure_count = 0
        self._last_failure_time: float = 0.0
        self._half_open_calls = 0
        self._lock = threading.Lock()

    @property
    def state(self) -> CircuitState:
        with self._lock:
            if self._state == CircuitState.OPEN:
                if time.monotonic() - self._last_failure_time >= self._recovery_timeout:
                    self._state = CircuitState.HALF_OPEN
                    self._half_open_calls = 0
                    logger.info("Circuit breaker: OPEN -> HALF_OPEN")
            return self._state

    def call(self, fn, *args, **kwargs):
        """
        Call fn with circuit breaker protection.
        Raises CircuitOpenError if the circuit is OPEN.
        """
        state = self.state

        if state == CircuitState.OPEN:
            raise CircuitOpenError("ML inference circuit is OPEN. Try again shortly.")

        if state == CircuitState.HALF_OPEN:
            with self._lock:
                if self._half_open_calls >= self._half_open_max_calls:
                    raise CircuitOpenError("Circuit is HALF-OPEN and test call slot is taken.")
                self._half_open_calls += 1

        try:
            result = fn(*args, **kwargs)
            self._on_success()
            return result
        except Exception as exc:
            self._on_failure()
            raise exc

    def _on_success(self) -> None:
        with self._lock:
            if self._state == CircuitState.HALF_OPEN:
                logger.info("Circuit breaker: HALF_OPEN -> CLOSED (test call succeeded)")
            self._state = CircuitState.CLOSED
            self._failure_count = 0

    def _on_failure(self) -> None:
        with self._lock:
            self._failure_count += 1
            self._last_failure_time = time.monotonic()
            if self._failure_count >= self._failure_threshold:
                if self._state != CircuitState.OPEN:
                    logger.warning(
                        "Circuit breaker: CLOSED -> OPEN after %d failures",
                        self._failure_count,
                    )
                self._state = CircuitState.OPEN


class CircuitOpenError(Exception):
    """Raised when the circuit is open and the call is rejected."""
    pass
```

What this module does:

- `CircuitState` defines the three breaker states: normal, failing-fast, and test-recovery.
- `CircuitBreaker` tracks consecutive failures, recovery time, and half-open test calls.
- The lock makes state changes thread-safe inside one process.
- `INFERENCE_SEMAPHORE` caps concurrent inference calls in one process.
- `state` automatically moves from `OPEN` to `HALF_OPEN` after the recovery timeout.
- `call()` either rejects the call, allows a half-open test call, or runs the protected function.
- `_on_success()` resets the breaker to closed.
- `_on_failure()` increments the failure count and opens the breaker after the threshold.
- `CircuitOpenError` gives the API layer a specific exception to convert into HTTP 503.

Check:

```powershell
Select-String -Path app\core\circuit_breaker.py -Pattern "from app.core.circuit_breaker|@router|APIRouter|UploadFile|HTTPException"
```

Expected result:

```text
No output.
```

Why: the core module must not import itself and must not contain FastAPI route code.

## Step 3: Wrap Model Service With The Circuit Breaker

Edit:

```text
app/services/model_service.py
```

Add this import near the other app imports:

```python
from app.core.circuit_breaker import CircuitBreaker, CircuitOpenError
```

Add this module-level breaker after `_LABELS`:

```python
_INFERENCE_BREAKER = CircuitBreaker(
    failure_threshold=3,    # open after 3 consecutive failures
    recovery_timeout=30.0,  # wait 30 seconds before testing again
)
```

Inside the existing `ModelService` class, change `predict()` so it only wraps the original inference logic:

```python
    def predict(self, image_bytes: bytes, return_cam: bool = False) -> PredictionResult:
        try:
            return _INFERENCE_BREAKER.call(self._predict_internal, image_bytes, return_cam)
        except CircuitOpenError:
            raise
```

Then rename the original prediction method body to `_predict_internal()`:

```python
    def _predict_internal(self, image_bytes: bytes, return_cam: bool) -> PredictionResult:
        tensor, img_array = _preprocess(image_bytes)
        tensor = tensor.to(self._device)

        with torch.no_grad():
            logit: float = self._net(tensor).squeeze().item()

        confidence = _apply_temperature(logit, self._temperature)
        label = _LABELS[int(confidence >= 0.5)]

        cam_b64 = ""
        if return_cam:
            cam_b64 = self._generate_cam(tensor, img_array)

        return PredictionResult(
            label=label,
            confidence=round(confidence, 4),
            raw_logit=round(logit, 4),
            cam_png_b64=cam_b64,
        )
```

What this wrapper does:

- Creates one module-level breaker for inference calls.
- Sends prediction work through `_INFERENCE_BREAKER.call(...)`.
- Leaves `CircuitOpenError` for the API layer to translate into a user-facing response.
- Moves the original prediction logic into `_predict_internal()` so the breaker can wrap it cleanly.

Important: keep exactly one `class ModelService` in this file. Do not paste a second `class ModelService` at the bottom.

Check:

```powershell
Select-String -Path app\services\model_service.py -Pattern "class ModelService"
Select-String -Path app\services\model_service.py -Pattern "def predict|def _predict_internal"
```

Expected result:

```text
One class ModelService line.
One def predict line and one def _predict_internal line.
```

## Step 4: Return 503 When Circuit Is Open

Edit:

```text
app/api/v1/router.py
```

This is the current local backend route file because it contains:

```python
router = APIRouter(prefix="/api/v1")
```

Do not add a second route in `app/api/v1/analysis.py`.

At the top of `app/api/v1/router.py`, make sure these imports exist:

```python
import asyncio

from app.core.circuit_breaker import CircuitOpenError, INFERENCE_SEMAPHORE
from app.services.model_service import ModelService
```

Below `router = APIRouter(prefix="/api/v1")`, create one model service instance:

```python
_model_service = ModelService()
```

Replace the existing `/analysis` route with:

```python
@router.post("/analysis", response_model=AnalysisResponse)
async def analyze_image(image: UploadFile = File(...)) -> AnalysisResponse:
    if image.content_type not in {"image/jpeg", "image/png"}:
        raise HTTPException(status_code=400, detail="Only JPEG and PNG images are supported")

    image_bytes = await image.read()

    async with INFERENCE_SEMAPHORE:
        try:
            return await asyncio.get_running_loop().run_in_executor(
                None,
                lambda: _analysis_response(image_bytes),
            )
        except CircuitOpenError:
            raise HTTPException(
                status_code=503,
                detail="Model inference is temporarily unavailable. Please try again in 30 seconds.",
                headers={"Retry-After": "30"},
            ) from None


def _analysis_response(image_bytes: bytes) -> AnalysisResponse:
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image")

    result = _model_service.predict(image_bytes)

    return AnalysisResponse(
        case_id=str(uuid4()),
        prediction=result.label,
        confidence=result.confidence,
        explanation_available=False,
    )
```

What this handler does:

- Catches only the circuit-open case.
- Returns `503 Service Unavailable` so clients know this is temporary.
- Adds `Retry-After: 30` so a frontend or proxy knows when retrying makes sense.
- Reads the upload bytes once before entering the thread-pool lambda.
- Keeps the response shape as `AnalysisResponse`.

Why 503 not 500: 503 tells the client (and load balancer) "retry later". 500 implies a bug.

## Step 5: Add A Semaphore - Limit Concurrent Inference

The circuit breaker stops cascading failure after it trips. The semaphore prevents it from tripping in the first place by capping concurrent inference calls.

### Step 5A: Go To The Backend Repo

Run this from PowerShell:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

What this does: moves into the backend repository. Every file path in this step is relative to:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Check:

```powershell
Test-Path app\core\circuit_breaker.py
Test-Path app\api\v1\router.py
```

Expected result:

```text
True
True
```

Why: `app/core/circuit_breaker.py` holds reusable protection logic. `app/api/v1/router.py` owns the current `/api/v1/analysis` route in this backend.

### Step 5B: Confirm The Semaphore Is In The Core File

Edit this file:

```text
app/core/circuit_breaker.py
```

Confirm `import asyncio` exists near the other imports:

```python
import asyncio
```

Confirm this constant exists after `logger = logging.getLogger(__name__)`:

```python
# Limit to 4 concurrent inference calls - tune based on your GPU/CPU capacity
INFERENCE_SEMAPHORE = asyncio.Semaphore(4)
```

What this semaphore does: limits the number of inference requests allowed to run concurrently in this process.

Do not paste route code into `app/core/circuit_breaker.py`.

What belongs in `app/core/circuit_breaker.py`:

```text
CircuitState
CircuitBreaker
CircuitOpenError
INFERENCE_SEMAPHORE
```

What does not belong in `app/core/circuit_breaker.py`:

```text
APIRouter
@router.post(...)
UploadFile
HTTPException
route handler functions
```

Why: `app/core/circuit_breaker.py` is reusable infrastructure logic. API route code belongs in the FastAPI route module so the dependency direction stays clean:

```text
API route -> core circuit breaker
core circuit breaker -> no API imports
```

Check the core file before moving on:

```powershell
Select-String -Path app\core\circuit_breaker.py -Pattern "from app.core.circuit_breaker|@router|APIRouter|UploadFile|HTTPException"
Select-String -Path app\core\circuit_breaker.py -Pattern "INFERENCE_SEMAPHORE"
```

Expected result:

```text
The first command prints no matches.
The second command prints the INFERENCE_SEMAPHORE line.
```

Why: a self-import such as `from app.core.circuit_breaker import INFERENCE_SEMAPHORE` inside `app/core/circuit_breaker.py` is wrong. The file defines `INFERENCE_SEMAPHORE`; it does not import it from itself.

### Step 5C: Confirm The Existing API Route Uses The Semaphore

Check this file:

```text
app/api/v1/router.py
```

This is the current local backend route file because it contains:

```python
router = APIRouter(prefix="/api/v1")
```

At the top of `app/api/v1/router.py`, these imports should exist:

```python
import asyncio

from app.core.circuit_breaker import CircuitOpenError, INFERENCE_SEMAPHORE
```

The existing route should be named:

```python
@router.post("/analysis", response_model=AnalysisResponse)
async def analyze_image(image: UploadFile = File(...)) -> AnalysisResponse:
```

It should use this pattern:

```python
@router.post("/analysis", response_model=AnalysisResponse)
async def analyze_image(image: UploadFile = File(...)) -> AnalysisResponse:
    if image.content_type not in {"image/jpeg", "image/png"}:
        raise HTTPException(status_code=400, detail="Only JPEG and PNG images are supported")

    image_bytes = await image.read()

    async with INFERENCE_SEMAPHORE:
        try:
            return await asyncio.get_running_loop().run_in_executor(
                None,
                lambda: _analysis_response(image_bytes),
            )
        except CircuitOpenError:
            raise HTTPException(
                status_code=503,
                detail="Model inference is temporarily unavailable. Please try again in 30 seconds.",
                headers={"Retry-After": "30"},
            )

def _analysis_response(image_bytes: bytes) -> AnalysisResponse:
    # See Step 4 for the full helper body.
```

What this route pattern does:

- `async with INFERENCE_SEMAPHORE` caps concurrent inference.
- `run_in_executor(...)` moves blocking model work off the event loop.
- `image_bytes = await image.read()` happens before `run_in_executor` because `await` cannot be used inside the synchronous lambda passed to the thread pool.
- The default thread pool is used for the blocking call.
- Circuit-open failures still become `503` responses.

Why semaphore: prevents queue buildup that exhausts threads before the breaker trips.
This is the Bulkhead pattern (see `docs/reference/09_SYSTEM_DESIGN_PATTERNS.md` 2.2 Bulkhead).

Important: this route pattern assumes `app/api/v1/router.py` imports `uuid4`, `File`, `HTTPException`, `UploadFile`, `AnalysisResponse`, and `ModelService`.

If your backend has moved analysis into a separate file later, use this file instead:

```text
app/api/v1/analysis.py
```

But only use one route file. Do not keep two `@router.post("/analysis")` handlers.

### Step 5D: Check For The Common Mistakes

Run from:

```powershell
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

```powershell
Select-String -Path app\core\circuit_breaker.py -Pattern "from app.core.circuit_breaker|@router|APIRouter|UploadFile|HTTPException"
Select-String -Path app\api\v1\*.py -Pattern "@router.post"
```

Expected result:

```text
No matches from app/core/circuit_breaker.py.
Exactly one route handler line for /analysis:
app\api\v1\router.py:<line>:@router.post("/analysis", response_model=AnalysisResponse)
```

Then run the backend tests:

```powershell
pytest tests/test_health.py tests/test_analysis.py -v
```

Expected result: health, ready, upload rejection, and PNG analysis tests still pass.

## Step 6: Test The Circuit Breaker

Create `tests/test_circuit_breaker.py`:

```python
import time

import pytest

from app.core.circuit_breaker import CircuitBreaker, CircuitOpenError


def _failing_fn() -> str:
    raise RuntimeError("inference failed")


def _success_fn() -> str:
    return "ok"


def test_circuit_opens_after_threshold() -> None:
    breaker = CircuitBreaker(failure_threshold=3, recovery_timeout=999.0)

    for _ in range(3):
        with pytest.raises(RuntimeError):
            breaker.call(_failing_fn)

    # Circuit should now be OPEN
    with pytest.raises(CircuitOpenError):
        breaker.call(_success_fn)


def test_circuit_closes_after_successful_test_call() -> None:
    breaker = CircuitBreaker(failure_threshold=1, recovery_timeout=0.01)
    with pytest.raises(RuntimeError):
        breaker.call(_failing_fn)

    time.sleep(0.02)

    result = breaker.call(_success_fn)

    assert result == "ok"
    assert breaker.state.value == "closed"


def test_circuit_stays_open_during_recovery() -> None:
    breaker = CircuitBreaker(failure_threshold=1, recovery_timeout=999.0)
    with pytest.raises(RuntimeError):
        breaker.call(_failing_fn)

    with pytest.raises(CircuitOpenError):
        breaker.call(_success_fn)
```

What these tests do:

- Force failures until the breaker opens.
- Confirm open circuits reject calls fast.
- Confirm the breaker moves to half-open after timeout and closes after a successful test call.
- Confirm the breaker stays open before the recovery timeout expires.

Create `tests/test_analysis_circuit_breaker.py`:

```python
import io

from fastapi.testclient import TestClient
from PIL import Image

from app.api.v1 import router as api_router
from app.core.circuit_breaker import CircuitOpenError
from app.main import app


client = TestClient(app)


def _png_bytes() -> bytes:
    image = Image.new("RGB", (32, 32), color=(128, 128, 128))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def test_analysis_returns_503_when_circuit_is_open(monkeypatch) -> None:
    def circuit_open(_image_bytes: bytes):
        raise CircuitOpenError("open")

    monkeypatch.setattr(api_router._model_service, "predict", circuit_open)

    response = client.post(
        "/api/v1/analysis",
        files={"image": ("sample.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 503
    assert response.headers["retry-after"] == "30"
    assert response.json()["detail"] == (
        "Model inference is temporarily unavailable. Please try again in 30 seconds."
    )
```

What this test does:

- Temporarily makes the route's model service raise `CircuitOpenError`.
- Sends a normal upload request to `/api/v1/analysis`.
- Confirms the API returns `503` with `Retry-After: 30`.

Update `tests/test_analysis.py` so the PNG test sends an actual in-memory PNG, not fake bytes:

```python
import io

from fastapi.testclient import TestClient
from PIL import Image

from app.main import app


client = TestClient(app)


def _png_bytes() -> bytes:
    image = Image.new("RGB", (32, 32), color=(128, 128, 128))
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()
```

Then use `_png_bytes()` in `test_analysis_accepts_png()`:

```python
def test_analysis_accepts_png() -> None:
    response = client.post(
        "/api/v1/analysis",
        files={"image": ("sample.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] in {"benign", "malignant"}
    assert 0 <= data["confidence"] <= 1
    assert data["explanation_available"] is False
```

Why: after this guide, the route calls `ModelService`, which opens the uploaded image with Pillow. Fake bytes with `image/png` are no longer enough.

Run:

```powershell
pytest tests/test_health.py tests/test_analysis.py tests/test_circuit_breaker.py tests/test_analysis_circuit_breaker.py -v
```

What this does: runs the health checks, upload route checks, circuit breaker unit tests, and the circuit-open API response test.

Expected result:

```text
8 passed
```

Then run the full backend suite:

```powershell
pytest -v
```

Expected result:

```text
14 passed
```

## Stop Point

Do not add retries inside the circuit breaker - retries amplify load when the model is failing.
Use retries only at the client (frontend) with exponential backoff after a 503.

## Concepts You Just Touched

- [Circuit Breaker (2.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#21-circuit-breaker) - the three states: CLOSED, OPEN, HALF_OPEN
- [Bulkhead (2.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#22-bulkhead) - the semaphore limits blast radius to 4 slots
- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - Grad-CAM is the slowest call; its timeout feeds the breaker threshold

## Questions You Should Be Able To Answer

1. The circuit opens after 3 failures. What defines a "failure" in the context of ML inference - a timeout, an exception, or both?
2. Why is the recovery timeout set to 30 seconds? What would you monitor to tune this value?
3. What is the difference between the circuit breaker (macroscopic protection) and the semaphore (microscopic protection)?
4. If the circuit is OPEN and a patient uploads an image, what exactly does the frontend receive and what should it show the user?
5. The `_INFERENCE_BREAKER` is a module-level singleton. What problem does this cause in a multi-worker Uvicorn deployment, and how do you fix it?
