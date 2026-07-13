# Research, Fairness, Calibration, Active Learning, And Observability Handholding Guide

Use this after analysis events, model version tracking, consent, and doctor review exist.

## Goal

Build research, fairness, calibration, active learning queues, and observability dashboards that help researchers and admins monitor model performance without exposing raw patient data.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- This guide touches backend, research, and frontend repositories, so start from the shared parent folder.

This guide uses:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_XAI_research
Skin_Lesion_Classification_frontend
```

What this repo list means:
- `Skin_Lesion_Classification_backend` exposes metrics and services.
- `Skin_Lesion_XAI_research` contains notebooks and training analysis.
- `Skin_Lesion_Classification_frontend` displays dashboard data.

## Step 1: Confidence Calibration And Uncertainty

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The calibration service and metrics API in this step belong in the backend repository.

The temperature scaling calibration is fitted in the research repo (see `docs/local-dev/14_CONFIDENCE_CALIBRATION_HANDHOLDING.md`). This service exposes the fitted result for the API and patient UI.

Create `app/services/calibration_service.py`:

```python
"""
Converts raw model confidence to patient-safe categorical labels and
a reliability band for the explanation endpoint.
Temperature is fitted offline (see local-dev/14_CONFIDENCE_CALIBRATION_HANDHOLDING.md).
"""
from __future__ import annotations

import math
from dataclasses import dataclass

# Update this after every retraining run (refit temperature on validation set)
_TEMPERATURE: float = 1.6842


@dataclass
class CalibratedResult:
    raw_confidence: float
    calibrated_confidence: float
    patient_label: str    # plain-language label for patient UI
    reliability_note: str
    show_to_patient: bool


def calibrate(raw_logit: float, image_quality_ok: bool = True) -> CalibratedResult:
    calibrated = 1.0 / (1.0 + math.exp(-(raw_logit / _TEMPERATURE)))

    if not image_quality_ok:
        return CalibratedResult(
            raw_confidence=round(1.0 / (1.0 + math.exp(-raw_logit)), 4),
            calibrated_confidence=round(calibrated, 4),
            patient_label="Image quality insufficient for reliable analysis",
            reliability_note="Please retake the image and try again.",
            show_to_patient=True,
        )

    if calibrated < 0.40:
        label = "The model found patterns more consistent with benign lesions."
    elif calibrated < 0.55:
        label = "The model result is uncertain. Professional review is recommended."
    elif calibrated < 0.75:
        label = "The model found some patterns that may warrant follow-up with a clinician."
    else:
        label = "The model found patterns that recommend professional clinical review."

    return CalibratedResult(
        raw_confidence=round(1.0 / (1.0 + math.exp(-raw_logit)), 4),
        calibrated_confidence=round(calibrated, 4),
        patient_label=label,
        reliability_note="This is educational information only. Please consult a qualified clinician.",
        show_to_patient=True,
    )
```

What this calibration code does:
- The docstring explains that the service turns raw model output into patient-safe labels and reliability notes.
- `from __future__ import annotations` improves type-hint handling.
- `math` is imported for the exponential function used in sigmoid conversion.
- `dataclass` is used to define a lightweight result object.
- `_TEMPERATURE` stores the fitted temperature-scaling value from validation data.
- `CalibratedResult` defines the structured output of calibration.
- `raw_confidence` stores the original sigmoid confidence.
- `calibrated_confidence` stores the temperature-scaled confidence.
- `patient_label` is the plain-language message shown in the UI.
- `reliability_note` explains limitations and next steps.
- `show_to_patient` lets the app decide whether the result is safe to display.
- `calibrate` accepts a raw model logit and an image-quality flag.
- `calibrated = 1.0 / (1.0 + math.exp(...))` applies sigmoid after temperature scaling.
- If image quality is poor, the function returns a retake message instead of normal risk wording.
- The threshold blocks map calibrated confidence into conservative patient-facing categories.
- The final return always includes the educational disclaimer and does not make a diagnosis.

Add a metrics endpoint for the research dashboard. Create `app/api/v1/research_metrics.py`:

```python
from __future__ import annotations

import os

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.prediction import Prediction
from app.models.training_case import TrainingCase, TrainingCaseStatus

router = APIRouter(prefix="/api/v1/research", tags=["research"])


# --- Step 1: Dataset counts ---

class DatasetMetrics(BaseModel):
    total_approved: int
    total_rejected: int
    total_pending: int
    model_version: str


@router.get("/metrics/dataset", response_model=DatasetMetrics)
def dataset_metrics(db: Session = Depends(get_db)) -> DatasetMetrics:
    """Return training-case counts by status. All counts are aggregate — no patient data exposed."""
    approved = db.query(TrainingCase).filter(
        TrainingCase.status == TrainingCaseStatus.admin_approved
    ).count()
    rejected = db.query(TrainingCase).filter(
        TrainingCase.status == TrainingCaseStatus.rejected
    ).count()
    pending = db.query(TrainingCase).filter(
        TrainingCase.status.in_([
            TrainingCaseStatus.uploaded,
            TrainingCaseStatus.patient_consented,
            TrainingCaseStatus.doctor_validated,
        ])
    ).count()
    return DatasetMetrics(
        total_approved=approved,
        total_rejected=rejected,
        total_pending=pending,
        model_version=os.environ.get("MODEL_VERSION", "model-v001"),
    )


# --- Step 2: Model performance metrics (stub) ---

class ModelPerformanceMetrics(BaseModel):
    model_version: str
    total_predictions: int
    accuracy: float | None = None
    sensitivity: float | None = None
    specificity: float | None = None
    false_positive_rate: float | None = None
    false_negative_rate: float | None = None
    mean_calibrated_confidence: float | None = None
    note: str = "Performance metrics require evaluation pipeline. See docs/product/12_."


@router.get("/metrics/performance", response_model=ModelPerformanceMetrics)
def model_performance_metrics(
    model_version: str | None = None,
    db: Session = Depends(get_db),
) -> ModelPerformanceMetrics:
    """
    Return model performance metrics. Currently returns prediction count only.
    Accuracy, sensitivity, specificity, and calibration are populated by the
    offline evaluation pipeline (TODO: wire evaluation results table).
    """
    query = db.query(Prediction)
    if model_version:
        query = query.filter(Prediction.model_version == model_version)
    total = query.count()
    return ModelPerformanceMetrics(
        model_version=model_version or os.environ.get("MODEL_VERSION", "model-v001"),
        total_predictions=total,
    )


# --- Step 5: Active learning queue (stub) ---

class ActiveLearningCase(BaseModel):
    prediction_id: str
    model_version: str
    reason: str   # "high_uncertainty" | "rare_pattern" | "edge_case"
    calibrated_confidence: float | None


class ActiveLearningQueue(BaseModel):
    cases: list[ActiveLearningCase]
    uncertainty_threshold: float
    note: str = "Active learning selection requires uncertainty scoring. See docs/product/12_."


@router.get("/active-learning/queue", response_model=ActiveLearningQueue)
def active_learning_queue(
    uncertainty_threshold: float = 0.55,
    limit: int = 50,
    db: Session = Depends(get_db),
) -> ActiveLearningQueue:
    """
    Return predictions in the high-uncertainty band for doctor/research review.
    Full active learning pipeline (diversity sampling, rare pattern detection) is a TODO.
    """
    uncertain_preds = (
        db.query(Prediction)
        .filter(Prediction.confidence >= 0.40, Prediction.confidence <= uncertainty_threshold)
        .order_by(Prediction.created_at.desc())
        .limit(limit)
        .all()
    )
    cases = [
        ActiveLearningCase(
            prediction_id=str(p.id),
            model_version=p.model_version,
            reason="high_uncertainty",
            calibrated_confidence=p.confidence,
        )
        for p in uncertain_preds
    ]
    return ActiveLearningQueue(cases=cases, uncertainty_threshold=uncertainty_threshold)
```

What this metrics API code does:
- `import os` is required for `os.environ.get("MODEL_VERSION", ...)` — the original doc omitted this.
- `router = APIRouter(...)` places all research routes under `/api/v1/research`.
- `dataset_metrics` returns approved/rejected/pending training case counts from the database.
- `model_performance_metrics` is a stub that returns prediction count. Accuracy, sensitivity, specificity, and calibration fields are `None` until an evaluation pipeline writes results.
- `active_learning_queue` selects predictions in the uncertainty band (confidence 0.40–0.55 by default) as a proxy for high uncertainty. Full diversity sampling and rare-pattern detection are future work.
- No patient identifiers are returned from any endpoint.

Register in `app/main.py`:

```python
from app.api.v1 import research_metrics
app.include_router(research_metrics.router)
```

What this code does:
- The import loads the research metrics route module.
- `app.include_router(research_metrics.router)` attaches the research routes to FastAPI.

Check:

```powershell
cd Skin_Lesion_Classification_backend
pytest
curl http://localhost:8000/api/v1/research/metrics/dataset
```

What this command block does:
- `cd Skin_Lesion_Classification_backend` enters the backend repo.
- `pytest` runs backend tests.
- `curl` calls the local research dataset metrics endpoint and requires the backend server to be running.

## Step 2: Model Performance Dashboard Data

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Model performance data aggregation belongs in the backend.

The `GET /api/v1/research/metrics/performance` endpoint in `research_metrics.py` (Step 1) is the
stub for this step. It currently returns total prediction count. The following fields will be
populated once an offline evaluation pipeline writes results to a `model_evaluation_results` table:

```text
accuracy               — overall correct / total
sensitivity            — true positive rate (recall for malignant class)
specificity            — true negative rate
false_positive_rate    — FP / (FP + TN)
false_negative_rate    — FN / (FN + TP)
mean_calibrated_confidence — mean predicted probability on test set
```

Fairness breakdown dimensions to track per model version:

```text
performance by skin tone category (requires consent + ethics review)
performance by body region
performance by image quality band (ok / blur / dark / glare)
performance by lighting condition
performance by device / camera type
```

What this metrics list means:
- Accuracy, sensitivity, specificity, and error counts describe overall performance.
- Calibration measures how well model confidence matches actual outcomes.
- Skin tone, body region, image quality, and device breakdowns help detect reliability gaps.
- Fairness breakdown by skin tone requires explicit metadata consent and ethical review before use.

TODO: Create `app/models/model_evaluation_result.py` with a `model_version`, `metric_name`,
`metric_value`, `group_name`, `group_value`, and `evaluated_at` table. Populate it from the
research repo evaluation pipeline, then update the performance endpoint to query it.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify metric aggregation and permission behavior.

## Step 3: Fairness Evaluation

Current repo:

```text
Skin_Lesion_XAI_research
```

What this block means:
- Fairness notebooks or scripts belong in the research repository.

The starter notebook exists at:

```text
Skin_Lesion_XAI_research/notebooks/fairness_evaluation.ipynb
```

What this path block means:
- The notebook is a runnable skeleton. It loads an evaluation CSV export, computes per-group
  accuracy/sensitivity/specificity/AUC, plots reliability diagrams, and flags groups with an
  accuracy gap above a configurable threshold.
- Replace `DATA_PATH` in the notebook with your de-identified evaluation export path.

The notebook evaluates these optional metadata dimensions:

```text
image_quality     — ok / blur / dark / glare (no consent required)
body_region       — location metadata (no consent required if de-identified)
skin_tone_category — only if consent + ethics review allow
lighting_condition — no consent required if de-identified
camera_type       — no consent required if de-identified
```

What this metadata block means:
- Each column in the evaluation CSV maps to one fairness dimension.
- The notebook skips columns that are missing and skips groups with fewer than 5 samples.
- Skin tone analysis is gated behind a comment warning — only run that cell with ethical clearance.

Important rule:

```text
The goal is measuring model reliability across diverse groups, not profiling users.
```

What this rule block means:
- Fairness evaluation should identify model reliability gaps.
- It must not be used to profile or rank individual users.
- The gap report cell flags groups more than 5 percentage points below overall accuracy.

Check:

```powershell
cd ..\Skin_Lesion_XAI_research
jupyter nbconvert --to notebook --execute notebooks/fairness_evaluation.ipynb --output notebooks/fairness_evaluation_out.ipynb
```

What this command block does:
- Executes the notebook non-interactively and saves output to a separate file.
- Requires the evaluation CSV export at the configured path.
- Use `make help` to see available research repo commands.

## Step 4: Dataset And Training Dashboard

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means:
- Backend provides dataset metrics via `GET /api/v1/research/metrics/dataset`.
- Frontend displays dataset and active learning dashboard views.

Update `app/research/page.tsx` (replace stub):

```tsx
import type { Metadata } from "next";
import { ResearchDatasetPanel } from "@/components/research/ResearchDatasetPanel";
import { ActiveLearningPanel } from "@/components/research/ActiveLearningPanel";

export const metadata: Metadata = {
  title: "Research Dashboard",
  robots: { index: false, follow: false },
};

export default function ResearchPage() {
  return (
    <main className="dashboard-shell">
      <section className="dashboard-header">
        <p className="eyebrow">Research</p>
        <h1>Research &amp; Fairness Dashboard</h1>
        <p>Aggregate metrics only. No patient identifiers are displayed here.</p>
      </section>
      <section className="dashboard-section">
        <ResearchDatasetPanel />
      </section>
      <section className="dashboard-section">
        <ActiveLearningPanel />
      </section>
    </main>
  );
}
```

Create `components/research/ResearchDatasetPanel.tsx`:

```tsx
"use client";
import { useEffect, useState } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

interface DatasetMetrics {
  total_approved: number;
  total_rejected: number;
  total_pending: number;
  model_version: string;
}

export function ResearchDatasetPanel() {
  const [data, setData] = useState<DatasetMetrics | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch(`${API_BASE}/api/v1/research/metrics/dataset`)
      .then((r) => { if (!r.ok) throw new Error(`${r.status}`); return r.json() as Promise<DatasetMetrics>; })
      .then(setData)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading dataset metrics…</p>;
  if (error) return <p className="error-msg">Could not load metrics: {error}</p>;
  if (!data) return null;

  return (
    <div className="card">
      <h2>Training Dataset</h2>
      <p className="caption">Model version: <strong>{data.model_version}</strong></p>
      <div className="stat-grid">
        <div className="stat">
          <span className="stat-value">{data.total_approved}</span>
          <span className="stat-label">Approved</span>
        </div>
        <div className="stat">
          <span className="stat-value">{data.total_pending}</span>
          <span className="stat-label">Pending review</span>
        </div>
        <div className="stat">
          <span className="stat-value">{data.total_rejected}</span>
          <span className="stat-label">Rejected</span>
        </div>
      </div>
    </div>
  );
}
```

Create `components/research/ActiveLearningPanel.tsx`:

```tsx
"use client";
import { useEffect, useState } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

interface ActiveLearningCase {
  prediction_id: string;
  model_version: string;
  reason: string;
  calibrated_confidence: number | null;
}

interface ActiveLearningQueue {
  cases: ActiveLearningCase[];
  uncertainty_threshold: number;
  note: string;
}

export function ActiveLearningPanel() {
  const [data, setData] = useState<ActiveLearningQueue | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch(`${API_BASE}/api/v1/research/active-learning/queue`)
      .then((r) => { if (!r.ok) throw new Error(`${r.status}`); return r.json() as Promise<ActiveLearningQueue>; })
      .then(setData)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading active learning queue…</p>;
  if (error) return <p className="error-msg">Could not load queue: {error}</p>;
  if (!data) return null;

  return (
    <div className="card">
      <h2>Active Learning Queue</h2>
      <p className="caption">
        Cases flagged for review (uncertainty threshold: {(data.uncertainty_threshold * 100).toFixed(0)}%).
      </p>
      {data.note && <p className="info-msg">{data.note}</p>}
      {data.cases.length === 0 ? (
        <p>No cases in the active learning queue.</p>
      ) : (
        <table className="data-table">
          <thead>
            <tr><th>Prediction ID</th><th>Model</th><th>Reason</th><th>Confidence</th></tr>
          </thead>
          <tbody>
            {data.cases.map((c) => (
              <tr key={c.prediction_id}>
                <td className="mono">{c.prediction_id.slice(0, 8)}…</td>
                <td>{c.model_version}</td>
                <td>{c.reason}</td>
                <td>{c.calibrated_confidence != null ? `${(c.calibrated_confidence * 100).toFixed(1)}%` : "—"}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
```

Dashboard fields covered:

```text
approved training images    — ResearchDatasetPanel: total_approved
pending review count        — ResearchDatasetPanel: total_pending
rejected images             — ResearchDatasetPanel: total_rejected
model version               — ResearchDatasetPanel: model_version
active learning queue       — ActiveLearningPanel: high-uncertainty predictions
```

What this dashboard-field block means:
- Class balance, body-region distribution, image-quality distribution, and model performance over
  time are future panels — they require the evaluation pipeline from Step 2.
- All data shown is aggregate only. No patient identifiers are displayed.

Check:

```powershell
cd ..\Skin_Lesion_Classification_frontend
npm run type-check
npm run build
```

What this command block does:
- `npm run type-check` verifies TypeScript types.
- `npm run build` runs the Next.js production build.

## Step 5: Active Learning

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Active learning selection logic belongs in the backend.

The `GET /api/v1/research/active-learning/queue` endpoint in `research_metrics.py` is the stub
for this step. It currently selects predictions in the uncertainty band (confidence 0.40–0.55).

Selection criteria and their current implementation status:

```text
high uncertainty          — IMPLEMENTED (confidence in uncertainty band, query parameter)
rare lesion pattern       — TODO (requires minority class or low-frequency label detection)
model disagreement        — TODO (requires multiple model version predictions on same image)
poorly represented region — TODO (requires body region metadata on Prediction model)
edge case                 — TODO (requires uncertainty scoring pipeline, e.g. MC Dropout)
```

To extend the active learning queue when the TODO items are ready:
- Add `body_region` and `image_quality` to `app/models/prediction.py`
- Add a `uncertainty_score` field (e.g. entropy from MC Dropout forward passes)
- Update the queue endpoint to combine uncertainty + rarity + body-region underrepresentation

Check:

```powershell
cd ..\Skin_Lesion_Classification_backend
make test
```

What this command block does:
- `cd ..\Skin_Lesion_Classification_backend` returns to the backend repo.
- `make test` should verify active learning queue endpoint and selection behavior.

## Step 6: Observability

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Observability metrics and instrumentation belong in the backend.

The existing `app/services/observability_service.py` wires OTel and LangSmith tracing. The
metrics below are the next layer — named counters and histograms for operational health.

Add named metrics to `app/observability/metrics.py` (create if missing):

```python
"""
Named observability metrics for operational health monitoring.
Wire these into the relevant service or route using your OTel meter.

Every metric must have: name, unit, description, owner, and reason.
"""
from opentelemetry import metrics

meter = metrics.get_meter("skin_lesion_api")

# API latency — wire as histogram in route middleware
api_latency_ms = meter.create_histogram(
    name="api.request.duration_ms",
    description="End-to-end API request latency",
    unit="ms",
)

# Model inference time — wire in model_inference_service.py
model_inference_ms = meter.create_histogram(
    name="model.inference.duration_ms",
    description="Time from image pre-processing to logit output",
    unit="ms",
)

# Grad-CAM generation time — wire in gradcam_service.py
gradcam_ms = meter.create_histogram(
    name="gradcam.generation.duration_ms",
    description="Time to generate Grad-CAM heatmap",
    unit="ms",
)

# Failed uploads — increment in the upload route on error
failed_uploads_total = meter.create_counter(
    name="upload.failed.total",
    description="Number of image uploads that failed validation or storage",
)

# Poor image quality — increment in image_quality_service.py when quality check fails
poor_quality_total = meter.create_counter(
    name="image.quality.poor.total",
    description="Number of images rejected by the quality check",
)

# LLM safety failures — increment in llm_safety_validator_service.py on block
llm_safety_failures_total = meter.create_counter(
    name="llm.safety.failure.total",
    description="Number of LLM outputs blocked by the safety validator",
)

# Doctor review queue size — read from DB in a background task or metrics scrape
doctor_review_queue_size = meter.create_observable_gauge(
    name="doctor_review.queue.size",
    description="Number of cases awaiting doctor review",
    callbacks=[],  # TODO: wire a callback that queries DoctorReview.pending count
)
```

What this metrics code does:
- `meter = metrics.get_meter(...)` creates a named OTel meter for this service.
- Each metric has a name, unit, and description — required before production.
- Histograms (`create_histogram`) record distributions like latency.
- Counters (`create_counter`) record monotonically increasing event counts.
- `create_observable_gauge` reads a current value on scrape — wire the doctor review queue callback to query the database.
- Wire each metric into the relevant service by calling `.record(value)` (histogram) or `.add(1)` (counter) at the appropriate point.

Metric ownership table (fill this in before production):

```text
api.request.duration_ms          — owner: backend team, reason: SLA tracking
model.inference.duration_ms      — owner: ML team, reason: latency budget
gradcam.generation.duration_ms   — owner: ML team, reason: Grad-CAM cost
upload.failed.total              — owner: backend team, reason: error rate alerting
image.quality.poor.total         — owner: ML team, reason: data quality monitoring
llm.safety.failure.total         — owner: AI safety, reason: safety regression detection
doctor_review.queue.size         — owner: product, reason: workflow health
```

Check:

```powershell
make test
```

What this command does:
- `make test` should verify observability code does not break backend behavior.

Expected result: every metric has a name, owner, and reason before production deployment.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What these commands do:
- `make cloud-status ENV=dev` checks development cloud resources.
- `make cloud-pause ENV=dev` pauses supported resources to reduce cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally shuts down or destroys development resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What these commands do:
- `make cloud-start ENV=dev` starts the development cloud environment again.
- `make cloud-status ENV=dev` confirms it is available before continuing.

If this guide was local-only, no cloud shutdown is needed.
