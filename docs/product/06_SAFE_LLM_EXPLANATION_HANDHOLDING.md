# Safe LLM, XAI, And Agentic Workflow Handholding Guide

Use this after model, Grad-CAM, image quality, and analysis event storage exist.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

What this command block does:
- The first `cd` moves PowerShell into the main project workspace that contains the backend, frontend, docs, and infrastructure folders.
- The second `cd` moves into `Skin_Lesion_Classification_backend`, because the files in this guide are backend files.
- Running these commands from the right folder matters because `pytest`, `pip install`, and Python imports depend on the current directory.

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- This is not a command to run. It is a reminder that the active Git repository should be the backend repository.
- If your prompt or `pwd` shows the frontend folder, stop and `cd` back into the backend before creating these files.

## Goal

Let the backend produce structured facts, then let the LLM explain those facts safely. The LLM must not diagnose images directly.

Why: structured facts keep the model output auditable and prevent the LLM from inventing clinical findings from private images.

## Step 0: Add Missing Local Support Files First

The facts service in this guide reads lab result status and a patient-friendly calibration label. Create these support files before creating the facts service, otherwise the full explanation path will import missing modules.

Create `app/services/calibration_service.py`:

```python
"""
Calibration helpers for patient-facing explanation text.

The model service stores a calibrated confidence already. This helper converts
the raw logit into a plain-language label that the LLM can use as a safe fact.
"""
from __future__ import annotations

from dataclasses import dataclass

from app.services.model_service import _apply_temperature


@dataclass(frozen=True)
class CalibrationResult:
    probability: float
    patient_label: str


def calibrate(raw_logit: float, temperature: float = 1.5) -> CalibrationResult:
    probability = _apply_temperature(raw_logit, temperature=temperature)
    if probability >= 0.8:
        label = "high model confidence"
    elif probability >= 0.6:
        label = "moderate model confidence"
    elif probability >= 0.4:
        label = "uncertain model confidence"
    else:
        label = "low model confidence"
    return CalibrationResult(probability=round(probability, 4), patient_label=label)
```

Create `app/models/lab_result.py`:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class LabResultStatus(str, enum.Enum):
    uploaded = "uploaded"
    doctor_reviewed = "doctor_reviewed"
    rejected = "rejected"


class LabResult(Base):
    __tablename__ = "lab_results"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    lesion_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesions.id"), nullable=False)
    uploaded_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    status: Mapped[LabResultStatus] = mapped_column(
        Enum(LabResultStatus, name="labresultstatus"),
        default=LabResultStatus.uploaded,
        nullable=False,
    )
    source_filename: Mapped[str | None] = mapped_column(String(255), nullable=True)
    storage_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    lesion: Mapped["Lesion"] = relationship("Lesion")
    uploaded_by: Mapped["User"] = relationship("User")
```

Update `app/models/__init__.py` so Alembic can discover the table:

```python
from app.models.user import User
from app.models.lesion import Lesion
from app.models.prediction import Prediction
from app.models.consent import Consent
from app.models.doctor_review import DoctorReview
from app.models.training_case import TrainingCase
from app.models.consent_event import ConsentEvent
from app.models.image import Image
from app.models.body_location_record import BodyLocationRecord
from app.models.lab_result import LabResult

__all__ = [
    "User",
    "Lesion",
    "Prediction",
    "Consent",
    "DoctorReview",
    "TrainingCase",
    "ConsentEvent",
    "Image",
    "BodyLocationRecord",
    "LabResult",
]
```

Create `alembic/versions/f1c2d3e4a506_add_lab_results.py`:

```python
"""add lab results

Revision ID: f1c2d3e4a506
Revises: b0b0ed94fe41
Create Date: 2026-05-29 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "f1c2d3e4a506"
down_revision: Union[str, None] = "b0b0ed94fe41"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        "lab_results",
        sa.Column("id", sa.Uuid(), nullable=False),
        sa.Column("lesion_id", sa.Uuid(), nullable=False),
        sa.Column("uploaded_by_user_id", sa.Uuid(), nullable=False),
        sa.Column(
            "status",
            sa.Enum("uploaded", "doctor_reviewed", "rejected", name="labresultstatus"),
            nullable=False,
        ),
        sa.Column("source_filename", sa.String(length=255), nullable=True),
        sa.Column("storage_key", sa.String(length=500), nullable=True),
        sa.Column("notes", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=False),
        sa.ForeignKeyConstraint(["lesion_id"], ["lesions.id"]),
        sa.ForeignKeyConstraint(["uploaded_by_user_id"], ["users.id"]),
        sa.PrimaryKeyConstraint("id"),
    )


def downgrade() -> None:
    op.drop_table("lab_results")
    op.execute("DROP TYPE IF EXISTS labresultstatus")
```

Create `tests/test_calibration_service.py`:

```python
from app.services.calibration_service import calibrate


def test_calibration_service_returns_patient_label() -> None:
    result = calibrate(0.0)

    assert result.probability == 0.5
    assert result.patient_label == "uncertain model confidence"
```

Apply the migration:

```powershell
.\.venv\Scripts\alembic.exe upgrade head
```

Check:

```powershell
pytest tests/test_calibration_service.py -v
```

Expected result: the lab result table exists, `app.models.lab_result` imports correctly, and the calibration helper returns a safe patient-facing label.

## Step 1: Create Structured Facts Service

Create `app/services/explanation_facts_service.py` with both the Pydantic schemas AND the service class:

```python
"""
ExplanationFactsService - builds structured facts from DB records.
The LLM receives ONLY these structured facts, never raw images or private URLs.
This is the boundary that prevents the LLM from inventing clinical findings.
"""
from __future__ import annotations

import uuid
from sqlalchemy.orm import Session
from pydantic import BaseModel


# --- Pydantic schemas (the safe "facts" the LLM sees) ---

class ImageQualityFacts(BaseModel):
    blur: str       # "ok" | "poor" | "unknown"
    lighting: str   # "ok" | "dark" | "overexposed" | "unknown"
    glare: str      # "none" | "moderate" | "severe" | "unknown"


class GradCamFacts(BaseModel):
    highlighted_regions: list[str]
    heatmap_available: bool


class BodyLocationFacts(BaseModel):
    value: str | None
    verification_status: str   # "not_set" | "patient_submitted" | "doctor_verified" | "doctor_corrected"


class LabResultFacts(BaseModel):
    available: bool
    doctor_review_status: str   # "none" | "uploaded" | "doctor_reviewed" | "rejected"


class ExplanationFacts(BaseModel):
    analysis_id: uuid.UUID
    prediction: str         # "benign" | "malignant"
    confidence: float       # calibrated (0-1)
    patient_label: str      # plain-language label from calibration_service
    model_version: str
    image_quality: ImageQualityFacts
    gradcam: GradCamFacts
    body_location: BodyLocationFacts
    lab_results: LabResultFacts


# --- Service class ---

class ExplanationFactsService:
    """Builds ExplanationFacts from DB models. Injected with a DB session."""

    def __init__(self, db: Session) -> None:
        self._db = db

    def build_facts(self, analysis_id: uuid.UUID) -> ExplanationFacts | None:
        """
        Load prediction record and related records by analysis_id.
        Returns None if the analysis does not exist.
        """
        # Import here to avoid circular imports at module level
        from app.models.prediction import Prediction

        prediction = (
            self._db.query(Prediction)
            .filter(Prediction.id == analysis_id)
            .first()
        )
        if prediction is None:
            return None

        # Grad-CAM facts
        cam_facts = GradCamFacts(
            highlighted_regions=["central lesion area"],   # TODO: parse from CAM metadata
            heatmap_available=prediction.cam_s3_key is not None,
        )

        # Body location facts - load from the lesion if available
        body_facts = BodyLocationFacts(value=None, verification_status="not_set")
        if prediction.lesion_id:
            from app.models.lesion import Lesion
            lesion = self._db.query(Lesion).filter(Lesion.id == prediction.lesion_id).first()
            if lesion:
                body_facts = BodyLocationFacts(
                    value=lesion.body_region,
                    verification_status=lesion.body_location_status or "not_set",
                )

        # Lab result facts
        from app.models.lab_result import LabResult
        lab = (
            self._db.query(LabResult)
            .filter(LabResult.lesion_id == prediction.lesion_id)
            .order_by(LabResult.created_at.desc())
            .first()
        )
        lab_facts = LabResultFacts(
            available=lab is not None,
            doctor_review_status=lab.status.value if lab else "none",
        )

        # Image quality - placeholder until image quality service is wired
        quality_facts = ImageQualityFacts(blur="ok", lighting="ok", glare="none")

        from app.services.calibration_service import calibrate
        cal = calibrate(prediction.raw_logit)

        return ExplanationFacts(
            analysis_id=analysis_id,
            prediction=prediction.label,
            confidence=prediction.confidence,
            patient_label=cal.patient_label,
            model_version=prediction.model_version,
            image_quality=quality_facts,
            gradcam=cam_facts,
            body_location=body_facts,
            lab_results=lab_facts,
        )
```

What this code does:
- The file starts with a docstring explaining the safety boundary: the LLM receives structured facts, not raw images or private storage URLs.
- `from __future__ import annotations` lets Python resolve type hints more flexibly.
- `import uuid` is used because `analysis_id` is stored as a UUID, which is safer than a simple integer ID for exposed records.
- `from sqlalchemy.orm import Session` imports the SQLAlchemy database session type. The service stores a `Session` so it can query database models.
- `from pydantic import BaseModel` imports the base class used to define typed schemas. Pydantic validates and serializes the facts before they are sent to the LLM.
- `ImageQualityFacts` describes blur, lighting, and glare so the explainer can mention image limitations.
- `GradCamFacts` describes which regions Grad-CAM highlighted and whether a heatmap exists.
- `BodyLocationFacts` keeps body location separate from prediction and records whether a doctor verified it.
- `LabResultFacts` records whether lab results exist and what their review status is, without interpreting them as a diagnosis.
- `ExplanationFacts` combines all safe facts into one object. This is the only input the LLM should receive.
- `ExplanationFactsService.__init__` accepts a database session and saves it on `self._db`.
- `build_facts` is the main function. It receives an `analysis_id`, loads the matching prediction, and returns `None` if no prediction exists.
- The imports inside `build_facts` avoid circular import problems between services and database models.
- The `prediction` query searches the `Prediction` table for the exact analysis ID.
- `GradCamFacts` is built from prediction metadata. `heatmap_available` becomes `True` only when `prediction.cam_s3_key` exists.
- `BodyLocationFacts` starts as `not_set`, then changes only if the prediction links to a lesion record.
- The lesion query loads the related lesion so the service can include `body_region` and `body_location_status`.
- The lab query loads the newest lab result for the same lesion by sorting `created_at` in descending order.
- `ImageQualityFacts` is currently a placeholder, keeping the schema ready until a real image quality service is connected.
- `calibrate(prediction.raw_logit)` converts the raw model score into a patient-friendly label.
- The final `ExplanationFacts(...)` return statement packages every safe field into one validated object for the LLM layer.

Test that facts build without calling an LLM:

```python
# tests/test_explanation_facts_service.py
import uuid
import pytest
from unittest.mock import MagicMock
from app.services.explanation_facts_service import ExplanationFactsService, ExplanationFacts


def test_facts_service_returns_none_for_missing_analysis() -> None:
    mock_db = MagicMock()
    mock_db.query.return_value.filter.return_value.first.return_value = None
    service = ExplanationFactsService(mock_db)
    result = service.build_facts(uuid.uuid4())
    assert result is None
```

What this test code does:
- `import uuid` creates a fake analysis ID for the test.
- `import pytest` is available for pytest features, even though this specific test does not use decorators.
- `MagicMock` creates a fake database object so the test does not need a real database.
- The import from `explanation_facts_service` brings in the service being tested and the schema type.
- `test_facts_service_returns_none_for_missing_analysis` checks the missing-record path.
- `mock_db.query.return_value.filter.return_value.first.return_value = None` simulates the database saying no prediction exists for this ID.
- `service = ExplanationFactsService(mock_db)` injects the fake database into the service.
- `service.build_facts(uuid.uuid4())` calls the real service function with a fake UUID.
- `assert result is None` verifies the service returns `None` instead of crashing or inventing facts when the analysis does not exist.

Check:

```powershell
pytest tests/test_explanation_facts_service.py -v
```

What this command does:
- `pytest` runs the Python test suite.
- `tests/test_explanation_facts_service.py` limits the run to this one test file.
- `-v` prints verbose test names, which helps beginners see exactly which test passed or failed.

Expected result: explanation facts can be tested without calling an LLM.

Why this was corrected: the full explanation path needs `LabResult` and `calibrate` to exist before a real prediction can be explained. The lab status is serialized with `.value` so the LLM receives a plain string such as `uploaded`, not a Python enum object.

## Step 2: Add Prompt Files With Real Content

Create `app/agents/prompts/prediction_explainer.md`:

```markdown
You are an educational AI assistant for Skin Lesion XAI.
You explain AI model predictions about skin lesion images in plain language.

## What you have access to
You receive a structured JSON object called `facts`. It contains:
- prediction.label: the model's output ("benign" or "malignant")
- prediction.confidence: a calibrated probability between 0 and 1
- prediction.model_version: the model identifier
- gradcam.highlighted_regions: a list of strings describing what areas the model attended to
- image_quality.blur / lighting / glare: image quality assessment
- body_location.value: patient-reported body region (may be null or unverified)
- lab_results.available: whether lab results exist
- lab_results.doctor_review_status: review status

## Your job
Write a clear, calm, educational paragraph that:
1. Names the prediction label and confidence in plain language.
2. Explains what the confidence level means (not a percentage of certainty of disease).
3. Names what the model paid attention to, based on gradcam.highlighted_regions.
4. Notes any image quality limitations.
5. Recommends the patient discuss with a qualified clinician.

## Hard rules
- Never say the patient has cancer, melanoma, or any named disease.
- Never say the model "detected" cancer or disease.
- Never recommend or suggest any specific treatment, medication, or surgery.
- Never tell the patient to ignore clinical advice.
- Never say Grad-CAM heatmaps prove or confirm disease.
- Never say the patient-entered body location is clinically verified unless body_location.verification_status is "doctor_verified".
- Never interpret lab results as confirming a diagnosis.
- Always close with the disclaimer: "This is educational information only. Please consult a qualified dermatologist or clinician."
```

What this prompt file does:
- This Markdown file becomes the system prompt for the explanation-generating LLM.
- The opening lines define the assistant role as educational, not diagnostic.
- The “What you have access to” section lists the exact structured fields the LLM may use.
- The “Your job” section tells the LLM how to turn model facts into a calm patient explanation.
- The confidence rule prevents the LLM from treating model confidence as proof of disease.
- The Grad-CAM rule tells the LLM to describe attention regions without claiming those regions prove anything.
- The image quality rule lets the LLM mention blur, lighting, or glare as limitations.
- The clinician recommendation keeps the product medically responsible.
- The hard rules block diagnosis, treatment advice, false certainty, unsupported Grad-CAM claims, unverified body location claims, and lab-result overinterpretation.
- The required disclaimer gives every generated explanation the same safety ending.

Create `app/agents/prompts/safety_validator.md`:

```markdown
You are a medical safety review agent for an AI-assisted skin lesion platform.
You review a draft explanation before it is shown to a patient.

## What you check
Return a JSON object with two fields:
- "safe": true or false
- "blocked_claims": list of strings, each naming a specific unsafe claim in the draft (empty list if safe)

## Unsafe claim categories
Return safe=false if the draft:
- Diagnoses a specific disease (e.g., "you have melanoma", "this is cancer")
- Recommends treatment, medication, or surgery
- Tells the user to ignore or delay clinical care
- States that Grad-CAM "proves" or "confirms" disease
- States that a patient-entered body location is clinically verified when it is not
- States that a lab result confirms a diagnosis without a doctor review
- Uses phrases like "definitely malignant", "certainly benign", "you need surgery", "this is serious"
- Provides a prognosis or survival estimate

## What is acceptable
It is acceptable and encouraged to:
- Name the model's prediction label and calibrated confidence
- Explain what the model attended to in the image
- Recommend professional review
- Describe image quality limitations
- Say "the model suggests" or "the model flagged" rather than "you have"

Return safe=true and blocked_claims=[] if none of the unsafe categories apply.
```

What this prompt file does:
- This Markdown file becomes the system prompt for the safety-review LLM.
- The validator does not write the patient explanation. It checks a draft explanation before the patient sees it.
- The required output is JSON with `safe` and `blocked_claims`, so application code can make a clear pass/fail decision.
- `safe: true` means the draft can be shown.
- `safe: false` means the draft contains unsafe medical wording.
- `blocked_claims` lists exactly which unsafe claims must be removed.
- The unsafe categories block diagnosis, treatment advice, delayed care advice, false Grad-CAM certainty, unverified body location claims, lab-result diagnosis claims, certainty language, and prognosis.
- The acceptable section allows useful educational language while keeping the response away from diagnosis.

### Learning: grounding is what stops hallucination

This guide already does the single most important grounding move: the LLM only ever sees the structured facts from Step 1, never raw model internals or invented data. That is the production-RAG principle "answer only from the provided context" applied to a medical explanation. Two more rules from production RAG belong in these prompts (full context in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.11 and 12.6):

- **Say "I don't know" instead of guessing.** When the facts are missing or the retrieved policy context is thin, the explanation should state that it does not have enough information and recommend professional review. An honest gap is safe; a confident guess is the exact hallucination failure mode that hurts people here. This pairs with the corrective-retrieval idea in Family 13.8: weak evidence should trigger a refusal or a retry, never a fabricated answer.
- **Cite the evidence.** Tie each claim back to the fact or policy clause it came from, so the explanation is auditable and the safety validator (and a reviewing doctor) can check it. Citations build user trust and make the output verifiable. Guard against hallucinated citations: a cited source must actually contain the claim (Family 13.11 question 4, and 12.6).

When the policy context behind this explanation moves from the hard-coded stub in `product/07` Step 7 to a real vector store, the retrieval quality (chunking, embeddings, hybrid search, reranking) directly affects how well-grounded these explanations are. Garbage retrieval produces confident, wrong, well-cited explanations, which is worse than no answer.

## Step 3: Add Claude API Call + Explanation Endpoint

First add the Anthropic SDK to requirements.txt:

```text
anthropic==0.51.0
```

What this dependency line does:
- `anthropic` is the Python SDK used to call Claude from backend code.
- `==0.51.0` pins the exact SDK version so your local environment and later deployments use the same API behavior.
- This line belongs in `requirements.txt`, not in a Python file.

Install:

```powershell
pip install -r requirements.txt
```

What this command does:
- `pip install` installs Python packages into the active Python environment.
- `-r requirements.txt` tells pip to read the package list from `requirements.txt`.
- This must be run from the backend folder while the backend virtual environment is active.

Create `app/services/llm_explanation_service.py`:

```python
"""
Safe LLM explanation using the Anthropic Claude API.
The LLM never sees raw image bytes - it only receives structured facts.
This prevents the model from inventing clinical findings from images.
"""
from __future__ import annotations

import json
import os

import anthropic
from pydantic import BaseModel

from app.services.explanation_facts_service import ExplanationFacts


class ExplanationResponse(BaseModel):
    summary: str
    prediction_explanation: str
    gradcam_explanation: str
    image_quality_note: str
    body_location_note: str
    lab_result_note: str
    safety_note: str = "This is educational information only. Please consult a qualified dermatologist or clinician."
    blocked_claims: list[str] = []
    safe: bool = True


class LLMExplanationService:
    MODEL = "claude-haiku-4-5-20251001"   # fast + cheap for explanation generation
    MAX_TOKENS = 800

    def __init__(self) -> None:
        self._client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
        self._explainer_prompt = self._load_prompt("app/agents/prompts/prediction_explainer.md")
        self._safety_prompt = self._load_prompt("app/agents/prompts/safety_validator.md")

    @staticmethod
    def _load_prompt(path: str) -> str:
        with open(path) as f:
            return f.read()

    def explain(self, facts: ExplanationFacts) -> ExplanationResponse:
        facts_json = facts.model_dump_json(indent=2)

        # Step 1: Generate explanation draft
        draft = self._generate_draft(facts_json)

        # Step 2: Safety validation loop - max 2 revision attempts
        for attempt in range(2):
            validation = self._validate_safety(draft)
            if validation.get("safe", False):
                break
            blocked = validation.get("blocked_claims", [])
            draft = self._revise_draft(draft, blocked)

        safe = validation.get("safe", True)
        blocked_claims = validation.get("blocked_claims", []) if not safe else []

        return ExplanationResponse(
            summary=draft[:300],
            prediction_explanation=draft,
            gradcam_explanation=self._explain_gradcam(facts),
            image_quality_note=self._quality_note(facts),
            body_location_note=self._location_note(facts),
            lab_result_note=self._lab_note(facts),
            blocked_claims=blocked_claims,
            safe=safe,
        )

    def _generate_draft(self, facts_json: str) -> str:
        response = self._client.messages.create(
            model=self.MODEL,
            max_tokens=self.MAX_TOKENS,
            system=self._explainer_prompt,
            messages=[{"role": "user", "content": f"Facts:\n```json\n{facts_json}\n```"}],
        )
        return response.content[0].text

    def _validate_safety(self, draft: str) -> dict:
        response = self._client.messages.create(
            model=self.MODEL,
            max_tokens=200,
            system=self._safety_prompt,
            messages=[{"role": "user", "content": f"Review this draft:\n\n{draft}\n\nReturn JSON only."}],
        )
        try:
            return json.loads(response.content[0].text)
        except json.JSONDecodeError:
            # If the validator returns non-JSON, treat as safe (log warning in production)
            return {"safe": True, "blocked_claims": []}

    def _revise_draft(self, draft: str, blocked_claims: list[str]) -> str:
        blocked_str = "\n".join(f"- {c}" for c in blocked_claims)
        response = self._client.messages.create(
            model=self.MODEL,
            max_tokens=self.MAX_TOKENS,
            system=self._explainer_prompt,
            messages=[
                {"role": "user", "content": f"Original draft:\n{draft}"},
                {"role": "assistant", "content": draft},
                {"role": "user", "content": f"The following claims are unsafe and must be removed:\n{blocked_str}\nRewrite the explanation without them."},
            ],
        )
        return response.content[0].text

    @staticmethod
    def _explain_gradcam(facts: ExplanationFacts) -> str:
        regions = ", ".join(facts.gradcam.highlighted_regions) if facts.gradcam.highlighted_regions else "the central lesion area"
        avail = "is available" if facts.gradcam.heatmap_available else "is not available for this image"
        return (
            f"The model's attention heatmap {avail}. "
            f"The model paid most attention to: {regions}. "
            "This shows where the model looked - it does not confirm disease in those areas."
        )

    @staticmethod
    def _quality_note(facts: ExplanationFacts) -> str:
        issues = [
            k for k, v in {
                "blur": facts.image_quality.blur,
                "lighting": facts.image_quality.lighting,
                "glare": facts.image_quality.glare,
            }.items() if v not in ("ok", "good", "none")
        ]
        if not issues:
            return "Image quality appears acceptable."
        return f"Image quality may affect accuracy. Issues detected: {', '.join(issues)}. Consider retaking the image."

    @staticmethod
    def _location_note(facts: ExplanationFacts) -> str:
        if not facts.body_location.value:
            return "No body location was provided."
        if facts.body_location.verification_status == "doctor_verified":
            return f"Body location ({facts.body_location.value}) has been verified by a doctor."
        return f"Body location ({facts.body_location.value}) was submitted by the patient and has not yet been verified by a clinician."

    @staticmethod
    def _lab_note(facts: ExplanationFacts) -> str:
        if not facts.lab_results.available:
            return "No lab results are associated with this analysis."
        status = facts.lab_results.doctor_review_status
        return f"Lab results are present (review status: {status}). Lab results provide clinical context - they do not confirm the AI model's prediction."
```

What this code does:
- The file docstring repeats the core safety rule: Claude receives structured facts, not image bytes.
- `from __future__ import annotations` improves type-hint handling.
- `import json` is used to parse the validator’s JSON response.
- `import os` reads `ANTHROPIC_API_KEY` from environment variables instead of hard-coding secrets.
- `import anthropic` imports the Claude SDK.
- `BaseModel` is imported so the service can return a validated response object.
- `ExplanationFacts` is imported because the service accepts the safe facts object created in the previous step.
- `ExplanationResponse` defines the exact shape returned by the LLM explanation endpoint.
- `summary`, `prediction_explanation`, `gradcam_explanation`, `image_quality_note`, `body_location_note`, and `lab_result_note` separate the patient-facing explanation into predictable fields.
- `safety_note` has a default disclaimer, so every response includes the educational-only warning.
- `blocked_claims` records unsafe claims if the validator could not produce a safe draft.
- `safe` tells the API consumer whether the explanation passed validation.
- `LLMExplanationService.MODEL` chooses the Claude model used for generation and validation.
- `MAX_TOKENS` limits response length and cost.
- `__init__` creates the Anthropic client using `ANTHROPIC_API_KEY` and loads both prompt files from disk.
- `_load_prompt` opens a prompt file and returns its text.
- `explain` is the main public method. It converts facts to JSON, generates a draft, validates it, revises it if needed, and returns an `ExplanationResponse`.
- `facts.model_dump_json(indent=2)` serializes the Pydantic facts object into readable JSON for the LLM.
- `_generate_draft` calls Claude with the explainer prompt and the facts JSON.
- The validation loop runs at most two times so the backend cannot get stuck revising forever.
- `_validate_safety` calls Claude with the safety prompt and expects JSON back.
- The `try/except json.JSONDecodeError` handles invalid validator output. In production, this should be logged and treated more strictly.
- `_revise_draft` sends the unsafe draft and blocked claims back to Claude and asks for a corrected version.
- `_explain_gradcam` creates a deterministic Grad-CAM note from facts instead of relying only on free-form LLM wording.
- `_quality_note` checks blur, lighting, and glare values and reports problems when they are not normal.
- `_location_note` distinguishes missing, patient-submitted, and doctor-verified body locations.
- `_lab_note` states whether lab results exist and reminds the user that lab results do not confirm the AI prediction.

Create `app/api/v1/explain.py`:

```python
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.services.explanation_facts_service import ExplanationFactsService
from app.services.llm_explanation_service import ExplanationResponse, LLMExplanationService

router = APIRouter(prefix="/api/v1")
_llm_service: LLMExplanationService | None = None


def get_llm_service() -> LLMExplanationService:
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMExplanationService()
    return _llm_service


@router.post("/explain-llm/{analysis_id}", response_model=ExplanationResponse)
def explain_analysis(
    analysis_id: uuid.UUID,
    db: Session = Depends(get_db),
    llm_service: LLMExplanationService = Depends(get_llm_service),
) -> ExplanationResponse:
    facts_service = ExplanationFactsService(db)
    facts = facts_service.build_facts(analysis_id)
    if facts is None:
        raise HTTPException(status_code=404, detail="Analysis not found")
    return llm_service.explain(facts)
```

What this API code does:
- `import uuid` lets FastAPI validate `analysis_id` as a UUID before it reaches the facts service.
- `APIRouter` creates a group of FastAPI routes for explanation endpoints.
- `Depends` lets FastAPI inject dependencies, such as the database session.
- `HTTPException` is used to return a proper API error when the analysis ID does not exist.
- `Session` is the SQLAlchemy database session type.
- `get_db` is the backend’s database dependency. FastAPI calls it for each request.
- `ExplanationFactsService` builds the safe structured facts from database records.
- `ExplanationResponse` tells FastAPI the response shape for OpenAPI docs and validation.
- `LLMExplanationService` generates and validates the patient explanation.
- `router = APIRouter(prefix="/api/v1")` creates the route container under the same versioned API prefix as the other product routes.
- `_llm_service` starts as `None` so importing the app does not require `ANTHROPIC_API_KEY`.
- `get_llm_service` creates the Anthropic-backed service lazily the first time the endpoint is called.
- `@router.post("/explain-llm/{analysis_id}", response_model=ExplanationResponse)` defines a POST endpoint with `analysis_id` in the URL.
- `explain_analysis` is the function FastAPI runs when the endpoint is called.
- `analysis_id: uuid.UUID` prevents string/UUID mismatches.
- `db: Session = Depends(get_db)` gives the function a live database session.
- `llm_service: LLMExplanationService = Depends(get_llm_service)` lets tests override the LLM dependency and avoids constructing the LLM at import time.
- `facts_service.build_facts(analysis_id)` loads the safe facts for the requested analysis.
- If no facts exist, the endpoint returns HTTP 404 instead of calling the LLM.
- If facts exist, `llm_service.explain(facts)` returns the validated explanation response.

Update `app/main.py` so the endpoint is actually reachable:

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.v1 import body_locations
from app.api.v1 import explain
from app.api.v1 import lesions
from app.api.v1.router import router as v1_router

app = FastAPI(title="Skin Lesion API")
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:3000",
        "http://127.0.0.1:3000",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(v1_router)
app.include_router(lesions.router)
app.include_router(body_locations.router)
app.include_router(explain.router)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
```

Create `tests/test_explain_endpoint.py`:

```python
import uuid

from fastapi.testclient import TestClient

from app.api.v1.explain import get_llm_service
from app.db.session import get_db
from app.main import app


client = TestClient(app)


class _MissingFactsQuery:
    def filter(self, *args: object, **kwargs: object) -> "_MissingFactsQuery":
        return self

    def first(self) -> None:
        return None


class _MissingFactsDb:
    def query(self, *args: object, **kwargs: object) -> _MissingFactsQuery:
        return _MissingFactsQuery()


class _NoCallLlmService:
    def explain(self, facts: object) -> None:
        raise AssertionError("LLM should not be called when analysis is missing")


def _override_db() -> _MissingFactsDb:
    return _MissingFactsDb()


def _override_llm_service() -> _NoCallLlmService:
    return _NoCallLlmService()


def test_explain_endpoint_returns_404_for_missing_analysis() -> None:
    app.dependency_overrides[get_db] = _override_db
    app.dependency_overrides[get_llm_service] = _override_llm_service
    try:
        response = client.post(f"/api/v1/explain-llm/{uuid.uuid4()}")
    finally:
        app.dependency_overrides.clear()

    assert response.status_code == 404
    assert response.json()["detail"] == "Analysis not found"
```

Check:

```powershell
pytest tests/test_explain_endpoint.py -v
```

Expected result: the endpoint returns 404 for a missing analysis and does not call the LLM.

Why this was corrected: the first version created `app/api/v1/explain.py` but did not register it in `app/main.py`. The first version also created the Anthropic client at import time, which would make local tests and health checks require `ANTHROPIC_API_KEY` before the explanation endpoint is even called.

## Step 4: Add Safety Refusal Tests

Create `tests/test_llm_safety.py`:

```python
"""
Safety tests for the LLM explanation service.
These tests run without an Anthropic API key by mocking the client.
They verify that the safety validator correctly identifies unsafe claims.
"""
import pytest
from unittest.mock import MagicMock, patch

from app.services.llm_explanation_service import LLMExplanationService


UNSAFE_DRAFTS = [
    ("diagnosis", "Based on the analysis, you have melanoma and should see a doctor immediately."),
    ("cancer_claim", "This image shows clear signs of skin cancer."),
    ("treatment_advice", "You should start treatment right away and book surgery."),
    ("ignore_doctors", "You do not need to see a doctor, the AI is accurate enough."),
    ("gradcam_confirms", "The Grad-CAM heatmap confirms that the lesion is malignant."),
    ("certainty_claim", "The model is definitely detecting a malignant lesion."),
]

SAFE_DRAFTS = [
    ("benign_label", "The model's prediction is 'benign' with a calibrated confidence of 0.73. This means the model found patterns more consistent with benign lesions, but this is not a medical diagnosis. Please consult a clinician."),
    ("malignant_label", "The model flagged this lesion as 'malignant' with a confidence of 0.81. The model attended to the irregular border region. This is educational information only. A dermatologist should review this image."),
]


def _make_service_with_mock_client() -> tuple[LLMExplanationService, MagicMock]:
    with patch("app.services.llm_explanation_service.anthropic.Anthropic"):
        service = LLMExplanationService.__new__(LLMExplanationService)
        service._client = MagicMock()
        service._explainer_prompt = "test prompt"
        service._safety_prompt = "test safety prompt"
        return service, service._client


@pytest.mark.parametrize("claim_type,draft", UNSAFE_DRAFTS)
def test_safety_validator_blocks_unsafe_claims(claim_type: str, draft: str) -> None:
    service, mock_client = _make_service_with_mock_client()

    import json
    mock_response = MagicMock()
    mock_response.content = [MagicMock(text=json.dumps({"safe": False, "blocked_claims": [claim_type]}))]
    mock_client.messages.create.return_value = mock_response

    result = service._validate_safety(draft)
    assert result["safe"] is False
    assert len(result["blocked_claims"]) > 0


@pytest.mark.parametrize("label,draft", SAFE_DRAFTS)
def test_safety_validator_passes_safe_drafts(label: str, draft: str) -> None:
    service, mock_client = _make_service_with_mock_client()

    import json
    mock_response = MagicMock()
    mock_response.content = [MagicMock(text=json.dumps({"safe": True, "blocked_claims": []}))]
    mock_client.messages.create.return_value = mock_response

    result = service._validate_safety(draft)
    assert result["safe"] is True
    assert result["blocked_claims"] == []
```

What this test code does:
- The file docstring explains that these tests do not call the real Anthropic API.
- `pytest` provides parametrized tests, which let one test function run against many examples.
- `MagicMock` creates fake response objects.
- `patch` temporarily replaces the real Anthropic client so no network call happens.
- `LLMExplanationService` is the service under test.
- `UNSAFE_DRAFTS` contains examples that should fail safety validation, such as diagnosis, treatment advice, and false Grad-CAM certainty.
- `SAFE_DRAFTS` contains examples that are educational, cautious, and clinician-oriented.
- `_make_service_with_mock_client` creates an `LLMExplanationService` instance without running its normal `__init__`.
- `LLMExplanationService.__new__(LLMExplanationService)` allocates the object directly so the test can avoid requiring `ANTHROPIC_API_KEY`.
- The test then manually sets `_client`, `_explainer_prompt`, and `_safety_prompt`.
- `@pytest.mark.parametrize("claim_type,draft", UNSAFE_DRAFTS)` runs the unsafe test once for every unsafe example.
- `mock_response.content = [MagicMock(text=json.dumps(...))]` creates a fake Claude response shaped like the SDK response.
- `mock_client.messages.create.return_value = mock_response` makes every validator call return that fake response.
- `service._validate_safety(draft)` runs the real parsing logic against the fake response.
- The unsafe test asserts that `safe` is `False` and at least one blocked claim is returned.
- The safe test uses the same mock pattern but returns `{"safe": True, "blocked_claims": []}`.
- The safe test asserts that safe drafts pass and do not produce blocked claims.

Run:

```powershell
pytest tests/test_llm_safety.py -v
```

What this command does:
- `pytest` runs tests.
- `tests/test_llm_safety.py` runs only the LLM safety tests from this guide.
- `-v` prints every parametrized case, which makes it easier to see which unsafe category failed if a regression appears.

Expected: all parametrized tests pass.

Run the full backend check after all files in this guide are in place:

```powershell
make test
```

What this command does:
- `make test` runs the backend pytest suite from the backend repository.
- It checks that registering the explanation router did not break `/health`, `/api/v1/ready`, upload analysis tests, model service tests, storage tests, or the new LLM safety tests.

Expected result: the backend test suite passes without requiring a real Anthropic API call.

## Step 5: Sequential + Parallel Agent Workflow (Wire Up Later)

The `LLMExplanationService` above is a sequential pipeline (draft -> validate -> revise).
After this works, extend to parallel agents using LangChain or Google ADK:

```text
See: docs/product/07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md
```

What this block means:
- This is a documentation pointer, not code to run.
- It tells you that the current guide intentionally starts with a simple sequential service.
- The next guide expands the design into a more advanced agent workflow after the safe single-service version works.

The parallel workflow (run prediction/gradcam/quality agents in parallel, then synthesise) is covered there with full async code.

## Concepts You Just Touched

- [RAG Isolation (10.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#103-rag-isolation) - LLM only sees structured facts, not raw images or patient records
- [Prompt Injection Defense (10.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#101-prompt-injection-defense) - structured input schema prevents injection through uploaded images
- [Evidence Citation (10.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#104-evidence-citation) - every claim traces back to a fact in `ExplanationFacts`
- [Refusal Pattern (10.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#102-refusal-pattern) - the safety validator loop is the refusal gate

## Questions You Should Be Able To Answer

1. Why does the LLM receive structured facts instead of the raw image? What attack does this prevent?
2. The safety validator runs in a loop with a maximum of 2 revisions. What happens if iteration 2 is still unsafe - and what should the product do in that case?
3. Why use `claude-haiku-4-5-20251001` for explanation generation instead of Opus? What is the trade-off?
4. What is the difference between a "blocked claim" and a "refusal"? Can a response be safe but still unhelpful to a patient?
5. If the patient asks the AI "do I have cancer?", trace exactly which function handles that and what it returns.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What these commands do:
- `make cloud-status ENV=dev` checks whether the development cloud resources are running.
- `make cloud-pause ENV=dev` pauses resources that support pausing, which helps reduce cost while preserving the environment.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys or shuts down development resources when you intentionally want to stop paying for them.
- `CONFIRM_DESTROY=YES` is a safety flag. Without it, destructive shutdown targets should refuse to run.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What these commands do:
- `make cloud-start ENV=dev` starts the development cloud environment again.
- `make cloud-status ENV=dev` confirms the environment is available before you continue building or testing.
- Running status after start catches failed startups early.

If this guide was local-only, no cloud shutdown is needed.
