# Domain Model And API Contracts Handholding Guide

Use this before building migrations for the full platform. It is the source of truth for domain entities, immutability, and API groups.

## Command Location

Run commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

What this command block does:

- The first `cd` moves to the main workspace.
- The second `cd` moves into the backend repo where API contracts, schemas, and models belong.

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: all file paths and backend commands in this guide are relative to the backend repo.

## Goal

Do not treat every upload as an isolated prediction.

Why: the app needs stable patient, lesion, image, analysis, consent, review, and report contracts before feature guides add workflows on top.

Use this structure:

```text
User
  -> many Lesions
Lesion
  -> many Images
  -> many AnalysisEvents
  -> many BodyLocationRecords
  -> many DoctorReviews
  -> many Reports
  -> many Reminders
```

What this domain relationship block means:

- One `User` can own many `Lesions`.
- One `Lesion` can have many uploaded `Images`.
- One `Lesion` can have many `AnalysisEvents` over time.
- One `Lesion` can have many `BodyLocationRecords` because patient and doctor locations may change or be corrected.
- One `Lesion` can have many `DoctorReviews`.
- One `Lesion` can have many generated `Reports`.
- One `Lesion` can have many `Reminders`.
- This prevents the app from treating every image upload as an isolated event with no history.

## Step 1: Domain Entity List

Create models over time for:

```text
User
Lesion
BodyLocationRecord
Image
AnalysisEvent
Consent
DoctorReview
LabResult
LabResultValue
AuditLog
Report
ModelVersion
Reminder
Notification
UserPreferences
```

What these entities represent:

- `User` is the account/person record.
- `Lesion` is a tracked skin lesion over time.
- `BodyLocationRecord` stores patient-submitted and doctor-verified body-map location history.
- `Image` stores metadata for uploaded image files.
- `AnalysisEvent` stores a model run result.
- `Consent` stores consent state and version.
- `DoctorReview` stores clinician review decisions.
- `LabResult` and `LabResultValue` store lab-report uploads and parsed values.
- `AuditLog` stores protected action history.
- `Report` stores generated case report metadata.
- `ModelVersion` records model identity and promotion status.
- `Reminder` and `Notification` support follow-up workflows.
- `UserPreferences` stores user settings.

Check:

```powershell
make test
```

What this command does: runs backend tests after introducing or changing domain entities.

Expected result: each entity has a focused model and matching test when introduced.

## Step 2: Core Tables

Use these tables as the database contract:

```text
users
lesions
body_location_records
images
analysis_events
consents
doctor_reviews
lab_results
lab_result_values
audit_logs
reports
model_versions
reminders
notifications
user_preferences
```

What these table names do:

- Each table stores one major domain concept.
- Plural table names such as `users` and `lesions` follow common SQL naming style.
- The table list is the database contract that migrations and API code should converge toward.

Important: store file keys or private URLs in the database. Do not store raw image or lab-report binary data directly in PostgreSQL.

## Step 3: Immutability Rules

Editable:

```text
lesion label
lesion status
user notes
doctor notes
storage preference
follow-up reminder
notification preferences
user preferences
```

What this editable list means: these fields can change during normal product use, so they need update endpoints, permissions, and possibly audit entries.

Editable through verification workflow only:

```text
body location
```

What this means: body location can change, but not casually. It should move through patient submission and doctor verification/correction so the history remains trustworthy.

Mostly immutable:

```text
prediction result
confidence
calibrated confidence
triage level
model version
preprocessing version
Grad-CAM method
analysis timestamp
```

What this mostly immutable list means: analysis outputs should normally be preserved as historical facts. If the model is rerun later, create a new analysis event instead of rewriting the old one.

Append-only:

```text
consent history
audit logs
model version history
body location history
```

What append-only means:

- New records are added over time.
- Old records are not edited or deleted casually.
- This preserves medical, consent, audit, and model history.

Check:

```powershell
make test
```

What this command does: runs backend tests that should verify immutable and append-only behavior.

Expected result: tests prove analysis events and audit logs are created as new rows, not edited in place.

## Step 4: API Endpoint Groups

Use these endpoint groups:

```text
/api/v1/lesions
/api/v1/body-locations
/api/v1/images
/api/v1/analysis
/api/v1/explain-llm
/api/v1/consents
/api/v1/reviews
/api/v1/lab-results
/api/v1/reports
/api/v1/audit-logs
/api/v1/admin
/api/v1/dashboard
/api/v1/notifications
/api/v1/reminders
/api/v1/user/preferences
```

What these endpoint groups mean:

- Each path groups related API operations under `/api/v1`.
- `/api/v1/lesions` owns lesion identity and listing.
- `/api/v1/body-locations` owns body-map location workflow.
- `/api/v1/images` owns image upload/retrieval metadata.
- `/api/v1/analysis` owns model analysis events.
- `/api/v1/explain-llm` owns safe explanation generation.
- `/api/v1/consents` owns consent state.
- `/api/v1/reviews` owns doctor review workflow.
- `/api/v1/lab-results` owns lab upload and review.
- `/api/v1/reports` owns report generation and retrieval.
- `/api/v1/audit-logs` owns protected audit access.
- `/api/v1/admin` owns admin-only operations.
- `/api/v1/dashboard`, notifications, reminders, and preferences support user-facing app state.

Check:

```powershell
make test
```

What this command does: runs backend tests after route groups or endpoint contracts are added.

## Step 5: Lesion Endpoints

Implement:

```text
POST   /api/v1/lesions
GET    /api/v1/lesions
GET    /api/v1/lesions/{lesion_id}
PATCH  /api/v1/lesions/{lesion_id}
DELETE /api/v1/lesions/{lesion_id}
GET    /api/v1/lesions/{lesion_id}/timeline
GET    /api/v1/lesions/{lesion_id}/reports
```

What these lesion endpoints do:

- `POST /api/v1/lesions` creates a tracked lesion.
- `GET /api/v1/lesions` lists lesions visible to the current user.
- `GET /api/v1/lesions/{lesion_id}` fetches one lesion.
- `PATCH /api/v1/lesions/{lesion_id}` updates editable lesion fields.
- `DELETE /api/v1/lesions/{lesion_id}` archives or removes a lesion according to privacy rules.
- `GET /api/v1/lesions/{lesion_id}/timeline` returns chronological lesion history.
- `GET /api/v1/lesions/{lesion_id}/reports` returns reports attached to the lesion.

Rule: `DELETE` should usually mean archive or soft-delete plus storage cleanup, not careless hard deletion.

Create `app/schemas/lesion_schema.py` - canonical contract for all lesion endpoints:

```python
import uuid
from datetime import datetime

from pydantic import BaseModel


class LesionCreate(BaseModel):
    user_label: str | None = None
    body_region: str | None = None
    notes: str | None = None


class LesionResponse(BaseModel):
    id: uuid.UUID
    user_label: str | None
    body_region: str | None
    body_location_status: str
    first_seen_at: datetime
    created_at: datetime

    model_config = {"from_attributes": True}


class LesionListResponse(BaseModel):
    lesions: list[LesionResponse]
    total: int


class TimelineEvent(BaseModel):
    event_type: str    # "analysis" | "doctor_review" | "body_location" | "consent" | "lab_result"
    event_id: uuid.UUID
    summary: str
    occurred_at: datetime
    actor_role: str    # "patient" | "doctor" | "admin" | "system"


class LesionTimelineResponse(BaseModel):
    lesion_id: uuid.UUID
    events: list[TimelineEvent]
```

What this schema file does:

- `import uuid` provides UUID types for IDs.
- `from datetime import datetime` provides timestamp types.
- `BaseModel` is Pydantic's base class for request/response schemas.
- `LesionCreate` describes data needed to create a lesion.
- `LesionResponse` describes one lesion returned by the API.
- `model_config = {"from_attributes": True}` lets Pydantic build responses from ORM objects.
- `LesionListResponse` wraps a list plus total count for pagination or summaries.
- `TimelineEvent` describes one event in lesion history.
- `LesionTimelineResponse` groups timeline events for one lesion.

## Step 6: Body Location Endpoints

Implement:

```text
POST  /api/v1/lesions/{lesion_id}/body-location
GET   /api/v1/lesions/{lesion_id}/body-location/history
PATCH /api/v1/lesions/{lesion_id}/body-location/{location_id}
POST  /api/v1/lesions/{lesion_id}/body-location/{location_id}/approve
POST  /api/v1/lesions/{lesion_id}/body-location/{location_id}/correct
POST  /api/v1/lesions/{lesion_id}/body-location/{location_id}/reject
```

What these body-location endpoints do:

- `POST .../body-location` creates a location record for a lesion.
- `GET .../history` returns previous location records.
- `PATCH .../{location_id}` edits a location record when allowed.
- `approve`, `correct`, and `reject` endpoints model explicit doctor review actions.

Doctor actions:

```text
approve location
correct location
reject location as unclear
request better image or more information
```

What these actions mean:

- `approve location` confirms the submitted body location.
- `correct location` records a clinician correction.
- `reject location as unclear` marks the submitted location unusable.
- `request better image or more information` asks the patient for a clearer input before review continues.

## Step 7: Image And Analysis Endpoints

Implement:

```text
POST   /api/v1/lesions/{lesion_id}/images
GET    /api/v1/images/{image_id}
DELETE /api/v1/images/{image_id}
POST   /api/v1/images/{image_id}/analyze
GET    /api/v1/analysis/{analysis_id}
GET    /api/v1/lesions/{lesion_id}/analysis
POST   /api/v1/lesions/{lesion_id}/analysis/metadata-only
```

What these endpoints do:

- Image endpoints create, fetch, and delete image metadata/files.
- `POST /api/v1/images/{image_id}/analyze` runs model analysis on an uploaded image.
- Analysis endpoints fetch one analysis or list analyses for a lesion.
- `metadata-only` supports context/history records that do not rerun image inference.

Rule: real image prediction requires the image at inference time. Metadata-only mode can store context and past results, but it cannot recreate the original medical image.

## Step 8: Explanation, Consent, Review, Lab, Report, Dashboard

Implement:

```text
POST /api/v1/explain-llm/{analysis_id}
POST /api/v1/consents
GET  /api/v1/consents/current
GET  /api/v1/consents/history
POST /api/v1/consents/revoke
GET   /api/v1/reviews/pending
POST  /api/v1/reviews
GET   /api/v1/reviews/{review_id}
PATCH /api/v1/reviews/{review_id}
GET   /api/v1/reviews/{review_id}/lab-results
POST   /api/v1/lab-results
GET    /api/v1/lab-results
GET    /api/v1/lab-results/{lab_result_id}
PATCH  /api/v1/lab-results/{lab_result_id}
DELETE /api/v1/lab-results/{lab_result_id}
PATCH  /api/v1/lab-results/{lab_result_id}/doctor-review
POST /api/v1/reports
GET  /api/v1/reports/{report_id}
GET  /api/v1/dashboard/summary
GET  /api/v1/dashboard/activity
GET  /api/v1/notifications
PATCH /api/v1/notifications/{notification_id}/read
POST /api/v1/reminders
GET  /api/v1/reminders
PATCH /api/v1/reminders/{reminder_id}
DELETE /api/v1/reminders/{reminder_id}
GET  /api/v1/user/preferences
PATCH /api/v1/user/preferences
```

What these endpoint groups do:

- `explain-llm` creates a safe educational explanation for an analysis.
- `consents` creates, reads, and revokes consent records.
- `reviews` supports doctor review queues and review updates.
- `lab-results` supports lab-report upload, retrieval, edits, deletion, and doctor review.
- `reports` creates and retrieves case reports.
- `dashboard` powers user summary and activity views.
- `notifications` and `reminders` support follow-up workflows.
- `user/preferences` stores user-configurable settings.

Create `app/schemas/analysis_schema.py` - canonical contract for analysis and consent:

```python
import uuid
from datetime import datetime

from pydantic import BaseModel


class AnalysisRequest(BaseModel):
    lesion_id: uuid.UUID | None = None
    lesion_mode: str = "not_sure"   # "new" | "existing" | "not_sure"
    symptoms: list[str] = []
    user_note: str | None = None


class AnalysisResponse(BaseModel):
    analysis_id: uuid.UUID
    lesion_id: uuid.UUID
    label: str            # "benign" | "malignant"
    confidence: float     # calibrated (0-1)
    patient_label: str    # plain-language confidence label for patient UI
    cam_available: bool
    model_version: str
    created_at: datetime

    model_config = {"from_attributes": True}


class ConsentCreate(BaseModel):
    analysis_id: uuid.UUID
    storage_mode: str
    consent_for_ai_analysis: bool
    consent_for_secure_storage: bool
    consent_for_doctor_review: bool
    consent_for_research_training: bool
    consent_version: str
    idempotency_key: str   # client-generated UUID, prevents duplicate consent rows


class ConsentResponse(BaseModel):
    consent_id: uuid.UUID
    status: str
    storage_mode: str
    consent_version: str
    consented_at: datetime | None

    model_config = {"from_attributes": True}


class DashboardSummary(BaseModel):
    total_lesions: int
    lesions_needing_followup: int
    recent_analyses: int
    pending_doctor_reviews: int
    next_reminder_date: datetime | None
    lab_results_pending_review: int
    storage_mode: str
    account_status: str
```

What this schema file does:

- `AnalysisRequest` describes optional lesion context, symptoms, and notes sent before analysis.
- `lesion_id` can be absent when the user is not sure whether this is a new or existing lesion.
- `lesion_mode` captures that uncertainty explicitly.
- `AnalysisResponse` describes the model result returned to the frontend.
- `patient_label` stores patient-safe wording separate from raw numeric confidence.
- `cam_available` tells the frontend whether a heatmap is ready.
- `ConsentCreate` captures consent choices and an `idempotency_key` so retries do not create duplicate consent rows.
- `ConsentResponse` describes the consent state returned after creation or lookup.
- `DashboardSummary` describes high-level counts and status used by the customer dashboard.

Check:

```powershell
make test
```

What this command does: runs backend tests after adding or changing API contracts.

Expected result: endpoint tests cover success, permission failure, validation failure, and audit behavior.

## Concepts You Just Touched

- [Idempotency Keys (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys) - every state-changing endpoint accepts one
- [Optimistic Concurrency Control (3.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#32-optimistic-concurrency-control) - version columns on mutable entities
- [Consent State Machine (11.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#112-consent-state-machine)
- [Audit-Immutable Log (11.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#113-audit-immutable-log)
- [Role Separation (11.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#114-role-separation) - the API contract is the boundary
- [Output Validation (12.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#125-output-validation) - response models double as validators

## Questions You Should Be Able To Answer

1. Why is an immutable entity (audit_log) modelled differently from a mutable one (case)?
2. What does "API contract" mean and why is it more permanent than the code that implements it?
3. If you add a field to a Pydantic response model, is that a breaking change? When and when not?
4. How does role-based access control belong IN the API contract (not just at the route layer)?
5. Why is the OpenAPI spec generated from the code, not the other way around, in this project?

If you cannot answer Q1-Q3, re-read the entity-vs-contract section.
If you cannot answer Q4-Q5, read [System Design Patterns: 11.4 Role Separation](../reference/09_SYSTEM_DESIGN_PATTERNS.md#114-role-separation).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Breaking change shipped to frontend | renamed field on a response model | version your API and deprecate first |
| Mutable entity has no audit trail | events not emitted from the service layer | add the outbox writes |
| Audit log can be UPDATEd | no DB trigger preventing it | add `BEFORE UPDATE` trigger that raises |
| Same entity has two representations across routes | response model not shared | one canonical Pydantic model |
| Consent withdrawal makes prior predictions disappear from audit | audit not separated from operational data | audit must survive any deletion |

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
