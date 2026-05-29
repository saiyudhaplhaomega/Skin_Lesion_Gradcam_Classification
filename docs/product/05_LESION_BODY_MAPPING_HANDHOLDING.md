# Lesion History, 2D Body Map, And 3D Body Map Handholding Guide

Use this after upload, analysis, and local database migrations work.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does: moves the terminal to the main workspace before switching into backend or frontend repos.

This guide uses two repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means:

- `Skin_Lesion_Classification_backend` owns lesion tables, APIs, history, and doctor verification logic.
- `Skin_Lesion_Classification_frontend` owns the 2D/3D body map UI and lesion timeline components.

## Goal

Turn isolated uploads into persistent lesion histories with both 2D and 3D location support. Patient-entered body location is unverified until a doctor approves, corrects, or rejects it.

## Step 1: Backend Lesion Table And Location History

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: the next commands and file paths are for the backend repo.

Command:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

What this command block does:

- `cd Skin_Lesion_Classification_backend` enters the backend repo.
- `.\.venv\Scripts\Activate.ps1` activates the backend Python virtual environment.

Create `app/models/body_location_record.py`:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class BodyLocationStatus(str, enum.Enum):
    unknown = "unknown"
    patient_submitted = "patient_submitted"
    doctor_verified = "doctor_verified"
    doctor_corrected = "doctor_corrected"
    rejected = "rejected"
    disputed = "disputed"


class BodyLocationSource(str, enum.Enum):
    patient_2d = "patient_2d"
    patient_3d = "patient_3d"
    doctor_correction = "doctor_correction"


class BodyLocationRecord(Base):
    __tablename__ = "body_location_records"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    lesion_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesions.id"), nullable=False)
    submitted_by_user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    submitted_by_role: Mapped[str] = mapped_column(String(50), nullable=False)
    source: Mapped[BodyLocationSource] = mapped_column(Enum(BodyLocationSource), nullable=False)

    # 2D map fields
    body_region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    body_side: Mapped[str | None] = mapped_column(String(20), nullable=True)
    body_map_x: Mapped[float | None] = mapped_column(Float, nullable=True)
    body_map_y: Mapped[float | None] = mapped_column(Float, nullable=True)

    # 3D map fields
    body_model_version: Mapped[str | None] = mapped_column(String(50), nullable=True)
    mesh_region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    uv_x: Mapped[float | None] = mapped_column(Float, nullable=True)
    uv_y: Mapped[float | None] = mapped_column(Float, nullable=True)

    note: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[BodyLocationStatus] = mapped_column(
        Enum(BodyLocationStatus), default=BodyLocationStatus.patient_submitted, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

What this model code does:

- `enum` creates controlled string choices for statuses and sources.
- `uuid` creates stable UUID IDs.
- `datetime` stores creation timestamps.
- SQLAlchemy imports define typed table columns and foreign keys.
- `BodyLocationStatus` tracks whether a location is unknown, patient-submitted, doctor-verified, corrected, rejected, or disputed.
- `BodyLocationSource` records where the location came from: patient 2D, patient 3D, or doctor correction.
- `BodyLocationRecord(Base)` declares the `body_location_records` table.
- `lesion_id` links the location to a lesion.
- `submitted_by_user_id` and `submitted_by_role` record who created the location record.
- `source` records whether the location came from 2D, 3D, or a doctor correction.
- `body_region`, `body_side`, `body_map_x`, and `body_map_y` store 2D body-map data.
- `body_model_version`, `mesh_region`, `uv_x`, and `uv_y` store 3D body-map data.
- `note` stores optional context.
- `status` stores verification state.
- `created_at` preserves location history order.

The `Lesion` model was defined in `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md` Step 4b. Extend it now with body location fields. Open `app/models/lesion.py` and add:

```python
# Add these fields to the existing Lesion model class:
body_location_status: Mapped[str] = mapped_column(
    String(50), default="unknown", nullable=False
)
current_body_location_record_id: Mapped[uuid.UUID | None] = mapped_column(
    nullable=True
)
first_seen_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
user_label: Mapped[str | None] = mapped_column(String(200), nullable=True)
```

What these lesion fields do:

- `body_location_status` stores the current location verification state on the lesion summary.
- `current_body_location_record_id` stores the active body location record ID.
- `first_seen_at` records when this lesion was first tracked.
- `user_label` lets the user name the lesion, such as "mole near elbow."

Why this field is not a database foreign key: `body_location_records.lesion_id` already points to `lesions.id`. Adding a second FK from `lesions.current_body_location_record_id` back to `body_location_records.id` creates a cyclic dependency that Alembic warns it cannot sort cleanly. Keep the pointer as a UUID column and enforce "current record belongs to this lesion" in the service/API layer until there is a stronger reason to add a named, deliberately managed constraint.

Add to `app/models/__init__.py`:

```python
from app.models.body_location_record import BodyLocationRecord
```

What this import does: registers the body location model so Alembic can discover it during migration generation.

Why: patients may mark the wrong location. Doctors need to approve, correct, or reject the location while preserving history.

Check:

```powershell
alembic revision --autogenerate -m "add lesions and body location records"
alembic upgrade head
make test
```

What this command block does:

- `alembic revision --autogenerate ...` creates a migration for lesion/body-location model changes.
- `alembic upgrade head` applies the migration.
- `make test` runs backend tests after schema changes.

Review the generated migration before applying it:

- It should create `body_location_records`.
- It should add `body_location_status`, `current_body_location_record_id`, `first_seen_at`, and `user_label` to `lesions`.
- It should not create a foreign key from `lesions.current_body_location_record_id` back to `body_location_records.id`.
- If it adds non-null columns to an existing table, use temporary `server_default` values in the migration, then remove those defaults with `op.alter_column(...)`.
- In `downgrade()`, drop PostgreSQL enum types such as `bodylocationstatus` and `bodylocationsource` after dropping `body_location_records`.

Why: migration autogeneration is a draft. Review it so local databases with existing rows can upgrade cleanly, and so downgrade/upgrade cycles do not fail on leftover PostgreSQL enum types.

## Step 2: Same Lesion Or New Lesion API

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: stay in the backend repo for the lesion API work.

Create `app/api/v1/lesions.py`:

```python
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.lesion import Lesion
from app.models.user import AccountStatus, User, UserRole
from app.schemas.lesion_schema import LesionCreate, LesionListResponse, LesionResponse

router = APIRouter(prefix="/api/v1/lesions", tags=["lesions"])
PLACEHOLDER_PATIENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")


def _ensure_placeholder_patient(db: Session) -> uuid.UUID:
    patient = db.query(User).filter(User.id == PLACEHOLDER_PATIENT_ID).first()
    if not patient:
        patient = User(
            id=PLACEHOLDER_PATIENT_ID,
            cognito_sub="local-placeholder-patient",
            email="local-patient@example.test",
            role=UserRole.patient,
            status=AccountStatus.active,
        )
        db.add(patient)
        db.flush()
    return PLACEHOLDER_PATIENT_ID


@router.post("", response_model=LesionResponse, status_code=201)
def create_lesion(body: LesionCreate, db: Session = Depends(get_db)) -> LesionResponse:
    # TODO: replace hardcoded patient_id with authenticated user from JWT token
    patient_id = _ensure_placeholder_patient(db)
    lesion = Lesion(
        patient_id=patient_id,
        body_region=body.body_region,
        user_label=body.user_label,
        notes=body.notes,
    )
    db.add(lesion)
    db.commit()
    db.refresh(lesion)
    return LesionResponse.model_validate(lesion)


@router.get("", response_model=LesionListResponse)
def list_lesions(db: Session = Depends(get_db)) -> LesionListResponse:
    patient_id = _ensure_placeholder_patient(db)
    lesions = db.query(Lesion).filter(Lesion.patient_id == patient_id).all()
    return LesionListResponse(
        lesions=[LesionResponse.model_validate(l) for l in lesions],
        total=len(lesions),
    )


@router.get("/{lesion_id}", response_model=LesionResponse)
def get_lesion(lesion_id: uuid.UUID, db: Session = Depends(get_db)) -> LesionResponse:
    lesion = db.query(Lesion).filter(Lesion.id == lesion_id).first()
    if not lesion:
        raise HTTPException(status_code=404, detail="Lesion not found")
    return LesionResponse.model_validate(lesion)
```

What this API code does:

- `uuid` handles UUID parsing and placeholder user IDs.
- `APIRouter` groups lesion routes under one router.
- `Depends` injects dependencies such as the database session.
- `HTTPException` returns controlled API errors such as 404.
- `Session` is the SQLAlchemy database session type.
- `get_db` provides one database session per request.
- `Lesion` is the SQLAlchemy model.
- `LesionCreate`, `LesionListResponse`, and `LesionResponse` are Pydantic contracts.
- `router = APIRouter(...)` creates `/api/v1/lesions` routes.
- `create_lesion(...)` creates one lesion for the current patient, commits it, refreshes it, and returns a response schema.
- `list_lesions(...)` fetches lesions for the current user and wraps them with a total count.
- `get_lesion(...)` fetches one lesion by ID or returns `404` if missing.
- The hardcoded patient ID is a placeholder until real JWT authentication is connected.
- `_ensure_placeholder_patient(...)` creates a local placeholder patient row so the foreign key from `lesions.patient_id` to `users.id` does not fail during local curl testing.

Register the router in `app/main.py`:

```python
from app.api.v1 import lesions
app.include_router(lesions.router)
```

What this code does:

- Imports the lesion router module.
- Attaches its routes to the main FastAPI app.

Check:

```powershell
pytest
curl -X POST http://localhost:8000/api/v1/lesions \
  -H "Content-Type: application/json" \
  -d '{"user_label": "mole on left arm"}'
```

What this command block does:

- `pytest` runs backend tests.
- `curl -X POST` sends a manual request to create a lesion.
- `-H "Content-Type: application/json"` tells the backend the body is JSON.
- `-d ...` sends the JSON body with a user label.

Expected result: analysis events link to `lesion_id`.

## Step 3: Body Location API And Doctor Verification

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: stay in the backend repo for body-location schemas and routes.

Create `app/schemas/body_location_schema.py`:

```python
import uuid
from pydantic import BaseModel


class BodyLocationSubmit(BaseModel):
    body_region: str
    body_side: str | None = None
    body_map_x: float | None = None
    body_map_y: float | None = None
    note: str | None = None
    source: str = "patient_2d"   # "patient_2d" | "patient_3d"


class BodyLocationCorrect(BaseModel):
    body_region: str
    body_side: str | None = None
    body_map_x: float | None = None
    body_map_y: float | None = None
    doctor_note: str | None = None


class BodyLocationResponse(BaseModel):
    id: uuid.UUID
    lesion_id: uuid.UUID
    body_region: str | None
    body_side: str | None
    status: str
    submitted_by_role: str

    model_config = {"from_attributes": True}
```

What this schema code does:

- `uuid` provides UUID field types.
- `BaseModel` creates Pydantic request/response schemas.
- `BodyLocationSubmit` describes patient-submitted 2D/3D location data.
- `BodyLocationCorrect` describes doctor correction input.
- `BodyLocationResponse` describes location data returned by the API.
- `model_config = {"from_attributes": True}` lets Pydantic build responses from SQLAlchemy objects.

Create `app/api/v1/body_locations.py`:

```python
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.body_location_record import BodyLocationRecord, BodyLocationSource, BodyLocationStatus
from app.models.lesion import Lesion
from app.models.user import AccountStatus, User, UserRole
from app.schemas.body_location_schema import (
    BodyLocationCorrect,
    BodyLocationResponse,
    BodyLocationSubmit,
)

router = APIRouter(prefix="/api/v1/lesions", tags=["body-locations"])
PLACEHOLDER_PATIENT_ID = uuid.UUID("00000000-0000-0000-0000-000000000001")
PLACEHOLDER_DOCTOR_ID = uuid.UUID("00000000-0000-0000-0000-000000000002")


def _ensure_placeholder_user(
    db: Session,
    user_id: uuid.UUID,
    cognito_sub: str,
    email: str,
    role: UserRole,
) -> uuid.UUID:
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        user = User(
            id=user_id,
            cognito_sub=cognito_sub,
            email=email,
            role=role,
            status=AccountStatus.active,
        )
        db.add(user)
        db.flush()
    return user_id


@router.post("/{lesion_id}/body-location", response_model=BodyLocationResponse, status_code=201)
def submit_body_location(
    lesion_id: uuid.UUID,
    body: BodyLocationSubmit,
    db: Session = Depends(get_db),
) -> BodyLocationResponse:
    lesion = db.query(Lesion).filter(Lesion.id == lesion_id).first()
    if not lesion:
        raise HTTPException(status_code=404, detail="Lesion not found")

    # TODO: get real user_id from JWT
    submitter_id = _ensure_placeholder_user(
        db,
        PLACEHOLDER_PATIENT_ID,
        "local-placeholder-patient",
        "local-patient@example.test",
        UserRole.patient,
    )

    record = BodyLocationRecord(
        lesion_id=lesion_id,
        submitted_by_user_id=submitter_id,
        submitted_by_role="patient",
        source=BodyLocationSource(body.source),
        body_region=body.body_region,
        body_side=body.body_side,
        body_map_x=body.body_map_x,
        body_map_y=body.body_map_y,
        note=body.note,
        status=BodyLocationStatus.patient_submitted,
    )
    db.add(record)
    db.flush()

    lesion.current_body_location_record_id = record.id
    lesion.body_location_status = BodyLocationStatus.patient_submitted.value
    db.commit()
    db.refresh(record)
    return BodyLocationResponse.model_validate(record)


@router.get("/{lesion_id}/body-location/history", response_model=list[BodyLocationResponse])
def get_body_location_history(
    lesion_id: uuid.UUID, db: Session = Depends(get_db)
) -> list[BodyLocationResponse]:
    records = (
        db.query(BodyLocationRecord)
        .filter(BodyLocationRecord.lesion_id == lesion_id)
        .order_by(BodyLocationRecord.created_at.desc())
        .all()
    )
    return [BodyLocationResponse.model_validate(r) for r in records]


@router.post("/{lesion_id}/body-location/{location_id}/approve")
def approve_body_location(
    lesion_id: uuid.UUID, location_id: uuid.UUID, db: Session = Depends(get_db)
) -> dict:
    record = db.query(BodyLocationRecord).filter(BodyLocationRecord.id == location_id).first()
    if not record:
        raise HTTPException(status_code=404, detail="Location record not found")
    record.status = BodyLocationStatus.doctor_verified
    lesion = db.query(Lesion).filter(Lesion.id == lesion_id).first()
    if lesion:
        lesion.body_location_status = BodyLocationStatus.doctor_verified.value
    db.commit()
    return {"status": "approved"}


@router.post("/{lesion_id}/body-location/{location_id}/correct")
def correct_body_location(
    lesion_id: uuid.UUID,
    location_id: uuid.UUID,
    body: BodyLocationCorrect,
    db: Session = Depends(get_db),
) -> BodyLocationResponse:
    # Doctor correction creates a NEW record (history is preserved)
    doctor_id = _ensure_placeholder_user(
        db,
        PLACEHOLDER_DOCTOR_ID,
        "local-placeholder-doctor",
        "local-doctor@example.test",
        UserRole.doctor,
    )  # TODO: from JWT
    correction = BodyLocationRecord(
        lesion_id=lesion_id,
        submitted_by_user_id=doctor_id,
        submitted_by_role="doctor",
        source=BodyLocationSource.doctor_correction,
        body_region=body.body_region,
        body_side=body.body_side,
        body_map_x=body.body_map_x,
        body_map_y=body.body_map_y,
        note=body.doctor_note,
        status=BodyLocationStatus.doctor_corrected,
    )
    db.add(correction)
    db.flush()
    lesion = db.query(Lesion).filter(Lesion.id == lesion_id).first()
    if lesion:
        lesion.current_body_location_record_id = correction.id
        lesion.body_location_status = BodyLocationStatus.doctor_corrected.value
    db.commit()
    db.refresh(correction)
    return BodyLocationResponse.model_validate(correction)
```

What this API code does:

- Imports UUID, datetime, FastAPI routing tools, SQLAlchemy sessions, models, and schemas.
- Creates a router under `/api/v1/lesions` because body location belongs to a lesion.
- `submit_body_location(...)` validates the lesion exists, creates a patient-submitted location record, updates the lesion summary, commits, and returns the record.
- `get_body_location_history(...)` returns all location records for a lesion ordered newest first.
- `approve_body_location(...)` marks an existing record as doctor verified and updates the lesion status.
- `correct_body_location(...)` creates a new doctor-correction record instead of overwriting patient history.
- The placeholder UUIDs represent future authenticated patient/doctor IDs from JWT.
- `_ensure_placeholder_user(...)` creates local placeholder user rows so foreign keys pass during curl testing.
- `db.flush()` gives the new body-location record its UUID before the lesion summary stores `current_body_location_record_id`.

Register in `app/main.py`:

```python
from app.api.v1 import body_locations
app.include_router(body_locations.router)
```

What this code does: imports and registers the body-location routes with the main FastAPI app.

Check:

```powershell
pytest
curl -X POST http://localhost:8000/api/v1/lesions/<lesion_id>/body-location \
  -H "Content-Type: application/json" \
  -d '{"body_region": "left_forearm", "body_side": "left", "body_map_x": 0.42, "body_map_y": 0.61}'
```

What this command block does:

- `pytest` runs backend tests.
- `curl -X POST` sends a body-location submission for one lesion.
- `<lesion_id>` must be replaced with a real lesion UUID.
- The JSON body sends body region, side, and normalized 2D coordinates.

Expected result: a correction creates a new active location record and supersedes the previous one instead of overwriting history.

## Step 4: 2D Body Map Frontend

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this means: switch to the frontend repo for the 2D body-map UI.

Command:

```powershell
cd ..\Skin_Lesion_Classification_frontend
```

What this command does: moves from the backend repo up one folder and into the frontend repo.

Create:

```text
components/body-map/BodyMap2D.tsx
components/body-map/bodyRegions.ts
```

What these files do:

- `BodyMap2D.tsx` will render the 2D body map and collect user clicks/selections.
- `bodyRegions.ts` will hold the fixed list of valid body regions so UI and API use consistent names.

Build UI states:

```text
front
back
left side
right side
face/scalp
hands
feet
```

What these states mean: the 2D map needs multiple views so users can place a lesion on the correct visible body area.

Stored data example:

```json
{
  "body_region": "left_forearm",
  "body_side": "left",
  "body_map_x": 0.42,
  "body_map_y": 0.61,
  "note": "mole near elbow",
  "source": "patient_submitted"
}
```

What this JSON example means:

- `body_region` stores the named anatomical region.
- `body_side` stores left/right when relevant.
- `body_map_x` and `body_map_y` store normalized 2D coordinates.
- `note` stores optional user context.
- `source` records that this location came from the patient submission workflow.

Customer UI examples:

```text
Location: Left forearm
Status: Submitted by you, awaiting doctor verification

Location: Left forearm
Status: Doctor verified

Location: Corrected by doctor from "upper arm" to "left forearm"
```

What this UI copy does:

- Shows the location in plain language.
- Separates patient-submitted, doctor-verified, and doctor-corrected states.
- Makes it clear when a location is not yet clinically verified.

Check:

```powershell
npm run type-check
npm run build
```

What this command block does:

- `npm run type-check` runs TypeScript checks without building output.
- `npm run build` creates a production Next.js build.

Expected result: the user can select a 2D body location before upload.

## Step 5: 3D Body Map Frontend

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this means: the 3D body map is also frontend work.

Create later in the sequence:

```text
components/body-map/BodyMap3D.tsx
components/body-map/BodyMapModeToggle.tsx
public/models/adult_generic_v1.glb
```

What these files do:

- `BodyMap3D.tsx` renders the 3D body map.
- `BodyMapModeToggle.tsx` switches between 2D and 3D modes.
- `adult_generic_v1.glb` is the 3D body model asset served from the public folder.

Implementation choice:

```text
Three.js plus React Three Fiber
GLB human body model
clickable mesh regions
lesion pins rendered on the surface
fallback to 2D map if 3D fails to load
```

What this implementation block means:

- Three.js provides browser 3D rendering.
- React Three Fiber lets React components control Three.js scenes.
- A GLB model stores the body mesh.
- Clickable mesh regions let users mark lesion location.
- Pins render selected lesion positions.
- The 2D fallback keeps the workflow usable if 3D rendering fails.

Stored 3D data:

```json
{
  "body_model": "adult_generic_v1",
  "mesh_region": "left_forearm",
  "uv_x": 0.238,
  "uv_y": 0.774,
  "surface_side": "front"
}
```

What this JSON example means:

- `body_model` records which 3D model version was used.
- `mesh_region` stores the named mesh/anatomical region.
- `uv_x` and `uv_y` store normalized coordinates on the model surface.
- `surface_side` records whether the location is on the front/back/side surface.

Check:

```powershell
npm run type-check
npm run build
```

What this command block does: verifies the 3D body-map frontend code type-checks and builds.

Expected result: 2D and 3D modes use the same backend lesion fields.

## Step 6: Lesion Timeline

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this means: the lesion timeline needs backend data endpoints and frontend timeline components.

Build:

```text
GET /api/v1/lesions/{lesion_id}/timeline
components/lesions/LesionTimeline.tsx
```

What this build block means:

- `GET /api/v1/lesions/{lesion_id}/timeline` is the backend endpoint that returns chronological lesion events.
- `components/lesions/LesionTimeline.tsx` is the frontend component that displays those events.

Timeline includes:

```text
image history
prediction history
Grad-CAM history
segmentation history
user notes
doctor notes
follow-up reminders
```

What this timeline data means:

- `image history` shows uploaded images over time.
- `prediction history` shows model outputs over time.
- `Grad-CAM history` shows explanation artifacts.
- `segmentation history` shows mask/boundary changes.
- `user notes` and `doctor notes` preserve human context.
- `follow-up reminders` show future action items.

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does:

- `make backend-test` verifies backend timeline behavior.
- `make frontend-build` verifies the frontend timeline component compiles.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks dev cloud resource state.
- `make cloud-pause ENV=dev` pauses dev resources where possible.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev resources after confirmation.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes dev cloud resources.
- `make cloud-status ENV=dev` verifies the state after startup.

If this guide was local-only, no cloud shutdown is needed.
