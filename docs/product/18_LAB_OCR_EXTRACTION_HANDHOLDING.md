# Lab OCR And Extraction Handholding Guide

Use this after simple lab report upload, metadata, storage, and doctor review work.

OCR is not part of the MVP lab flow. The first lab flow is file upload plus review status.

## Current Implementation Boundary

The local implementation now includes:

```text
Skin_Lesion_Classification_backend/app/services/lab_ocr_provider.py
Skin_Lesion_Classification_backend/app/models/lab_ocr.py
Skin_Lesion_Classification_backend/app/schemas/lab_ocr_schema.py
Skin_Lesion_Classification_backend/app/services/lab_ocr_service.py
Skin_Lesion_Classification_backend/alembic/versions/h3f4a5b6c728_add_lab_ocr_draft_tables.py
Skin_Lesion_Classification_frontend/app/doctor/lab-results/[id]/page.tsx
Skin_Lesion_Classification_frontend/components/lab-results/LabOcrReviewPanel.tsx
```

**What this means:** the product guide is implemented as a safe manual-stub OCR workflow. The provider returns no automatic values until a paid OCR vendor is chosen, but the database, API contract, audit events, and doctor review page are now wired so a real provider can be added later without changing the review boundary.

The completion boundary is still conservative:

```text
OCR_PROVIDER=manual_stub
No raw OCR text stored
No OCR value auto-promotes into doctor-accepted data
Doctor review is required per extracted value
Audit events record run creation and value review
```

**What this means:** this guide completes the local product contract without committing to AWS Textract, Azure Document Intelligence, or any paid OCR vendor.

## Goal

Add clinician-guided OCR extraction without trusting OCR as medical truth.

```text
lab file uploaded -> OCR draft extraction -> doctor review -> accepted structured values -> audit trail
```

**What this workflow means:** OCR extracts values from the lab file and marks them as drafts. A doctor reviews each extracted value, can edit it, and decides whether to accept or reject it. Only accepted values become structured data that the system uses. The audit trail records who reviewed what and when. OCR is never allowed to write directly to patient records without doctor review.

Do not let OCR automatically change diagnosis, triage, or model labels.

## Command Location

Start from:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root before changing into the backend or frontend repos in subsequent steps.

Backend files belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the OCR provider interface, extraction service, and Alembic migrations all live in the backend. Not in the research repo.

Frontend files belong in:

```text
Skin_Lesion_Classification_frontend
```

**What this means:** the doctor review UI for OCR drafts lives in the Next.js frontend, under the doctor section of the app.

## Parameters You Must Set First

```text
OCR_PROVIDER=manual_stub first
FUTURE_OCR_PROVIDER=AWS Textract or Azure Document Intelligence
MAX_FILE_SIZE_MB=10
SUPPORTED_FILE_TYPES=pdf,png,jpg,jpeg
OCR_CONFIDENCE_REVIEW_THRESHOLD=0.90
STORE_RAW_OCR_TEXT=false by default
```

**What these parameters mean:**

- `OCR_PROVIDER=manual_stub first` - start with a stub that returns no extracted values. This lets you wire up the full review workflow before integrating a paid OCR vendor.
- `FUTURE_OCR_PROVIDER=AWS Textract or Azure Document Intelligence` - the real OCR vendors to evaluate later. Both support medical documents and structured form extraction.
- `MAX_FILE_SIZE_MB=10` - reject uploads larger than 10MB at the API layer. Prevents accidental full-resolution scans from being sent to OCR.
- `SUPPORTED_FILE_TYPES=pdf,png,jpg,jpeg` - the only file types the OCR flow accepts. Reject other formats early with a clear error message.
- `OCR_CONFIDENCE_REVIEW_THRESHOLD=0.90` - extracted values with a confidence score below 0.90 are flagged for mandatory doctor review. Values above 0.90 are still shown to the doctor but not highlighted as uncertain.
- `STORE_RAW_OCR_TEXT=false by default` - the raw unstructured OCR text output (full page text) is not stored by default. Only the extracted field values are kept. Raw text may contain identifiers or context that is not needed in the database.

## Step 1: Define Provider Interface

Create:

```text
Skin_Lesion_Classification_backend/app/services/lab_ocr_provider.py
```

**What this file is:** the provider abstraction layer for OCR. The backend depends on this interface, not on a specific OCR vendor. Swapping from the stub to Textract later requires only a new class that implements `extract()`.

Paste:

```python
from dataclasses import dataclass


@dataclass(frozen=True)
class ExtractedLabValue:
    name: str
    value: str
    unit: str | None
    confidence: float


class ManualLabOcrProvider:
    def extract(self, file_key: str) -> list[ExtractedLabValue]:
        return []
```

**What this code does:**

- `@dataclass(frozen=True)` - creates an immutable data class. `frozen=True` prevents accidental modification of extracted values after they are created.
- `ExtractedLabValue` - a value object representing one extracted field from a lab report. `name` is the test name (e.g., "Total Bilirubin"), `value` is the raw extracted string, `unit` is optional (e.g., "mg/dL"), and `confidence` is the OCR vendor's certainty score for this extraction.
- `class ManualLabOcrProvider` - the stub implementation. `extract()` returns an empty list, meaning no values are extracted automatically. This is the correct default for local development before a real OCR vendor is connected.
- `def extract(self, file_key: str) -> list[ExtractedLabValue]` - the interface contract. All future OCR providers must implement this method with this signature. `file_key` is the S3 key of the uploaded lab file.

Check:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -c "from app.services.lab_ocr_provider import ManualLabOcrProvider; print(ManualLabOcrProvider().extract('x'))"
```

**What this does:** imports the provider class and calls `extract()` with a dummy key. Confirms the class exists, all imports resolve, and the stub returns an empty list.

Expected result:

```text
OCR provider interface exists and returns no automatic values locally.
```

**What this result means:** the import succeeded and the stub returned `[]`. The doctor review workflow can now be built against this interface.

Why: the app contract is ready before choosing a paid OCR vendor.

## Step 2: Store Draft Values Separately

Create:

```text
Skin_Lesion_Classification_backend/app/models/lab_ocr.py
```

Paste:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LabExtractionStatus(str, enum.Enum):
    pending = "pending"
    completed = "completed"
    failed = "failed"
    reviewed = "reviewed"


class LabExtractedValueReviewStatus(str, enum.Enum):
    pending = "pending"
    accepted = "accepted"
    edited = "edited"
    rejected = "rejected"


class LabExtractionRun(Base):
    __tablename__ = "lab_extraction_runs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    lab_result_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lab_results.id"), nullable=False)
    provider: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[LabExtractionStatus] = mapped_column(
        Enum(LabExtractionStatus, name="labextractionstatus"),
        default=LabExtractionStatus.pending,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class LabExtractedValue(Base):
    __tablename__ = "lab_extracted_values"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    extraction_run_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lab_extraction_runs.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    value: Mapped[str] = mapped_column(String(200), nullable=False)
    unit: Mapped[str | None] = mapped_column(String(80), nullable=True)
    confidence: Mapped[float] = mapped_column(Float, nullable=False)
    review_status: Mapped[LabExtractedValueReviewStatus] = mapped_column(
        Enum(LabExtractedValueReviewStatus, name="labextractedvaluereviewstatus"),
        default=LabExtractedValueReviewStatus.pending,
        nullable=False,
    )
    reviewed_value: Mapped[str | None] = mapped_column(String(200), nullable=True)
    reviewed_unit: Mapped[str | None] = mapped_column(String(80), nullable=True)
    review_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    reviewed_by: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

Then update:

```text
Skin_Lesion_Classification_backend/app/models/__init__.py
```

Add these imports and exports:

```python
from app.models.lab_ocr import LabExtractionRun, LabExtractedValue
```

```python
"LabExtractionRun",
"LabExtractedValue",
```

**What this model does:** it creates two separate tables:

```text
lab_extraction_runs:
  id
  lab_result_id
  provider
  status
  created_at
  reviewed_at

lab_extracted_values:
  id
  extraction_run_id
  name
  value
  unit
  confidence
  review_status
  reviewed_value
  reviewed_unit
  review_note
  reviewed_by
  reviewed_at
  created_at
```

**What these tables mean:**

- `lab_extraction_runs` - one record per OCR job. `lab_result_id` links back to the original uploaded file. `provider` records which OCR vendor was used. `status` tracks whether the run completed, failed, or is still pending. `reviewed_at` is set when the doctor finishes reviewing the draft values.
- `lab_extracted_values` - one record per extracted field from a lab report. `extraction_run_id` groups values from the same run. `name` and `value` are the field label and raw extracted text. `confidence` is the OCR score. `review_status` tracks whether the doctor accepted, edited, or rejected this specific value. The reviewed fields record the doctor-confirmed value without overwriting the original OCR draft.

Do not store raw OCR text by default.

Create:

```text
Skin_Lesion_Classification_backend/alembic/versions/h3f4a5b6c728_add_lab_ocr_draft_tables.py
```

Paste the migration from the repository if you are rebuilding this step by hand. It creates:

```text
labextractionstatus enum: pending, completed, failed, reviewed
labextractedvaluereviewstatus enum: pending, accepted, edited, rejected
lab_extraction_runs table
lab_extracted_values table
foreign keys to lab_results, lab_extraction_runs, and users
```

**Why this choice was made:** OCR data stays draft-only and separate from doctor-reviewed lab-result status. There is no third accepted-values table yet because the product currently needs a safe doctor review workflow first; a structured clinical-values table can be added later after the accepted-value use cases are clearer.

Check:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\alembic.exe revision --autogenerate -m "add lab extraction drafts"
.\.venv\Scripts\alembic.exe upgrade head
.\.venv\Scripts\python.exe -m pytest
```

**What this command block does:**

- `alembic revision --autogenerate -m "add lab extraction drafts"` - only use this if you are recreating the migration yourself. In the current repo, the migration file already exists.
- `alembic upgrade head` - runs the generated migration to create the new tables in the database.
- `pytest` - runs the full test suite to confirm the migration did not break any existing tests.

Expected result:

```text
OCR draft tables exist separately from doctor-accepted lab review.
```

**What this means:** the two new tables are created and the test suite still passes. Confirm by connecting to the database and listing tables, or by running `alembic current` to see the latest applied revision.

## Step 3: Add OCR API Contract

Create:

```text
Skin_Lesion_Classification_backend/app/schemas/lab_ocr_schema.py
Skin_Lesion_Classification_backend/app/services/lab_ocr_service.py
```

Then update:

```text
Skin_Lesion_Classification_backend/app/api/v1/lab_results.py
```

Add these API endpoints under the existing lab-result router:

```text
POST /api/v1/lab-results/{lab_result_id}/ocr-runs
GET  /api/v1/lab-results/{lab_result_id}/ocr-runs/latest
PATCH /api/v1/lab-results/{lab_result_id}/ocr-values/{value_id}/review
```

**What these endpoints do:**

- `POST /ocr-runs` creates a manual-stub extraction run for a consented lab result. Locally this returns an empty `values` list because the provider extracts nothing automatically yet.
- `GET /ocr-runs/latest` returns the latest OCR run plus the original lab-result metadata. The doctor UI uses this to keep the source report context visible.
- `PATCH /ocr-values/{value_id}/review` records one doctor decision: `accepted`, `edited`, or `rejected`.

Paste this request shape for review actions:

```json
{
  "review_status": "edited",
  "reviewed_value": "214",
  "reviewed_unit": "U/L",
  "review_note": "Corrected against the original report."
}
```

Use these response fields for each extracted value:

```text
id
extraction_run_id
name
value
unit
confidence
review_status
reviewed_value
reviewed_unit
review_note
reviewed_by
reviewed_at
created_at
```

**Safety rule:** the endpoint never changes diagnosis, triage, model labels, or the main lab-result status. It only stores OCR draft review decisions and audit events.

Check:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_lab_ocr.py
```

Expected result:

```text
2 passed
```

**What this means:** the backend can create a manual OCR run and can record doctor accept/edit/reject decisions for draft OCR values.

## Step 4: Doctor Review UI

Create the frontend page under the existing lab result review flow:

```text
Skin_Lesion_Classification_frontend/app/doctor/lab-results/[id]/page.tsx
Skin_Lesion_Classification_frontend/components/lab-results/LabOcrReviewPanel.tsx
```

Then update the shared frontend API client:

```text
Skin_Lesion_Classification_frontend/lib/api.ts
```

**What these files are:**

- `app/doctor/lab-results/[id]/page.tsx` is the doctor's review screen for a specific lab result. The `[id]` is the lab result ID from the URL.
- `components/lab-results/LabOcrReviewPanel.tsx` loads the latest OCR run, can start a manual-stub run, and renders each extracted value as a reviewable card.
- `lib/api.ts` holds the typed fetch helpers for the OCR endpoints.

UI rules:

```text
show OCR values as draft
show confidence
doctor can accept, edit, or reject each value
record reviewer and timestamp
never hide the original lab file from the reviewer
```

Use this route:

```text
/doctor/lab-results/[id]
```

**What this route means:** replace `[id]` with a real `lab_result_id`. The page is doctor-facing and is not indexed by search engines.

**What these UI rules mean:**

- `show OCR values as draft` - extracted values must be clearly labelled as unconfirmed. A badge or label like "Draft - pending review" prevents anyone from treating them as verified data.
- `show confidence` - display the OCR confidence score next to each value. Low-confidence values should be visually flagged (e.g., amber highlight) to draw the doctor's attention.
- `doctor can accept, edit, or reject each value` - the review is per-value, not per-file. A doctor can accept some values and reject others from the same extraction run.
- `record reviewer and timestamp` - every accept/edit/reject action writes to the audit log with the doctor's user ID and the timestamp.
- `never hide the original lab file from the reviewer` - the doctor must be able to see the original PDF or image alongside the extracted values to verify accuracy.
- `manual stub empty state` - if the manual provider returns no values, the UI says that no draft values were extracted and keeps the original lab upload as the source of truth.
- `start another draft run` - doctors can start a new manual-stub run, which lets the same page work after a real OCR provider is added later.

Check:

```powershell
cd Skin_Lesion_Classification_frontend
npm run build
```

**What this does:** runs the full Next.js production build to confirm the new doctor review page compiles without TypeScript errors or missing imports.

Expected result:

```text
Doctor review page builds and OCR values are visibly marked as drafts.
```

**What this means:** the build succeeds and the draft status labelling is visible in the rendered page. Verify the draft badge is present by running the dev server and navigating to the page.

### Learning: when you want to retrieve across lab documents, go multimodal

This guide extracts text values from a single uploaded lab report. The moment you want to *search* across many stored lab documents (for example, a doctor asking "show this patient's past LDH values"), plain text extraction becomes a liability. OCR-to-text flattens a lab table and loses which value pairs with which reference range, and it mangles charts entirely. The production-RAG answer is multimodal RAG, also called the ColPali approach: embed images of the document pages directly instead of extracting text first, so tables, columns, and reference ranges keep their structure. Detail in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.10.

Keep the medical-safety boundary that this whole guide is built on. Page-image retrieval is for organizing and surfacing lab documents for professional review and for citing the exact page a value came from. It is never for auto-reading a lab result as a diagnosis. The extracted values stay drafts until a doctor verifies them, exactly as Steps 2 and 3 require.

## Completion Gate

Lab OCR is complete only when:

```text
simple lab upload works first
OCR provider is behind an interface
draft extraction is stored separately
doctor review is required before structured values are accepted
raw OCR text is not exposed to Power BI
audit log records accept/edit/reject actions
```

**What this completion gate means:** each bullet is a firm requirement before considering OCR done. `simple lab upload works first` means the file upload, storage, and basic doctor review flow must be stable before adding OCR on top. `OCR provider is behind an interface` means the real vendor can be swapped without changing the service layer. `draft extraction is stored separately` means OCR values are in their own tables, not mixed with doctor-accepted values. `doctor review is required` means there is no code path that promotes OCR output to structured data without a human in the loop. `raw OCR text not exposed to Power BI` means the analytics views exclude the unstructured OCR output. `audit log records accept/edit/reject` means every review action is traceable.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of all dev cloud resources.
- `make cloud-pause ENV=dev` pauses pausable resources to reduce cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment with explicit confirmation.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` creates or resumes the dev environment.
- `make cloud-status ENV=dev` confirms all resources are healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
