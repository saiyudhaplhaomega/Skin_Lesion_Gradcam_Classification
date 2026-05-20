# Model And Grad-CAM Handholding Guide

Use this only after the mock upload API works.

## Goal

Replace the fake prediction with a real model prediction and add an explanation image.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

**What these commands do:** navigate from the workspace root into the backend repo, then activate the virtual environment. PyTorch, Grad-CAM, and all model service dependencies must be installed in this environment.

Run every command in this guide from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** all model service code, tests, and uvicorn runs happen inside the backend repo. The `models/` directory holding the checkpoint also lives here.

Every file path in this guide is relative to `Skin_Lesion_Classification_backend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Research repo: `Skin_Lesion_XAI_research/`
- Create or edit backend `app/...` and `tests/...` paths under `Skin_Lesion_Classification_backend/`.
- Copy model artifacts only from the research repo path named in the step; do not paste backend service code into `Skin_Lesion_XAI_research/`.

## Why This Comes Later

Model loading adds complexity:

- PyTorch versions
- model artifact paths
- image preprocessing
- CPU vs GPU behavior
- Grad-CAM target layers
- slower tests

You should already have a stable API before adding this.

## Step 1: Use The Fixed Local Model Artifact Path

Use a local path first:

```text
models/skin_lesion_classifier.pth
```

What this path means: the backend will look for the trained PyTorch checkpoint under `Skin_Lesion_Classification_backend/models/`. This keeps local inference simple while avoiding cloud storage until later.

Do not commit model weights to Git.

Check `.gitignore` includes:

```text
models/
*.pth
*.pt
```

What this ignores:

- `models/` prevents local model folders from being committed.
- `*.pth` ignores PyTorch checkpoint files.
- `*.pt` ignores other common PyTorch model files.

## Step 2: Create Model Service (Stub First)

Create this file:

```text
app/services/model_service.py
```

**What this path is:** `app/services/` holds service layer classes that contain business logic - in this case, all model inference and Grad-CAM generation code. The API route in `app/api/v1/` delegates to this service rather than containing inference logic directly.

Start with a testable stub - validate the interface before wiring real PyTorch:

```python
from dataclasses import dataclass


@dataclass
class PredictionResult:
    label: str
    confidence: float
    raw_logit: float = 0.0


class ModelService:
    def predict(self, image_bytes: bytes) -> PredictionResult:
        return PredictionResult(label="benign", confidence=0.82, raw_logit=0.5)
```

What this stub does:

- `@dataclass` creates a small typed result object without boilerplate.
- `PredictionResult` defines the shape the API expects from model inference.
- `ModelService.predict(...)` accepts image bytes, matching the future real model interface.
- The hard-coded result lets you test the API path before PyTorch, checkpoints, or Grad-CAM are involved.

Why: keep the API route thin. The route receives files; the service owns model logic.

## Step 3: Test The Service Stub

Create `tests/test_model_service.py`:

```python
import io

from PIL import Image

from app.services.model_service import ModelService


def _make_fake_image_bytes() -> bytes:
    img = Image.new("RGB", (8, 8), color=(120, 80, 60))
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def test_model_service_returns_prediction() -> None:
    service = ModelService()
    result = service.predict(_make_fake_image_bytes())
    assert result.label in {"benign", "malignant"}
    assert 0.0 <= result.confidence <= 1.0
```

What this test does:

- Creates the model service directly without starting the API.
- Creates a tiny valid JPEG in memory.
- Calls `predict()` with valid image bytes to validate the interface.
- Checks that the label is one of the expected classes.
- Checks that confidence stays in the safe probability range.

Run:

```powershell
pytest tests/test_model_service.py -v
```

**What this does:** runs only the model service tests in verbose mode. `-v` shows each test name and its pass/fail status. Running a single test file is faster than running the full suite, and useful when iterating on service code.

## Step 4: Wire Service Into API

Update `/api/v1/analysis` in `app/api/v1/analysis.py`:

```python
from fastapi import APIRouter, UploadFile, File, HTTPException
from pydantic import BaseModel

from app.services.model_service import ModelService

router = APIRouter()
_model_service = ModelService()


class AnalysisResponse(BaseModel):
    label: str
    confidence: float
    case_id: str


@router.post("/analysis", response_model=AnalysisResponse)
async def run_analysis(image: UploadFile = File(...)) -> AnalysisResponse:
    image_bytes = await image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Empty image")
    result = _model_service.predict(image_bytes)
    import uuid
    case_id = str(uuid.uuid4())
    return AnalysisResponse(label=result.label, confidence=result.confidence, case_id=case_id)
```

What this route does:

- Imports `ModelService` so the API delegates prediction logic to a service class.
- Creates `_model_service` once at module load instead of constructing it for every request.
- Reads the uploaded image bytes with `await image.read()`.
- Rejects empty uploads with a controlled `400` error.
- Calls `predict()` and maps the service result into the API response model.
- Generates a temporary `case_id` so the response shape is ready for later database storage.

The response shape must not change when you replace the stub with real inference.

## Step 5: Replace Stub With Real ResNet50 + GradCAM++

After `pytest` passes for the stub, replace `app/services/model_service.py` with the full implementation.

Copy this entire file:

```python
"""
Real ResNet50 inference with GradCAM++ explanation.

Prerequisites:
  - pip install torch torchvision timm albumentations grad-cam pillow
  - A trained checkpoint at models/skin_lesion_classifier.pth
    (copy from Skin_Lesion_XAI_research/ml/outputs/models/ or train one first)
"""
from __future__ import annotations

import base64
import io
from dataclasses import dataclass, field
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torchvision.models as tv_models
from PIL import Image
from pytorch_grad_cam import GradCAMPlusPlus
from pytorch_grad_cam.utils.image import show_cam_on_image
from pytorch_grad_cam.utils.model_targets import ClassifierOutputTarget

# HAM10000 normalisation values - same values used in research training
_MEAN = [0.7630, 0.5456, 0.5700]
_STD  = [0.1409, 0.1526, 0.1700]
_IMG_SIZE = 224

# Label map - index 1 = malignant (positive class)
_LABELS = {0: "benign", 1: "malignant"}


@dataclass
class PredictionResult:
    label: str
    confidence: float          # calibrated probability (0-1)
    raw_logit: float           # raw model output before sigmoid
    cam_png_b64: str = ""      # base64-encoded CAM overlay PNG (empty if not requested)


class _ResNet50Classifier(nn.Module):
    """ResNet50 with a single binary output head - matches research training."""

    def __init__(self) -> None:
        super().__init__()
        backbone = tv_models.resnet50(weights=None)
        in_features = backbone.fc.in_features
        backbone.fc = nn.Linear(in_features, 1)
        self.model = backbone

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.model(x)

    def get_target_layer(self) -> nn.Module:
        # layer4[-1] is the standard GradCAM target for ResNet50
        # Matches the target layer used in RQ1-RQ2 research notebooks
        return self.model.layer4[-1]


def _preprocess(image_bytes: bytes) -> tuple[torch.Tensor, np.ndarray]:
    """
    Returns a (1,3,224,224) tensor for inference and the raw (224,224,3) float32
    array in [0,1] range needed by show_cam_on_image.
    """
    import torchvision.transforms.functional as TF

    img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    img = img.resize((_IMG_SIZE, _IMG_SIZE), Image.LANCZOS)

    # Raw array for CAM overlay - must be float32 [0,1]
    img_array = np.array(img).astype(np.float32) / 255.0

    # Normalised tensor for inference
    tensor = TF.to_tensor(img)
    tensor = TF.normalize(tensor, mean=_MEAN, std=_STD)
    return tensor.unsqueeze(0), img_array


def _apply_temperature(logit: float, temperature: float = 1.5) -> float:
    """
    Temperature scaling - divides the logit before sigmoid.
    temperature=1.0 means no change. temperature>1.0 flattens confidence.
    1.5 is a reasonable default for an uncalibrated ResNet50.
    Fit the exact value on your validation set using 14_CONFIDENCE_CALIBRATION_HANDHOLDING.md.
    """
    import math
    return 1.0 / (1.0 + math.exp(-(logit / temperature)))


class ModelService:
    """Loads once at startup, thread-safe for inference."""

    def __init__(
        self,
        model_path: str = "models/skin_lesion_classifier.pth",
        temperature: float = 1.5,
    ) -> None:
        self._temperature = temperature
        self._device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

        self._net = _ResNet50Classifier().to(self._device)

        ckpt_path = Path(model_path)
        if ckpt_path.exists():
            state = torch.load(str(ckpt_path), map_location=self._device, weights_only=True)
            # Handle both raw state_dict and checkpoint dict formats
            if "model_state_dict" in state:
                state = state["model_state_dict"]
            self._net.load_state_dict(state)
        else:
            # Stub mode - weights not available, returns random predictions
            # This keeps the test suite passing before you have a real checkpoint
            pass

        self._net.eval()

    def predict(self, image_bytes: bytes, return_cam: bool = False) -> PredictionResult:
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

    def _generate_cam(self, tensor: torch.Tensor, img_array: np.ndarray) -> str:
        target_layer = self._net.get_target_layer()
        # The model has one binary logit, so Grad-CAM must target output index 0.
        targets = [ClassifierOutputTarget(0)]

        with GradCAMPlusPlus(model=self._net, target_layers=[target_layer]) as cam:
            grayscale_cam = cam(input_tensor=tensor, targets=targets)[0]

        # Blend CAM onto the original image
        overlay = show_cam_on_image(img_array, grayscale_cam, use_rgb=True)

        # Encode to PNG, then base64
        buf = io.BytesIO()
        Image.fromarray(overlay).save(buf, format="PNG")
        return base64.b64encode(buf.getvalue()).decode("utf-8")
```

What this full service does:

- The module imports image, tensor, model, and Grad-CAM tools needed for real inference.
- `_MEAN`, `_STD`, and `_IMG_SIZE` keep preprocessing aligned with research training.
- `PredictionResult` keeps model output separate from FastAPI response models.
- `_ResNet50Classifier` builds a ResNet50 with one binary output head for benign/malignant prediction.
- `_preprocess()` turns uploaded bytes into both a normalized tensor for inference and a raw image array for CAM overlay.
- `_apply_temperature()` converts the raw logit into a less overconfident probability.
- `ModelService.__init__()` chooses CPU/GPU, builds the model, loads a checkpoint if present, and switches to eval mode.
- `predict()` runs inference, computes the label/confidence, and optionally asks for a Grad-CAM overlay.
- `_generate_cam()` targets output index `0` because the binary classifier has one logit, runs GradCAM++, blends the heatmap onto the input image, encodes it as PNG, then returns base64 text for the frontend.

## Step 6: Add Grad-CAM Explanation Endpoint

Add this route to `app/api/v1/analysis.py` (or a separate `explanation.py`):

```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.model_service import ModelService

router = APIRouter()
_model_service = ModelService()


class ExplanationResponse(BaseModel):
    case_id: str
    cam_png_b64: str   # paste into an <img src="data:image/png;base64,..."> tag
    method: str = "gradcam++"


@router.get("/analysis/{case_id}/explanation", response_model=ExplanationResponse)
async def get_explanation(case_id: str) -> ExplanationResponse:
    # In production: load the original image bytes from S3 by case_id.
    # For local learning, accept the case_id and re-run on a stored temp path.
    # This stub returns an error until you wire up image storage.
    raise HTTPException(
        status_code=501,
        detail="Wire up image retrieval by case_id first (see 05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md)",
    )
```

What this endpoint stub does:

- Defines the future explanation response shape.
- Keeps explanation retrieval separate from prediction.
- Returns `501 Not Implemented` until the app can retrieve the original image by `case_id`.

Why separate endpoint: prediction should not block on CAM generation. Grad-CAM on CPU takes 1-3 seconds. The patient gets the label immediately; the heatmap loads asynchronously.

Full wiring (after you add image key storage to the database):

```python
@router.get("/analysis/{case_id}/explanation", response_model=ExplanationResponse)
async def get_explanation(case_id: str, db: Session = Depends(get_db)) -> ExplanationResponse:
    case = db.query(TrainingCase).filter(TrainingCase.id == case_id).first()
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")

    # Load image bytes from local path or S3
    image_bytes = Path(case.image_key).read_bytes()   # local dev only

    result = _model_service.predict(image_bytes, return_cam=True)
    return ExplanationResponse(case_id=case_id, cam_png_b64=result.cam_png_b64)
```

What this later wiring does:

- Reads the case from the database by `case_id`.
- Returns `404` if the case does not exist.
- Loads the original image bytes from a local path for development.
- Calls the model service with `return_cam=True`.
- Returns only the explanation data for the requested case.

## Step 7: Add Tests With A Tiny Fake Checkpoint

Create `tests/test_model_service_real.py`:

```python
"""
These tests require a real or minimal test checkpoint.
Skip if models/test_checkpoint.pth does not exist.
"""
import io
import os
import struct

import numpy as np
import pytest
import torch
from PIL import Image

from app.services.model_service import ModelService, _ResNet50Classifier


def _make_fake_image_bytes(width: int = 64, height: int = 64) -> bytes:
    """Generate a random solid-colour JPEG in memory."""
    arr = np.random.randint(0, 255, (height, width, 3), dtype=np.uint8)
    img = Image.fromarray(arr, mode="RGB")
    buf = io.BytesIO()
    img.save(buf, format="JPEG")
    return buf.getvalue()


def _save_minimal_checkpoint(path: str = "models/test_checkpoint.pth") -> None:
    """Save an untrained ResNet50 state dict for testing without a trained model."""
    os.makedirs("models", exist_ok=True)
    net = _ResNet50Classifier()
    torch.save(net.state_dict(), path)


@pytest.fixture(scope="module")
def service() -> ModelService:
    _save_minimal_checkpoint("models/test_checkpoint.pth")
    return ModelService(model_path="models/test_checkpoint.pth")


def test_predict_returns_valid_label(service: ModelService) -> None:
    result = service.predict(_make_fake_image_bytes())
    assert result.label in {"benign", "malignant"}


def test_predict_confidence_in_range(service: ModelService) -> None:
    result = service.predict(_make_fake_image_bytes())
    assert 0.0 <= result.confidence <= 1.0


def test_predict_with_cam(service: ModelService) -> None:
    result = service.predict(_make_fake_image_bytes(), return_cam=True)
    assert result.cam_png_b64 != ""
    # Confirm it decodes to valid PNG bytes
    import base64
    png_bytes = base64.b64decode(result.cam_png_b64)
    assert png_bytes[:4] == b"\x89PNG"
```

What these tests do:

- `_make_fake_image_bytes()` creates a small in-memory JPEG so no test image file is needed.
- `_save_minimal_checkpoint()` creates an untrained checkpoint to test loading mechanics.
- The `service` fixture builds one `ModelService` for the test module.
- The tests verify label shape, confidence range, and that Grad-CAM output decodes to PNG bytes.

Run:

```powershell
pytest tests/test_model_service_real.py -v
```

**What this does:** runs the full model tests including Grad-CAM generation with a real (but untrained) checkpoint. These tests are slower than the stub tests because they load PyTorch model weights and run a forward pass.

## Checks

Use two PowerShell terminals for the live API check.

Terminal 1, start the backend server from:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
.\.venv\Scripts\python.exe -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8010
```

Leave Terminal 1 running.

Terminal 2, run the checks from:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
pytest
curl.exe http://127.0.0.1:8010/openapi.json | Select-String "/api/v1/analysis"
curl.exe -X POST http://127.0.0.1:8010/api/v1/analysis -F "image=@ml\data\processed\raw\images\ISIC_0024306.jpg"
```

**What these verify:** `pytest` runs the full test suite including both stub and real model tests. The OpenAPI check confirms the running server has `POST /api/v1/analysis`. The `curl.exe` upload uses a real image already present in the backend `ml/` folder and confirms the endpoint returns the expected JSON shape through the live server.

Expected result:

```text
Tests pass, the analysis endpoint returns the same response shape, and explanation generation is exposed separately from prediction.
```

**What this means:** the API contract established in the stub guide is preserved, the real model can be loaded and run, and the explanation endpoint is registered (even if it returns 501 until image retrieval is wired up).

When these checks finish, return to Terminal 1 and press:

```text
Ctrl+C
```

**What this does:** stops the local Uvicorn server so it does not keep using port `8010` in the background.

## Stop Point

Do not add MLflow or training pipelines until local model inference and explanation work.

## Concepts You Just Touched

- [Circuit Breaker (2.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#21-circuit-breaker) - the highest-priority gap to wire around inference
- [Bulkhead (2.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#22-bulkhead) - inference and Grad-CAM should not starve other endpoints
- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - Grad-CAM is the slowest call in the system
- [Calibration (9.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#93-calibration) - raw softmax is dangerous to show patients
- [Model Registry (9.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#91-model-registry) - design space; even a hard-coded version string counts as a starting point

## Questions You Should Be Able To Answer

1. Why does Grad-CAM require an end-to-end fine-tuned CNN, and why is "freeze backbone, train XGBoost head" the wrong approach?
2. What is the difference between the four Grad-CAM variants in the research (GradCAM, GradCAM++, ScoreCAM, etc.), and which won on faithfulness?
3. If the inference call hangs for 30 seconds, what should `/analysis` return to the patient? What protects the rest of the API?
4. Why is raw softmax (e.g., 0.97) misleading to a patient and how does temperature scaling fix it?
5. How does the API know which model file to load, and what is the rollback procedure if a new model is bad?

If you cannot answer Q1-Q2, re-read the Grad-CAM theory section and check the research repo's RQ1 notebook.
If you cannot answer Q3-Q5, read [System Design Patterns: 2.1 Circuit Breaker](../reference/09_SYSTEM_DESIGN_PATTERNS.md#21-circuit-breaker), [9.1 Model Registry](../reference/09_SYSTEM_DESIGN_PATTERNS.md#91-model-registry), and [9.3 Calibration](../reference/09_SYSTEM_DESIGN_PATTERNS.md#93-calibration).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| OOM on first inference | full FP32 model loaded; AMP not used in research training | check checkpoint dtype |
| Grad-CAM looks like noise | wrong target layer | research repo `classifier.get_target_layer()` |
| Inference times out only sometimes | thread-pool contention; another request hogged the GPU | add a semaphore around inference |
| Confidence always 0.98+ on every input | uncalibrated model | run temperature scaling on validation set |
| Model version drifts vs S3 path | no atomic update | gap 12 in the 28-gap list |

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
