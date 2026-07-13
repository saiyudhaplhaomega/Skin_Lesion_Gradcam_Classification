# Lab Result Support Handholding Guide

Use this after privacy modes, consent, signed private storage, and doctor review basics exist.

## Command Location

Run commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- This guide uses both backend and frontend folders, so starting from the workspace avoids path confusion.

This guide uses:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo list means:
- Backend lab-result models, schemas, routes, and tests go in `Skin_Lesion_Classification_backend`.
- Frontend lab-result pages and components go in `Skin_Lesion_Classification_frontend`.

## Goal

Allow patients to upload or record relevant blood/lab results so doctors can review them alongside lesion images, AI analysis, Grad-CAM, body location, history, and symptoms.

Why: lab files are sensitive supporting context for review and must stay separate from AI image prediction logic.

Important:

```text
The AI should not diagnose from blood tests.
Blood/lab results are supporting clinical context for doctor review.
```

What this safety block means:
- Lab results must not become another AI diagnosis input in the MVP.
- They are uploaded so doctors can review context alongside lesion history and AI image analysis.

## Step 1: Backend Lab Result Model

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The lab-result model, schema, API route, migration, and tests belong in the backend repository.

Command:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

What this command block does:
- `cd Skin_Lesion_Classification_backend` enters the backend repo.
- `.\.venv\Scripts\Activate.ps1` activates the backend Python virtual environment.
- Activate the environment before running Alembic, pytest, or Python imports.

Create `app/models/lab_result.py`:

```python
import enum
import uuid
from datetime import datetime, date

from sqlalchemy import Boolean, Date, DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LabResultStatus(str, enum.Enum):
    uploaded = "uploaded"
    doctor_reviewed = "doctor_reviewed"
    rejected = "rejected"
    deleted = "deleted"


class LabResultFileType(str, enum.Enum):
    pdf = "pdf"
    image = "image"
    manual = "manual"


class LabResult(Base):
    __tablename__ = "lab_results"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    lesion_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("lesions.id"), nullable=True)
    file_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    file_type: Mapped[LabResultFileType] = mapped_column(
        Enum(LabResultFileType), default=LabResultFileType.pdf, nullable=False
    )
    test_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    lab_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    status: Mapped[LabResultStatus] = mapped_column(
        Enum(LabResultStatus), default=LabResultStatus.uploaded, nullable=False
    )
    patient_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    doctor_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    consent_to_share_with_doctor: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
```

What this model code does:
- `enum` defines fixed status and file-type values.
- `uuid` creates unique lab result IDs.
- `datetime` and `date` support created/updated timestamps and test dates.
- SQLAlchemy imports define database column types and relationships.
- `Mapped` and `mapped_column` are SQLAlchemy 2.0 typed model helpers.
- `Base` is the shared database model base.
- `LabResultStatus` restricts status to uploaded, doctor reviewed, rejected, or deleted.
- `LabResultFileType` restricts file type to PDF, image, or manual entry.
- `LabResult` defines the `lab_results` database table.
- `user_id` links the lab result to the patient.
- `lesion_id` is optional because a lab result may apply generally rather than to one lesion.
- `file_s3_key` stores the private storage key, not a public URL.
- `file_type` records whether the upload is a PDF, image, or manual entry.
- `test_date` and `lab_name` store optional metadata.
- `status` tracks upload/review/deletion workflow state.
- `patient_note` and `doctor_note` store separate notes.
- `consent_to_share_with_doctor` controls whether a doctor can review the file.
- `created_at` and `updated_at` timestamp the row.

Create `app/schemas/lab_result_schema.py`:

```python
import uuid
from datetime import date, datetime
from pydantic import BaseModel


class LabResultResponse(BaseModel):
    id: uuid.UUID
    lesion_id: uuid.UUID | None
    test_date: date | None
    lab_name: str | None
    status: str
    patient_note: str | None
    consent_to_share_with_doctor: bool
    created_at: datetime
    # file_s3_key intentionally excluded - never expose raw S3 keys

    model_config = {"from_attributes": True}


class DoctorReviewLabResult(BaseModel):
    doctor_note: str
    new_status: str   # "doctor_reviewed" | "rejected"
```

What this schema code does:
- `uuid` supports UUID response fields.
- `date` and `datetime` support test date and created-at fields.
- `BaseModel` is Pydantic’s schema base class.
- `LabResultResponse` defines what the API returns to the frontend.
- `file_s3_key` is intentionally excluded so raw private storage keys are never exposed.
- `model_config = {"from_attributes": True}` lets Pydantic build responses from SQLAlchemy rows.
- `DoctorReviewLabResult` defines the request body for a doctor review action.
- `doctor_note` stores the clinician’s note.
- `new_status` limits the intended status change to doctor-reviewed or rejected.

Create `app/api/v1/lab_results.py`:

```python
import uuid

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.lab_result import LabResult, LabResultFileType, LabResultStatus
from app.schemas.lab_result_schema import DoctorReviewLabResult, LabResultResponse

router = APIRouter(prefix="/api/v1/lab-results", tags=["lab-results"])

_PLACEHOLDER_USER = uuid.UUID("00000000-0000-0000-0000-000000000001")  # TODO: from JWT


@router.post("", response_model=LabResultResponse, status_code=201)
async def upload_lab_result(
    file: UploadFile = File(...),
    lab_name: str | None = Form(None),
    patient_note: str | None = Form(None),
    consent_to_share_with_doctor: bool = Form(False),
    db: Session = Depends(get_db),
) -> LabResultResponse:
    content_type = file.content_type or ""
    file_type = LabResultFileType.pdf if "pdf" in content_type else LabResultFileType.image
    s3_key = f"users/{_PLACEHOLDER_USER}/lab-results/{uuid.uuid4()}/{file.filename}"
    # TODO: wire real S3 upload using storage_service.py pattern

    lab = LabResult(
        user_id=_PLACEHOLDER_USER,
        file_s3_key=s3_key,
        file_type=file_type,
        lab_name=lab_name,
        patient_note=patient_note,
        consent_to_share_with_doctor=consent_to_share_with_doctor,
    )
    db.add(lab)
    db.commit()
    db.refresh(lab)
    return LabResultResponse.model_validate(lab)


@router.get("", response_model=list[LabResultResponse])
def list_lab_results(db: Session = Depends(get_db)) -> list[LabResultResponse]:
    results = db.query(LabResult).filter(LabResult.user_id == _PLACEHOLDER_USER).all()
    return [LabResultResponse.model_validate(r) for r in results]


@router.patch("/{lab_result_id}/doctor-review", response_model=LabResultResponse)
def doctor_review(
    lab_result_id: uuid.UUID,
    body: DoctorReviewLabResult,
    db: Session = Depends(get_db),
) -> LabResultResponse:
    lab = db.query(LabResult).filter(LabResult.id == lab_result_id).first()
    if not lab:
        raise HTTPException(status_code=404, detail="Lab result not found")
    if not lab.consent_to_share_with_doctor:
        raise HTTPException(status_code=403, detail="Patient has not consented to share with doctor")
    lab.doctor_note = body.doctor_note
    lab.status = LabResultStatus(body.new_status)
    db.commit()
    db.refresh(lab)
    return LabResultResponse.model_validate(lab)
```

What this API code does:
- `uuid` creates placeholder user IDs and handles UUID path values.
- FastAPI imports provide routing, dependency injection, file upload handling, form fields, errors, and uploaded file objects.
- `Session` is the SQLAlchemy database session type.
- `get_db` provides a database session for each request.
- `LabResult`, `LabResultFileType`, and `LabResultStatus` are the model and enums.
- The schema imports define response and doctor-review request shapes.
- `router = APIRouter(...)` groups lab-result endpoints under `/api/v1/lab-results`.
- `_PLACEHOLDER_USER` is temporary until JWT authentication supplies the real patient user.
- `upload_lab_result` is async because file upload handling can be asynchronous.
- `file: UploadFile = File(...)` requires an uploaded file.
- `Form(...)` fields read metadata from a multipart form request.
- `content_type` checks whether the upload looks like a PDF or image.
- `s3_key` builds the private storage key where the file will eventually be uploaded.
- The TODO reminds you to connect real S3 storage later.
- `LabResult(...)` creates the database row.
- `db.add`, `db.commit`, and `db.refresh` save the row and reload generated fields.
- `list_lab_results` returns lab results for the placeholder user only.
- `doctor_review` loads one lab result, returns 404 if missing, blocks access without consent, updates doctor note and status, commits, and returns a validated response.

Create `app/schemas/lab_result_schema.py`:

```python
import uuid
from datetime import date, datetime

from pydantic import BaseModel


class LabResultResponse(BaseModel):
    id: uuid.UUID
    lesion_id: uuid.UUID | None
    test_date: date | None
    lab_name: str | None
    file_type: str
    status: str
    patient_note: str | None
    doctor_note: str | None
    consent_to_share_with_doctor: bool
    created_at: datetime
    # file_s3_key intentionally excluded - never expose raw S3 keys

    model_config = {"from_attributes": True}


class DoctorReviewLabResult(BaseModel):
    doctor_note: str
    new_status: str  # "doctor_reviewed" | "rejected"
```

What this schema code does:
- `LabResultResponse` defines what the API returns to the frontend.
- `file_s3_key` is intentionally excluded so raw private storage keys are never exposed to clients.
- `model_config = {"from_attributes": True}` lets Pydantic build responses from SQLAlchemy rows.
- `DoctorReviewLabResult` defines the request body for a doctor review action.
- `new_status` accepts only `doctor_reviewed` or `rejected` — the route validates this.

Add to `app/models/__init__.py`:

```python
from app.models.lab_result import LabResult
```

What this code does:
- Importing `LabResult` helps Alembic discover the model when generating migrations.

Register in `app/main.py`:

```python
from app.api.v1 import lab_results
app.include_router(lab_results.router)
```

What this code does:
- The import loads the lab-result router module.
- `app.include_router(lab_results.router)` attaches its endpoints to the FastAPI application.

Migrate and check:

```powershell
alembic upgrade head
pytest
curl http://localhost:8000/api/v1/lab-results
```

What this command block does:
- `alembic upgrade head` applies the pre-written migration `g2e3f4a5b617_alter_lab_results_to_full_schema.py`.
- That migration renames columns, adds new columns, extends the status enum, and adds the `labresultfiletype` enum.
- If you are starting fresh (no existing `lab_results` table), you can use `--autogenerate` instead. If the table already exists from a prior guide, use the manual migration file.
- `pytest` runs backend tests.
- `curl` calls the local lab-results endpoint and requires the backend server to be running.

Expected result: lab result records can be created without requiring a lesion.

## Step 2: Consent And Privacy Rules

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Consent and privacy logic for lab results belongs in the backend.

Two consent types are enforced for lab results:

```text
consent_for_lab_result_storage:       implicit when patient uploads — file is only saved on submit
consent_for_lab_result_doctor_review: stored as consent_to_share_with_doctor on the LabResult row
```

What this consent block means:
- `consent_for_lab_result_storage` is satisfied by the patient voluntarily uploading the file.
- `consent_for_lab_result_doctor_review` is the checkbox field on the upload form, persisted in the database.
- The existing `Consent` model is prediction-centric (1:1 with Prediction). Lab results use the per-row `consent_to_share_with_doctor` boolean instead of a separate Consent row.

The consent enforcement logic lives in `app/services/lab_result_service.py`:

```python
import uuid

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.lab_result import LabResult, LabResultStatus
from app.services.audit_service import log_event


def assert_doctor_consent(lab: LabResult) -> None:
    """Raise 403 if the patient has not consented to doctor access."""
    if not lab.consent_to_share_with_doctor:
        raise HTTPException(
            status_code=403,
            detail="Patient has not consented to share this lab result with a doctor.",
        )


def get_lab_result_for_user(db: Session, lab_result_id: uuid.UUID, user_id: uuid.UUID) -> LabResult:
    """Load a lab result and verify ownership. Raise 404 if not found."""
    lab = db.query(LabResult).filter(LabResult.id == lab_result_id, LabResult.user_id == user_id).first()
    if not lab:
        raise HTTPException(status_code=404, detail="Lab result not found.")
    return lab


def get_lab_result_for_doctor(db: Session, lab_result_id: uuid.UUID, doctor_id: uuid.UUID) -> LabResult:
    """Load a lab result for doctor access. Enforces consent and logs audit event."""
    lab = db.query(LabResult).filter(LabResult.id == lab_result_id).first()
    if not lab:
        raise HTTPException(status_code=404, detail="Lab result not found.")
    assert_doctor_consent(lab)
    log_event(db, "lab_result_viewed_by_doctor", "doctor", actor_id=doctor_id,
              target_type="lab_result", target_id=str(lab_result_id))
    return lab


def soft_delete_lab_result(db: Session, lab: LabResult, actor_id: uuid.UUID, actor_role: str) -> LabResult:
    """Mark lab result as deleted and emit audit event."""
    lab.status = LabResultStatus.deleted
    log_event(db, "lab_result_deleted", actor_role, actor_id=actor_id,
              target_type="lab_result", target_id=str(lab.id))
    db.commit()
    db.refresh(lab)
    return lab


def update_consent(db: Session, lab: LabResult, new_consent: bool, actor_id: uuid.UUID) -> LabResult:
    """Update consent_to_share_with_doctor and emit audit event."""
    old = lab.consent_to_share_with_doctor
    lab.consent_to_share_with_doctor = new_consent
    log_event(db, "lab_result_consent_changed", "patient", actor_id=actor_id,
              target_type="lab_result", target_id=str(lab.id), detail={"from": old, "to": new_consent})
    db.commit()
    db.refresh(lab)
    return lab
```

What this service code does:
- `assert_doctor_consent` is called in any route that allows doctor access. Raises 403 immediately if consent is False.
- `get_lab_result_for_user` enforces patient ownership — a patient cannot load another patient's result.
- `get_lab_result_for_doctor` calls `assert_doctor_consent` and logs `lab_result_viewed_by_doctor` in one call.
- `soft_delete_lab_result` sets status to `deleted` and logs `lab_result_deleted`. The row is never hard-deleted.
- `update_consent` logs `lab_result_consent_changed` with before/after values so the audit trail captures consent history.
- None of these functions commit except after a state change — they let the caller control the transaction.

Rules:

```text
lab result files are private
lab result files use encrypted storage
lab result access uses signed URLs
doctor access requires consent_to_share_with_doctor=True
lab result view/review/delete creates audit log
```

What this rules block means:
- Lab result files are sensitive and must stay private.
- Storage should be encrypted and access should use signed URLs (real S3 wiring is a TODO in the upload route).
- Doctor access requires both the doctor role and patient consent.
- Viewing, reviewing, deleting, and changing consent all write audit rows via `audit_service.log_event`.

Check:

```powershell
make test
```

What this command does:
- `make test` should run backend privacy and consent tests.

Expected result: tests reject doctor access when lab review consent is missing.

## Step 3: Lab Result Endpoints

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The endpoint implementation belongs in the backend repository.

Implement:

```text
POST   /api/v1/lab-results
GET    /api/v1/lab-results
GET    /api/v1/lab-results/{lab_result_id}
PATCH  /api/v1/lab-results/{lab_result_id}
DELETE /api/v1/lab-results/{lab_result_id}
PATCH  /api/v1/lab-results/{lab_result_id}/doctor-review
GET    /api/v1/reviews/{review_id}/lab-results
```

What this endpoint block means:
- These are the lab-result API routes needed for upload, listing, detail, update, deletion, doctor review, and linking lab results to doctor reviews.
- Each endpoint must enforce user ownership, consent, and permissions.

Important routing note: `GET /api/v1/reviews/{review_id}/lab-results` uses the `/api/v1/reviews` prefix and belongs in `app/api/v1/doctor_review.py`, not in `lab_results.py`. The `lab_results.py` router is prefixed at `/api/v1/lab-results` and cannot host that path without a second router registration.

Audit events:

```text
lab_result_uploaded
lab_result_viewed_by_doctor
lab_result_reviewed
lab_result_deleted
lab_result_consent_changed
```

What this audit-event block means:
- Each listed event should create an audit log row.
- Audit events make lab-result access and review traceable.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify endpoint permissions, consent behavior, and audit logging.

## Step 4: Frontend Lab Result Pages

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this block means:
- The lab-result UI files belong in the frontend repository.

Command:

```powershell
cd ..\Skin_Lesion_Classification_frontend
```

What this command does:
- This moves from the backend folder into the frontend folder.
- Use it only when your terminal is currently inside `Skin_Lesion_Classification_backend`.

Create:

```text
app/lab-results/page.tsx
components/lab-results/LabResultUpload.tsx
components/lab-results/LabResultList.tsx
components/lab-results/LabResultStatus.tsx
```

What this file list means:
- `app/lab-results/page.tsx` creates the lab-results page.
- `LabResultUpload.tsx` handles the upload form.
- `LabResultList.tsx` displays uploaded lab results.
- `LabResultStatus.tsx` displays uploaded, reviewed, rejected, or deleted states.

Update `app/lab-results/page.tsx` (replace the stub):

```tsx
import type { Metadata } from "next";
import { LabResultUpload } from "@/components/lab-results/LabResultUpload";
import { LabResultList } from "@/components/lab-results/LabResultList";

export const metadata: Metadata = {
  title: "Lab Results",
  robots: { index: false, follow: false },
};

export default function LabResultsPage() {
  return (
    <main className="dashboard-shell">
      <section className="dashboard-header">
        <p className="eyebrow">Lab Results</p>
        <h1>Your Lab Results</h1>
        <p>
          Upload blood tests or lab reports so your doctor can review them alongside your skin
          lesion history. Lab results are private and never used as AI diagnostic input.
        </p>
      </section>
      <section className="dashboard-section">
        <LabResultUpload />
      </section>
      <section className="dashboard-section">
        <LabResultList />
      </section>
    </main>
  );
}
```

What this page code does:
- Replaces the earlier stub with a real page that composes `LabResultUpload` and `LabResultList`.
- The safety note in the subtitle ("never used as AI diagnostic input") is intentional and should stay.

Create `components/lab-results/LabResultStatus.tsx`:

```tsx
type Status = "uploaded" | "doctor_reviewed" | "rejected" | "deleted" | string;

const STATUS_LABELS: Record<string, string> = {
  uploaded: "Uploaded",
  doctor_reviewed: "Reviewed by doctor",
  rejected: "Rejected",
  deleted: "Deleted",
};

const STATUS_CLASS: Record<string, string> = {
  uploaded: "badge badge--neutral",
  doctor_reviewed: "badge badge--success",
  rejected: "badge badge--warning",
  deleted: "badge badge--muted",
};

interface Props { status: Status; }

export function LabResultStatus({ status }: Props) {
  const label = STATUS_LABELS[status] ?? status;
  const cls = STATUS_CLASS[status] ?? "badge badge--neutral";
  return <span className={cls}>{label}</span>;
}
```

What this component code does:
- Maps each `LabResultStatus` enum value to a human-readable label and CSS badge class.
- Falls back to the raw status string if an unrecognised value arrives.

Create `components/lab-results/LabResultList.tsx`:

```tsx
"use client";

import { useEffect, useState } from "react";
import { LabResultStatus } from "./LabResultStatus";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

interface LabResult {
  id: string;
  lesion_id: string | null;
  test_date: string | null;
  lab_name: string | null;
  file_type: string;
  status: string;
  patient_note: string | null;
  doctor_note: string | null;
  consent_to_share_with_doctor: boolean;
  created_at: string;
}

export function LabResultList() {
  const [results, setResults] = useState<LabResult[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    fetch(`${API_BASE}/api/v1/lab-results`)
      .then((r) => { if (!r.ok) throw new Error(`${r.status}`); return r.json() as Promise<LabResult[]>; })
      .then(setResults)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  if (loading) return <p>Loading lab results…</p>;
  if (error) return <p className="error-msg">Could not load lab results: {error}</p>;
  if (results.length === 0) return <p>No lab results uploaded yet.</p>;

  return (
    <div className="lab-result-list">
      <h2>Uploaded Lab Results</h2>
      <table className="data-table">
        <thead>
          <tr>
            <th>Date</th><th>Lab</th><th>Type</th>
            <th>Status</th><th>Shared with doctor</th><th>Doctor note</th>
          </tr>
        </thead>
        <tbody>
          {results.map((r) => (
            <tr key={r.id}>
              <td>{r.test_date ?? r.created_at.slice(0, 10)}</td>
              <td>{r.lab_name ?? "—"}</td>
              <td>{r.file_type}</td>
              <td><LabResultStatus status={r.status} /></td>
              <td>{r.consent_to_share_with_doctor ? "Yes" : "No"}</td>
              <td>{r.doctor_note ?? "—"}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

What this component code does:
- Fetches lab results from `GET /api/v1/lab-results` on mount.
- Shows loading, error, and empty states before rendering the table.
- Uses `LabResultStatus` for the status badge.

Create `components/lab-results/LabResultUpload.tsx`:

```tsx
"use client";

import { useState } from "react";

const API_BASE = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8000";

export function LabResultUpload() {
  const [file, setFile] = useState<File | null>(null);
  const [labName, setLabName] = useState("");
  const [patientNote, setPatientNote] = useState("");
  const [shareWithDoctor, setShareWithDoctor] = useState(false);
  const [status, setStatus] = useState<"idle" | "uploading" | "success" | "error">("idle");
  const [errorMsg, setErrorMsg] = useState("");

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    if (!file) return;
    setStatus("uploading");
    setErrorMsg("");

    const form = new FormData();
    form.append("file", file);
    if (labName) form.append("lab_name", labName);
    if (patientNote) form.append("patient_note", patientNote);
    form.append("consent_to_share_with_doctor", String(shareWithDoctor));

    try {
      const res = await fetch(`${API_BASE}/api/v1/lab-results`, { method: "POST", body: form });
      if (!res.ok) throw new Error(`Upload failed: ${res.status}`);
      setStatus("success");
      setFile(null); setLabName(""); setPatientNote(""); setShareWithDoctor(false);
    } catch (err) {
      setStatus("error");
      setErrorMsg(err instanceof Error ? err.message : "Upload failed.");
    }
  }

  return (
    <div className="card">
      <h2>Upload Lab Result</h2>
      <p className="caption">
        Your doctor can only access this file if you check the sharing box below.
      </p>
      <form onSubmit={handleSubmit} className="form-stack">
        <label>
          <span className="label">Lab report file (PDF or image)</span>
          <input type="file" accept="application/pdf,image/*" required
            onChange={(e) => setFile(e.target.files?.[0] ?? null)} />
        </label>
        <label>
          <span className="label">Lab provider / lab name (optional)</span>
          <input type="text" placeholder="e.g. Charité Berlin"
            value={labName} onChange={(e) => setLabName(e.target.value)} />
        </label>
        <label>
          <span className="label">Your note (optional)</span>
          <textarea placeholder="Any context you want your doctor to know"
            value={patientNote} onChange={(e) => setPatientNote(e.target.value)} rows={3} />
        </label>
        <label className="checkbox-label">
          <input type="checkbox" checked={shareWithDoctor}
            onChange={(e) => setShareWithDoctor(e.target.checked)} />
          <span>Allow my doctor to view this lab result</span>
        </label>
        <button type="submit" disabled={!file || status === "uploading"} className="btn-primary">
          {status === "uploading" ? "Uploading…" : "Upload"}
        </button>
        {status === "success" && <p className="success-msg">Lab result uploaded successfully.</p>}
        {status === "error" && <p className="error-msg">{errorMsg}</p>}
      </form>
    </div>
  );
}
```

What this component code does:
- Sends a `multipart/form-data` POST to `/api/v1/lab-results`.
- The consent checkbox maps directly to `consent_to_share_with_doctor` in the backend.
- Resets the form on success.

MVP upload fields implemented:

```text
PDF lab report
image/photo of lab report
lab provider/lab name
patient note
share with doctor checkbox
```

Check:

```powershell
npm run type-check
npm run build
```

What this command block does:
- `npm run type-check` verifies frontend TypeScript types if that script exists.
- `npm run build` runs the Next.js production build.

Expected result: user can upload a lab file with metadata and see doctor review status.

## Step 5: Later Structured Lab Values

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Structured lab values are a later backend feature, not part of the MVP upload-only flow.

Later table:

```text
lab_result_values
id
lab_result_id
marker_name
marker_value
unit
reference_range
abnormal_flag nullable
created_at
```

What this table block means:
- This is the planned shape for extracted or manually entered lab values.
- It links each value to a lab result and stores marker name, value, unit, reference range, abnormal flag, and timestamp.

Possible values:

```text
WBC
CRP
ESR
Vitamin D
Liver markers
Inflammation markers
Other doctor-relevant values
```

What this values block means:
- These are examples of markers that might appear later.
- Do not hard-code clinical interpretation until a doctor-reviewed design exists.

Rule:

```text
Structured lab values and OCR should be clinician-guided later. MVP is file upload plus metadata.
```

What this rule block means:
- Start with simple file upload and metadata.
- Add OCR and structured values only after the clinical review workflow is designed.

Check:

```powershell
make test
```

What this command does:
- `make test` should continue passing after later structured lab-value changes.

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
