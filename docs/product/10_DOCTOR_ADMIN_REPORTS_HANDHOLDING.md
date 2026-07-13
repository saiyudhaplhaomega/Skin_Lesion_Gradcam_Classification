# Doctor Review, Admin Workflow, Reports, Roles, And Audit Handholding Guide

Use this after lesion history, consent, and analysis events exist.

Why: doctor and admin workflows need role-specific review, approval, and reporting surfaces instead of sharing the patient dashboard.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` changes PowerShell into the main workspace that contains the backend and frontend repositories.
- Start here because this guide switches between backend and frontend work.

This guide uses:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo list means:
- Backend files belong in `Skin_Lesion_Classification_backend`.
- Frontend dashboard files belong in `Skin_Lesion_Classification_frontend`.
- Check your terminal location before creating each file.

## Step 1: Role-Based Accounts

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- This step belongs in the backend repository.
- Role models and permission checks should be implemented server-side, not only in the frontend.

Create or extend:

```text
app/models/user.py
app/security/permissions.py
```

What this file list means:
- `app/models/user.py` stores the user account model and role field.
- `app/security/permissions.py` should contain reusable permission checks used by routes and services.

Roles:

```text
patient
doctor
admin
research_reviewer
```

What this roles block means:
- `patient` is the normal user uploading and reviewing their own data.
- `doctor` reviews assigned cases and adds clinical notes.
- `admin` manages approvals, audit views, and platform settings.
- `research_reviewer` can only access de-identified approved data.

Permission rules:

```text
patient: own uploads, own results, own consent, own deletion requests
doctor: assigned case review and notes
admin: approvals, training eligibility, audit, settings
research_reviewer: de-identified approved data only
```

What this permission block means:
- Each line defines what a role is allowed to do.
- These rules should be enforced in backend code before database data is returned or changed.
- Frontend hiding is helpful, but backend permission checks are the real security boundary.

Check:

```powershell
cd Skin_Lesion_Classification_backend
make test
```

What this command block does:
- `cd Skin_Lesion_Classification_backend` moves into the backend repo.
- `make test` runs the backend test target.
- Tests should prove role checks reject unauthorized access.

## Step 2: Doctor Review API

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The doctor review schema and route files belong in the backend repository.

The `DoctorReview` SQLAlchemy model was created in `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`.
Create the Pydantic schemas and FastAPI routes now.

Create `app/schemas/doctor_review_schema.py`:

```python
import uuid
from datetime import datetime
from pydantic import BaseModel


class DoctorReviewCreate(BaseModel):
    prediction_id: uuid.UUID
    decision: str   # "validated" | "corrected" | "inconclusive" | "rejected"
    corrected_label: str | None = None
    notes: str | None = None
    urgency: str | None = None   # "routine" | "follow_up" | "urgent"


class DoctorReviewResponse(BaseModel):
    id: uuid.UUID
    prediction_id: uuid.UUID
    doctor_id: uuid.UUID
    decision: str
    corrected_label: str | None
    notes: str | None
    reviewed_at: datetime | None
    created_at: datetime

    model_config = {"from_attributes": True}
```

What this schema code does:
- `uuid` is imported because prediction, review, and doctor IDs are UUIDs.
- `datetime` is imported for review timestamps.
- `BaseModel` is Pydantic’s base class for API schemas.
- `DoctorReviewCreate` defines the request body a doctor submits.
- `prediction_id` links the review to the AI prediction being reviewed.
- `decision` records the doctor’s decision, such as validated or corrected.
- `corrected_label`, `notes`, and `urgency` are optional because not every review needs them.
- `DoctorReviewResponse` defines the JSON shape returned by the API.
- `id`, `prediction_id`, and `doctor_id` identify the review, prediction, and reviewer.
- `reviewed_at` can be `None` if a review record exists before completion.
- `model_config = {"from_attributes": True}` lets Pydantic build the response from a SQLAlchemy model object.

Create `app/api/v1/doctor_review.py`:

```python
import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.doctor_review import DoctorReview, ReviewDecision
from app.schemas.doctor_review_schema import DoctorReviewCreate, DoctorReviewResponse

router = APIRouter(prefix="/api/v1/reviews", tags=["doctor-reviews"])

_PLACEHOLDER_DOCTOR = uuid.UUID("00000000-0000-0000-0000-000000000002")  # TODO: from JWT


@router.get("/pending", response_model=list[DoctorReviewResponse])
def list_pending_reviews(db: Session = Depends(get_db)) -> list[DoctorReviewResponse]:
    reviews = (
        db.query(DoctorReview)
        .filter(DoctorReview.decision == ReviewDecision.pending)
        .order_by(DoctorReview.created_at.asc())
        .all()
    )
    return [DoctorReviewResponse.model_validate(r) for r in reviews]


@router.post("", response_model=DoctorReviewResponse, status_code=201)
def submit_review(body: DoctorReviewCreate, db: Session = Depends(get_db)) -> DoctorReviewResponse:
    review = DoctorReview(
        prediction_id=body.prediction_id,
        doctor_id=_PLACEHOLDER_DOCTOR,
        decision=ReviewDecision(body.decision),
        corrected_label=body.corrected_label,
        notes=body.notes,
        reviewed_at=datetime.utcnow(),
    )
    db.add(review)
    db.commit()
    db.refresh(review)
    return DoctorReviewResponse.model_validate(review)


@router.get("/{review_id}", response_model=DoctorReviewResponse)
def get_review(review_id: uuid.UUID, db: Session = Depends(get_db)) -> DoctorReviewResponse:
    review = db.query(DoctorReview).filter(DoctorReview.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Review not found")
    return DoctorReviewResponse.model_validate(review)
```

What this API code does:
- `uuid` and `datetime` support UUID path values and review timestamps.
- `APIRouter` groups doctor-review routes.
- `Depends` injects the database session.
- `HTTPException` returns API errors like 404.
- `Session` is the SQLAlchemy session type.
- `get_db` provides the database session for each request.
- `DoctorReview` and `ReviewDecision` are database model objects.
- The schema imports define request and response shapes.
- `router = APIRouter(...)` puts routes under `/api/v1/reviews` and tags them for API docs.
- `_PLACEHOLDER_DOCTOR` is temporary until JWT authentication supplies the real doctor ID.
- `list_pending_reviews` queries pending reviews, sorts oldest first, and returns validated response objects.
- `submit_review` creates a new `DoctorReview` row from the request body.
- `ReviewDecision(body.decision)` converts the incoming string into the enum value.
- `db.add`, `db.commit`, and `db.refresh` save the row and reload generated fields.
- `get_review` loads one review by ID and returns 404 if it does not exist.

Register in `app/main.py`:

```python
from app.api.v1 import doctor_review
app.include_router(doctor_review.router)
```

What this code does:
- The import makes the doctor review router module available to the app.
- `app.include_router(...)` attaches those routes to FastAPI.
- Without this registration, the route file exists but the API endpoints are not reachable.

Check:

```powershell
pytest
curl http://localhost:8000/api/v1/reviews/pending
```

What this command block does:
- `pytest` runs backend tests.
- `curl` calls the pending doctor reviews endpoint on the local backend server.
- The `curl` command requires the FastAPI server to be running in another terminal.

Expected result: doctor notes and recommendation link to lesion and analysis event.

## Step 3: Doctor Body-Location Verification

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Body-location verification routes and tests belong in the backend.

Use the body-location endpoints from:

```text
docs/product/05_LESION_BODY_MAPPING_HANDHOLDING.md
```

What this reference block means:
- Reuse the body-location API design from the earlier lesion body mapping guide.
- Do not invent a second conflicting body-location workflow.

Doctor dashboard must show:

```text
patient-marked location
image of lesion
patient note
body region selected by patient
approve action
correct action
reject action
doctor note
```

What this dashboard-field block means:
- These are the pieces of evidence and actions the doctor needs for body-location verification.
- The doctor should see the patient’s submitted location, image context, notes, and approve/correct/reject actions.

Check:

```powershell
make test
```

What this command does:
- `make test` runs backend tests for body-location verification and audit logging.

Expected result: approve/correct/reject creates audit logs and preserves body-location history.

## Step 4: Dermatology-Style Case Summary

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The case summary service belongs in the backend because it aggregates protected clinical context.

Create:

```text
app/services/case_summary_service.py
```

What this path block means:
- Create a backend service file for assembling dermatology-style summaries.
- Keep summary-building logic out of route functions so it can be tested directly.

Summary fields:

```text
patient-reported location
first recorded date
latest image quality
AI prediction label and calibrated confidence
change since previous image
Grad-CAM attention summary
user symptoms and notes
body location verification status
lab result doctor-review status
professional review recommendation
```

What this summary-field block means:
- These fields describe the evidence a clinician or report needs.
- The summary combines location, time, quality, AI output, Grad-CAM, notes, lab review state, and professional review recommendation.
- It should not convert AI output into a diagnosis.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify the case summary service builds the expected fields and respects permissions.

## Step 5: PDF Case Report Export

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Report generation and report API files belong in the backend.

Create:

```text
app/services/report_service.py
app/api/v1/reports.py
```

What this file list means:
- `app/services/report_service.py` should assemble the report data and PDF content.
- `app/api/v1/reports.py` should expose API endpoints for requesting or downloading reports.

Report includes:

```text
original image or thumbnail
prediction result
confidence/reliability
Grad-CAM heatmap
segmentation mask
body-map location
timeline
image-quality notes
user notes
doctor notes
lab result status
model version
disclaimer
```

What this report-field block means:
- These are the sections that should appear in a case report.
- The report includes evidence and context, but must include a disclaimer and must not claim diagnosis.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify report creation, permissions, and disclaimer behavior.

Expected result: reports include disclaimer and do not claim diagnosis.

## Step 6: Lab Result Review Notes

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Lab result review notes belong in backend routes and services.

Create or extend:

```text
app/api/v1/lab_results.py
app/services/lab_result_service.py
```

What this file list means:
- `app/api/v1/lab_results.py` exposes lab-result endpoints.
- `app/services/lab_result_service.py` contains reusable business logic for review, consent, and audit behavior.

Doctor lab workflow:

```text
view lab result if consent allows
add doctor note
mark uploaded / doctor_reviewed / rejected / deleted
keep lab result as context, not AI diagnostic evidence
```

What this workflow block means:
- A doctor can view a lab result only when consent and permissions allow it.
- Doctor notes and status changes should be saved.
- Lab results are clinical context for review, not input that changes the AI image prediction event.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify consent, doctor review notes, and report context behavior.

Expected result: lab result review notes appear in doctor review and PDF report context without changing analysis events.

## Step 7: Audit Logging

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Audit logging is backend infrastructure and must be enforced server-side.

Create `app/models/audit_log.py`:

```python
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class AuditLog(Base):
    """
    Append-only audit trail. Nothing in the system is allowed to UPDATE or DELETE rows here.
    Add a DB-level trigger in production: BEFORE UPDATE OR DELETE ON audit_logs RAISE.
    """
    __tablename__ = "audit_logs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    actor_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    actor_role: Mapped[str] = mapped_column(String(50), nullable=False)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    target_type: Mapped[str | None] = mapped_column(String(50), nullable=True)   # "lesion" | "prediction" | "consent" ...
    target_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    detail_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    occurred_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

What this model code does:
- `uuid` creates unique audit log IDs.
- `datetime` timestamps when the event occurred.
- SQLAlchemy imports define database column types and foreign keys.
- `Mapped` and `mapped_column` are SQLAlchemy 2.0 typing helpers for model fields.
- `Base` is the declarative base class for backend database models.
- `AuditLog` defines the `audit_logs` table.
- The docstring states the table must be append-only, meaning rows should not be updated or deleted.
- `id` is the primary key.
- `actor_id` optionally links the event to a user.
- `actor_role` records whether the actor was patient, doctor, admin, or another role.
- `event_type` names what happened.
- `target_type` and `target_id` identify the object affected by the event.
- `detail_json` stores extra structured details as JSON text.
- `occurred_at` records when the event was created.

Create `app/services/audit_service.py`:

```python
import json
import uuid
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.audit_log import AuditLog


def log_event(
    db: Session,
    event_type: str,
    actor_role: str,
    actor_id: uuid.UUID | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    detail: dict | None = None,
) -> None:
    entry = AuditLog(
        actor_id=actor_id,
        actor_role=actor_role,
        event_type=event_type,
        target_type=target_type,
        target_id=str(target_id) if target_id else None,
        detail_json=json.dumps(detail) if detail else None,
    )
    db.add(entry)
    # Do NOT commit here - let the caller control the transaction


# Usage example in a route:
#   log_event(db, "image_uploaded", "patient", actor_id=user_id, target_type="lesion", target_id=lesion.id)
#   db.commit()
```

What this service code does:
- `json` serializes optional detail dictionaries into text.
- `uuid` types actor IDs.
- `datetime` is imported but not used in this snippet because the model sets the timestamp.
- `Session` types the database session.
- `AuditLog` is the model being written.
- `log_event` is a reusable helper for routes and services.
- The function accepts event type, actor role, optional actor ID, target information, and optional details.
- `target_id=str(target_id) if target_id else None` stores target IDs consistently as strings.
- `detail_json=json.dumps(detail)` stores detail dictionaries in the audit row.
- `db.add(entry)` stages the audit row for saving.
- The function intentionally does not commit, so the caller can save the business action and audit row in one transaction.
- The usage example shows calling `log_event` before `db.commit()`.

Add to `app/models/__init__.py`:

```python
from app.models.audit_log import AuditLog
```

What this code does:
- Importing `AuditLog` in `app/models/__init__.py` helps Alembic discover the model during autogeneration.

Migrate:

```powershell
alembic revision --autogenerate -m "add audit logs"
alembic upgrade head
```

What this command block does:
- `alembic revision --autogenerate -m "add audit logs"` creates a migration by comparing models to the database.
- `alembic upgrade head` applies the newest migration to the database.

Check:

```powershell
make test
```

What this command does:
- `make test` should verify protected actions create audit rows.

Expected result: protected actions write audit rows.

## Step 8: Frontend Dashboards

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this block means:
- The doctor and admin dashboard UI files belong in the frontend repository.

Create:

```text
app/doctor/page.tsx
app/admin/page.tsx
components/doctor/DoctorCaseQueue.tsx
components/admin/AdminReviewDashboard.tsx
```

What this file list means:
- `app/doctor/page.tsx` creates the doctor dashboard route.
- `app/admin/page.tsx` creates the admin dashboard route.
- `DoctorCaseQueue.tsx` should list cases awaiting doctor review.
- `AdminReviewDashboard.tsx` should show admin approvals, audit, and training eligibility views.

Build:

```text
doctor case queue
case detail evidence viewer
doctor notes and status form
admin approval queue
audit log table
training eligibility dashboard
PDF report action
```

What this build list means:
- These are the expected doctor/admin dashboard features.
- The doctor view focuses on case review and notes.
- The admin view focuses on approvals, audit logs, training eligibility, and report actions.

Check:

```powershell
cd ..\Skin_Lesion_Classification_frontend
npm run type-check
npm run build
```

What this command block does:
- `cd ..\Skin_Lesion_Classification_frontend` moves from backend to frontend if needed.
- `npm run type-check` verifies TypeScript types if the script exists.
- `npm run build` runs the Next.js production build.

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
