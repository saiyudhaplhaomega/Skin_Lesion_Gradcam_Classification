# Customer Dashboard Handholding Guide

Use this after lesion profiles, body-location records, privacy modes, and analysis events exist.

## Command Location

Run commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` changes the current PowerShell directory.
- This path is the main workspace that contains both the backend and frontend repositories.
- Starting here matters because this guide switches between backend and frontend folders.

This guide uses:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo list means:
- `Skin_Lesion_Classification_backend` contains FastAPI routes, database services, and tests.
- `Skin_Lesion_Classification_frontend` contains Next.js dashboard pages and UI code.
- When a step says “current repo,” make sure your terminal is inside the matching folder.

## Goal

Give the user one safe place to:

```text
track lesions
see recent AI analyses
understand changes over time
manage privacy and consent
upload lab results
prepare information for doctor review
```

What this feature list means:
- The dashboard is the user’s main monitoring area.
- It should show lesion tracking, recent AI analyses, time-based changes, consent controls, lab result uploads, and doctor-review preparation.
- These are workflow features, not diagnosis features.

The dashboard should feel like a personal skin-monitoring dashboard, not a cancer-prediction dashboard.

Why: the dashboard organizes monitoring and review tasks without implying that the app replaces clinical diagnosis.

## Step 1: Backend Dashboard Summary

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The next backend files must be created inside `Skin_Lesion_Classification_backend`.
- If your terminal is still in the root workspace or frontend folder, change directories before continuing.

Command:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

What this command block does:
- `cd Skin_Lesion_Classification_backend` enters the backend repository.
- `.\.venv\Scripts\Activate.ps1` activates the backend virtual environment on Windows PowerShell.
- Activating the virtual environment makes `pytest`, FastAPI, SQLAlchemy, and project dependencies available.

Create `app/schemas/dashboard_schema.py`:

```python
from datetime import datetime
from pydantic import BaseModel


class DashboardSummaryResponse(BaseModel):
    total_lesions: int
    lesions_needing_followup: int
    recent_analyses: int            # analyses in the last 30 days
    pending_doctor_reviews: int
    next_reminder_date: datetime | None
    lab_results_pending_review: int
    storage_mode: str
    account_status: str             # "active" | "pending_approval" | "suspended" | "expired"


class ActivityEvent(BaseModel):
    event_type: str
    summary: str
    occurred_at: datetime
    lesion_id: str | None = None


class DashboardActivityResponse(BaseModel):
    events: list[ActivityEvent]
    total: int
```

What this schema code does:
- `datetime` is imported so response fields can include dates and times.
- `BaseModel` is Pydantic’s base class for request and response schemas.
- `DashboardSummaryResponse` defines the JSON shape for the dashboard summary cards.
- `total_lesions`, `lesions_needing_followup`, `recent_analyses`, and `pending_doctor_reviews` are integer counts shown in the UI.
- `next_reminder_date: datetime | None` allows either a real reminder date or `null`.
- `lab_results_pending_review` counts lab uploads waiting for review.
- `storage_mode` tells the frontend whether the account is using metadata-only, balanced, or image-storage mode.
- `account_status` gives the frontend a simple account state to display or enforce.
- `ActivityEvent` defines one row in the activity feed.
- `lesion_id: str | None = None` means an event may or may not be tied to a lesion.
- `DashboardActivityResponse` wraps a list of activity events plus a total count.

Create `app/services/dashboard_service.py`:

```python
"""
Dashboard service - aggregates data from multiple tables for the patient dashboard.
Reads from the same DB as writes (fine at portfolio scale).
For production: move to a read replica or materialized view.
"""
from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.models.lesion import Lesion
from app.models.training_case import TrainingCase, TrainingCaseStatus
from app.schemas.dashboard_schema import ActivityEvent, DashboardActivityResponse, DashboardSummaryResponse


def get_dashboard_summary(db: Session, user_id: uuid.UUID) -> DashboardSummaryResponse:
    total_lesions = db.query(Lesion).filter(Lesion.patient_id == user_id).count()

    # Lesions needing follow-up: doctor review pending or location unverified
    followup = (
        db.query(Lesion)
        .filter(
            Lesion.patient_id == user_id,
            Lesion.body_location_status.in_(["patient_submitted", "disputed"]),
        )
        .count()
    )

    # Recent analyses: cases uploaded in the last 30 days
    since = datetime.utcnow() - timedelta(days=30)
    recent = (
        db.query(TrainingCase)
        .join(Lesion, TrainingCase.image_key.contains(str(user_id)))
        .filter(TrainingCase.created_at >= since)
        .count()
    )

    return DashboardSummaryResponse(
        total_lesions=total_lesions,
        lesions_needing_followup=followup,
        recent_analyses=recent,
        pending_doctor_reviews=0,       # wire up after DoctorReview model exists
        next_reminder_date=None,        # wire up after Reminder model exists
        lab_results_pending_review=0,   # wire up after LabResult model exists
        storage_mode="privacy_balanced",
        account_status="active",
    )


def get_activity_feed(db: Session, user_id: uuid.UUID, limit: int = 20) -> DashboardActivityResponse:
    # Placeholder: return lesion creation events from the DB
    lesions = (
        db.query(Lesion)
        .filter(Lesion.patient_id == user_id)
        .order_by(Lesion.created_at.desc())
        .limit(limit)
        .all()
    )
    events = [
        ActivityEvent(
            event_type="lesion_created",
            summary=f"Lesion profile created: {l.user_label or 'unnamed'}",
            occurred_at=l.created_at,
            lesion_id=str(l.id),
        )
        for l in lesions
    ]
    return DashboardActivityResponse(events=events, total=len(events))
```

What this service code does:
- The docstring explains that this service aggregates dashboard data from several database tables.
- `from __future__ import annotations` improves type-hint handling.
- `uuid` is used because user IDs are UUIDs.
- `datetime` and `timedelta` calculate the “last 30 days” window.
- `Session` is the SQLAlchemy database session type.
- `Lesion` and `TrainingCase` are database models used to count lesions and recent uploads.
- The dashboard schema imports define the response objects this service returns.
- `get_dashboard_summary` accepts a database session and the current user ID.
- The first query counts all lesions owned by that user.
- The follow-up query counts lesions where body location still needs verification or correction.
- `since = datetime.utcnow() - timedelta(days=30)` creates the cutoff for recent analyses.
- The recent analysis query counts training cases created after that cutoff.
- The returned `DashboardSummaryResponse` packages summary values into one validated object.
- Several fields are placeholders until doctor review, reminders, and lab result models are wired in.
- `get_activity_feed` loads recent lesions for the user and converts them into activity events.
- `.order_by(Lesion.created_at.desc())` shows newest events first.
- `.limit(limit)` prevents the feed from returning too many rows.
- The list comprehension creates one `ActivityEvent` per lesion.

Create `app/api/v1/dashboard.py`:

```python
import uuid

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.dashboard_schema import DashboardActivityResponse, DashboardSummaryResponse
from app.services.dashboard_service import get_activity_feed, get_dashboard_summary

router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])

_PLACEHOLDER_USER = uuid.UUID("00000000-0000-0000-0000-000000000001")  # TODO: from JWT


@router.get("/summary", response_model=DashboardSummaryResponse)
def dashboard_summary(db: Session = Depends(get_db)) -> DashboardSummaryResponse:
    return get_dashboard_summary(db, _PLACEHOLDER_USER)


@router.get("/activity", response_model=DashboardActivityResponse)
def dashboard_activity(db: Session = Depends(get_db)) -> DashboardActivityResponse:
    return get_activity_feed(db, _PLACEHOLDER_USER)
```

What this API code does:
- `uuid` creates the placeholder user ID.
- `APIRouter` creates a group of dashboard routes.
- `Depends` lets FastAPI inject the database session.
- `Session` is the SQLAlchemy session type.
- `get_db` provides a database session for each request.
- The schema imports tell FastAPI what response shape each endpoint returns.
- The service imports provide the actual dashboard data.
- `router = APIRouter(prefix="/api/v1/dashboard", tags=["dashboard"])` puts both routes under `/api/v1/dashboard`.
- `_PLACEHOLDER_USER` is temporary until authentication/JWT support is connected.
- `@router.get("/summary", response_model=DashboardSummaryResponse)` creates `GET /api/v1/dashboard/summary`.
- `dashboard_summary` calls `get_dashboard_summary` and returns validated JSON.
- `@router.get("/activity", response_model=DashboardActivityResponse)` creates `GET /api/v1/dashboard/activity`.
- `dashboard_activity` calls `get_activity_feed` for the same placeholder user.

Register in `app/main.py`:

```python
from app.api.v1 import dashboard
app.include_router(dashboard.router)
```

What this code does:
- `from app.api.v1 import dashboard` imports the router module created above.
- `app.include_router(dashboard.router)` attaches the dashboard routes to the main FastAPI app.
- Without this registration, the route file can exist but requests to `/api/v1/dashboard/...` will return 404.

Check:

```powershell
pytest
curl http://localhost:8000/api/v1/dashboard/summary
```

What this command block does:
- `pytest` runs the backend test suite.
- `curl http://localhost:8000/api/v1/dashboard/summary` calls the new summary endpoint on the local backend server.
- The `curl` command requires the backend server to be running in another terminal.

Expected result: `GET /api/v1/dashboard/summary` returns JSON with total lesions, follow-up count, recent analyses.

## Step 2: Backend Activity Feed

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- This step is backend-only.
- Add the activity route and supporting logic inside `Skin_Lesion_Classification_backend`.

Add:

```text
GET /api/v1/dashboard/activity
```

What this endpoint block means:
- This is the route the frontend will call to fetch recent dashboard activity.
- It should return activity for the current user only.

Activity events:

```text
image uploaded
analysis completed
Grad-CAM generated
body location submitted
body location approved/corrected/rejected
doctor review added
lab result uploaded
lab result reviewed
consent updated
report generated
reminder created
image deleted
```

What this activity list means:
- Each line is an event type the dashboard may show over time.
- These events should eventually come from audit logs or activity tables.
- The feed must avoid showing events from other users.

Check:

```powershell
make test
```

What this command does:
- `make test` runs the backend’s test target.
- It should include route, service, and privacy checks once those tests exist.

Expected result: activity feed reads from audit/activity sources without exposing other users' data.

## Step 3: Frontend Dashboard Pages

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this block means:
- The next page files belong in the frontend repository.
- Do not create Next.js pages inside the backend folder.

Command:

```powershell
cd ..\Skin_Lesion_Classification_frontend
```

What this command does:
- `cd ..\Skin_Lesion_Classification_frontend` moves from the backend folder up one level and into the frontend folder.
- Use this only if your terminal is currently inside `Skin_Lesion_Classification_backend`.

Create pages over time:

```text
app/dashboard/page.tsx
app/lesions/page.tsx
app/lesions/[lesionId]/page.tsx
app/body-map/page.tsx
app/analyze/page.tsx
app/lab-results/page.tsx
app/reports/page.tsx
app/privacy/page.tsx
app/reminders/page.tsx
app/education/page.tsx
```

What this page list means:
- Each path is a Next.js App Router page.
- `app/dashboard/page.tsx` is the main dashboard route.
- `app/lesions/page.tsx` lists lesions.
- `app/lesions/[lesionId]/page.tsx` is a dynamic route for one lesion.
- The remaining pages separate body map, analysis, lab results, reports, privacy, reminders, and education workflows.

MVP navigation:

```text
Dashboard
My Lesions
Body Map
Analyze
Lab Results
Privacy
Reports
```

What this MVP navigation block means:
- These are the first navigation items the frontend should show.
- The MVP keeps the dashboard focused on the core patient workflow.

Full navigation:

```text
Dashboard
My Lesions
Body Map
Analyze
Lab Results
Reports
Doctor Reviews
Reminders
Privacy & Consent
Settings
Education
```

What this full navigation block means:
- This is the expanded navigation after doctor review, reminders, settings, and education pages exist.
- Start with MVP navigation first so the UI does not link to unfinished workflows too early.

Check:

```powershell
npm run type-check
npm run build
```

What this command block does:
- `npm run type-check` checks TypeScript types if the frontend package defines that script.
- `npm run build` runs the Next.js production build.
- The build verifies that routes compile and page imports are valid.

Expected result: routes build even if some pages initially render placeholder data.

If PowerShell says `npm` is not recognized in this local Codex environment, use the bundled Node runtime directly from the frontend repo:

```powershell
C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe node_modules\typescript\bin\tsc --noEmit
C:\Users\saiyu\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe node_modules\next\dist\bin\next build
```

What this fallback does:
- The first command runs the same TypeScript type-check that `npm run type-check` would run.
- The second command runs the same Next.js production build that `npm run build` would run.
- Use this fallback only when `node_modules` already exists but `npm` is not available on PATH.

## Step 4: Lesion List And Detail UX

Current repo:

```text
Skin_Lesion_Classification_frontend
```

What this block means:
- Lesion list and detail UI files belong in the frontend repository.
- The backend should provide data, but the user-facing layout is built in Next.js.

Lesion card fields:

```text
lesion label
body location
body location verification status
thumbnail if stored
last analysis date
latest triage level
follow-up status
doctor review status
```

What this card field block means:
- These are the fields each lesion card should eventually show.
- The card should help the user scan which lesions need attention without making a diagnosis claim.

Metadata-only copy:

```text
No image stored - metadata-only mode.
```

What this copy block means:
- Show this text when the user chose not to store the lesion image.
- It explains why a thumbnail or image history may be missing.

Unverified location copy:

```text
Location submitted by patient - awaiting doctor verification.
```

What this copy block means:
- Show this text when the body location came from the patient and has not been verified by a clinician.
- This prevents the UI from presenting patient-entered information as clinical confirmation.

Lesion detail sections:

```text
lesion summary
body location and verification status
image/history timeline
latest AI analysis
Grad-CAM view
segmentation view
change detection
user notes
doctor notes
related lab results
reports
privacy/storage setting
```

What this section list means:
- These are the areas that belong on a complete lesion detail page.
- They separate patient notes, doctor notes, AI analysis, Grad-CAM, lab results, reports, and privacy settings.
- Keeping sections separate makes the page easier for beginners and clinicians to understand.

Check:

```powershell
npm run type-check
npm run build
```

What this command block does:
- `npm run type-check` catches TypeScript problems in the lesion UI.
- `npm run build` confirms the Next.js app compiles after adding routes or components.

## Step 5: Reminders, Notifications, Privacy, Education

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means:
- This step touches both backend and frontend work.
- Backend code stores reminders, notifications, privacy settings, and education metadata.
- Frontend code displays and manages those workflows.

Build:

```text
follow-up reminders
notifications center
privacy and consent center
safety and education section
```

What this build list means:
- Follow-up reminders help users return to monitoring tasks.
- A notifications center groups app messages in one place.
- A privacy and consent center lets users manage storage and sharing choices.
- The safety and education section explains the app’s limits and clinical disclaimers.

Reminder examples:

```text
recheck this lesion in 30 days
monthly skin self-check
follow up after doctor review
retake image because quality was poor
upload updated lab result
```

What this reminder list means:
- These are user-facing reminder examples, not backend table names.
- Each reminder should be tied to a lesion, account task, doctor review, image quality issue, or lab result workflow.

Education topics:

```text
What does Grad-CAM mean?
What does confidence mean?
What is ABCDE?
How to take a better lesion photo
What does doctor-verified location mean?
What does lab result review mean?
When to seek professional review
What this app can and cannot do
```

What this education list means:
- These topics explain XAI and medical-safety concepts in beginner language.
- They should help users understand confidence, Grad-CAM, photo quality, verification, lab review, and when to seek professional care.

Check:

```powershell
cd ..\Skin_Lesion_Classification_backend
make test
cd ..\Skin_Lesion_Classification_frontend
npm run build
```

What this command block does:
- The first `cd` moves back into the backend repository.
- `make test` runs backend checks.
- The second `cd` moves into the frontend repository.
- `npm run build` confirms the frontend still compiles.

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
- `CONFIRM_DESTROY=YES` is the explicit safety confirmation for destructive shutdown behavior.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What these commands do:
- `make cloud-start ENV=dev` starts the development cloud environment again.
- `make cloud-status ENV=dev` confirms it is available before you continue.

If this guide was local-only, no cloud shutdown is needed.
