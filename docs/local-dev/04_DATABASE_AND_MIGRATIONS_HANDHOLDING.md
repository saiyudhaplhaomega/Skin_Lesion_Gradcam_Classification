# Database And Migrations Handholding Guide

Use this after the backend health and ready endpoints pass.

## Goal

Add database state slowly so the project can track users, uploads, consent, review, approval, and training eligibility.

Start with local Postgres. Aurora DSQL is the planned cloud database target, but local Postgres is the first learning step.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

**What these three commands do:** the first `cd` moves to the workspace root. The second enters the backend repo. `.\.venv\Scripts\Activate.ps1` activates the backend virtual environment so all subsequent `python`, `pip`, `alembic`, and `pytest` commands use the backend dependencies.

Run every command in this guide from:

```text
Skin_Lesion_Classification_backend
```

**What this means:** database commands, Alembic migrations, and pytest all run from inside the backend repo. Running them from the workspace root fails because `app/` is not visible from there.

Every file path in this guide is relative to `Skin_Lesion_Classification_backend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...`, `alembic/...`, `migrations/...`, and `tests/...` path in this guide under `Skin_Lesion_Classification_backend/`.
- Run database and migration commands from `Skin_Lesion_Classification_backend/` unless a step explicitly says otherwise.

## Why Local Postgres First

Local Postgres lets you learn:

- connection strings
- tables
- migrations
- test database setup
- transaction behavior

Cloud databases add networking, IAM, cost, and availability problems. Learn the database model locally first, then validate the same migrations against Aurora DSQL during the staging database guide.

Keep the local schema conservative:

- use normal PostgreSQL-compatible tables, indexes, and constraints
- avoid extensions until the Aurora DSQL guide confirms they are supported
- avoid database-specific tricks that hide application behavior from tests
- keep migrations small enough to validate one at a time

Why: the app is planned for Aurora DSQL in cloud, so the local database should teach portable PostgreSQL-compatible habits instead of locking the backend to one local-only feature.

## Step 0: Start Local Postgres

Alembic must connect to a real database before it can autogenerate or apply migrations. Start local Postgres before running any `alembic revision --autogenerate`, `alembic upgrade head`, or `alembic current` command.

Run from this exact command location:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

First, confirm nothing is listening on the Postgres port:

```powershell
Test-NetConnection 127.0.0.1 -Port 5432
```

Expected before Postgres is started:

```text
TcpTestSucceeded : False
```

What this means: there is no local Postgres server available yet, so Alembic will fail with a `psycopg.OperationalError`.

Start Docker Desktop if it is not already running. Then create and start the local Postgres container:

```powershell
docker run --name skin-lesion-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=skin_lesion -p 5432:5432 -d postgres:16
```

What this command does:

- `--name skin-lesion-postgres` gives the container a stable name.
- `POSTGRES_USER=postgres` creates the username expected by `alembic.ini`.
- `POSTGRES_PASSWORD=postgres` creates the password expected by `alembic.ini`.
- `POSTGRES_DB=skin_lesion` creates the database expected by `alembic.ini`.
- `-p 5432:5432` makes the database reachable at `localhost:5432`.
- `postgres:16` uses a current local PostgreSQL image for development.

If the container already exists from a previous day, start it instead:

```powershell
docker start skin-lesion-postgres
```

Check that Postgres is reachable:

```powershell
Test-NetConnection 127.0.0.1 -Port 5432
```

Expected after Postgres is started:

```text
TcpTestSucceeded : True
```

Check the database connection through SQLAlchemy:

```powershell
python -c "from sqlalchemy import create_engine, text; engine = create_engine('postgresql+psycopg://postgres:postgres@localhost:5432/skin_lesion'); conn = engine.connect(); print(conn.execute(text('select 1')).scalar()); conn.close()"
```

Expected:

```text
1
```

Why: this proves the same Python dependency stack Alembic uses can reach the local `skin_lesion` database.

## Step 1: Add Database Dependencies

Edit this file:

```text
requirements.txt
```

**What this path is:** `requirements.txt` inside `Skin_Lesion_Classification_backend/` is the runtime dependency list. Adding packages here means they get installed in production containers. Only runtime dependencies go here - test and dev tools go in `requirements-dev.txt`.

Add these lines:

```text
SQLAlchemy==2.0.36
alembic==1.14.0
psycopg[binary]==3.2.3
pydantic-settings==2.7.1
```

What these dependencies do:

- `SQLAlchemy` maps Python classes to database tables.
- `alembic` creates and applies database migrations.
- `psycopg[binary]` is the PostgreSQL driver SQLAlchemy uses to connect to Postgres.
- `pydantic-settings` reads environment variables such as `DATABASE_URL` into typed settings.

Install through the dev dependency file because it already includes `requirements.txt`:

```powershell
pip install -r requirements-dev.txt
```

What this does: installs the updated runtime dependencies plus the development/test dependencies into the active backend `.venv`.

Check:

```powershell
python -c "import sqlalchemy, alembic, psycopg; print('database deps ok')"
```

What this checks: Python imports the three database packages. If any import fails, the dependency install did not complete correctly.

## Step 2: Create Settings

Create this file:

```text
app/core/config.py
```

**What this path is:** `app/core/` is the module for cross-cutting application concerns - settings, security utilities, and shared dependencies. Putting the settings class here keeps it away from route handlers and models, so any module can import it without circular dependency risk.

Paste:

```python
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/skin_lesion"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
```

What this code does:

- `BaseSettings` creates a settings object from defaults plus environment variables.
- `database_url` is the connection string SQLAlchemy will use for local Postgres.
- `SettingsConfigDict(env_file=".env", extra="ignore")` tells Pydantic to read a local `.env` file and ignore unrelated variables.
- `settings = Settings()` creates one shared settings object that other modules can import.

Why: every environment can change `DATABASE_URL` without changing code.

## Step 3: Create Database Base

Create these files:

```text
app/db/base.py
app/db/session.py
```

**What this path is:** `app/db/` is the module for database infrastructure - the declarative base, the engine, the session factory, and the `get_db` dependency. Separating this from `app/models/` keeps the ORM metadata setup away from individual table definitions.

`app/db/base.py`:

```python
from sqlalchemy.orm import DeclarativeBase


class Base(DeclarativeBase):
    pass
```

What this code does: `Base` is the parent class for every SQLAlchemy model. Alembic reads `Base.metadata` later to discover the tables that should exist.

`app/db/session.py`:

```python
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

engine = create_engine(settings.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

What this code does:

- `create_engine(settings.database_url, pool_pre_ping=True)` creates the database engine and checks pooled connections before reuse.
- `sessionmaker(...)` creates a factory for database sessions.
- `autoflush=False` prevents SQLAlchemy from writing pending changes earlier than expected.
- `autocommit=False` keeps transactions explicit.
- `get_db()` opens one session for a request or test and always closes it in `finally`.

## Step 4: Add The First Model

Create this file:

```text
app/models/training_case.py
```

**What this path is:** `app/models/` holds all SQLAlchemy ORM table definitions. Each model file maps to one or a small group of related database tables. `training_case.py` defines the first table - the one that tracks where an image is in the consent and review workflow.

Paste:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class TrainingCaseStatus(str, enum.Enum):
    uploaded = "uploaded"
    patient_consented = "patient_consented"
    doctor_validated = "doctor_validated"
    admin_approved = "admin_approved"
    queued_for_training = "queued_for_training"
    written_to_training_bucket = "written_to_training_bucket"
    rejected = "rejected"
    failed = "failed"


class TrainingCase(Base):
    __tablename__ = "training_cases"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    image_key: Mapped[str] = mapped_column(String(500), nullable=False)
    status: Mapped[TrainingCaseStatus] = mapped_column(
        Enum(TrainingCaseStatus),
        default=TrainingCaseStatus.uploaded,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    def __init__(self, **kwargs: object) -> None:
        super().__init__(**kwargs)
        if self.status is None:
            self.status = TrainingCaseStatus.uploaded
```

What this model does:

- `TrainingCaseStatus` defines the allowed workflow states for a case.
- `TrainingCase(Base)` declares a SQLAlchemy table model.
- `__tablename__ = "training_cases"` sets the database table name.
- `id` is a generated UUID primary key.
- `image_key` stores where the image lives, not the image bytes themselves.
- `status` stores the current workflow state and defaults to `uploaded`.
- `created_at` records when the case row was created.
- `__init__` makes the default status visible immediately in plain Python tests, before the row is inserted into Postgres.

Why: this is the state machine for consent and review.

## Step 4b: Add The Full Domain Model

The TrainingCase model tracks one workflow stage. Add the rest of the domain now so all migrations stay in sync.

Create these files:

```text
app/models/user.py
app/models/lesion.py
app/models/prediction.py
app/models/consent.py
app/models/doctor_review.py
```

**What these files are:** each file defines one SQLAlchemy model that maps to a database table. Together they form the core domain model: users (patients, doctors, admins), lesions (the skin area being tracked), predictions (AI model output), consents (patient agreement and storage preferences), and doctor reviews (clinical validation of AI predictions).

### `app/models/user.py`

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class UserRole(str, enum.Enum):
    patient = "patient"
    doctor = "doctor"
    admin = "admin"
    research_reviewer = "research_reviewer"


class AccountStatus(str, enum.Enum):
    pending_approval = "pending_approval"
    active = "active"
    suspended = "suspended"
    expired = "expired"


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    cognito_sub: Mapped[str] = mapped_column(String(200), unique=True, nullable=False)
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    role: Mapped[UserRole] = mapped_column(Enum(UserRole), nullable=False)
    status: Mapped[AccountStatus] = mapped_column(
        Enum(AccountStatus),
        default=AccountStatus.pending_approval,
        nullable=False,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    lesions: Mapped[list["Lesion"]] = relationship("Lesion", back_populates="patient")
    consents: Mapped[list["Consent"]] = relationship("Consent", back_populates="patient")
```

What this model does:

- `UserRole` separates patient, doctor, admin, and research-reviewer permissions.
- `AccountStatus` supports approval, suspension, and expiry instead of a fragile yes/no account flag.
- `cognito_sub` stores the future AWS Cognito identity ID.
- `email` is unique so one email cannot create duplicate users.
- `lesions` and `consents` define ORM relationships from a patient to their records.

### `app/models/lesion.py`

```python
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Lesion(Base):
    __tablename__ = "lesions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)

    # 2D body map coordinates - region name from the fixed region list
    body_region: Mapped[str | None] = mapped_column(String(100), nullable=True)
    # 3D body map coordinates - normalised x,y,z on the 3D mesh (stored as JSON string)
    body_map_3d_coords: Mapped[str | None] = mapped_column(Text, nullable=True)

    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    patient: Mapped["User"] = relationship("User", back_populates="lesions")
    predictions: Mapped[list["Prediction"]] = relationship("Prediction", back_populates="lesion")
```

What this model does:

- `patient_id` links each lesion to a user.
- `body_region` stores a simple 2D body-map region.
- `body_map_3d_coords` is reserved for later 3D coordinates.
- `notes` stores optional local notes.
- `predictions` links one lesion to one or more model predictions over time.

### `app/models/prediction.py`

```python
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Float, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class Prediction(Base):
    __tablename__ = "predictions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    lesion_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lesions.id"), nullable=False)

    # S3 key for the original image (never expose raw URL to patient)
    image_s3_key: Mapped[str] = mapped_column(String(500), nullable=False)
    # S3 key for the Grad-CAM PNG overlay
    cam_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)

    label: Mapped[str] = mapped_column(String(50), nullable=False)        # "benign" | "malignant"
    confidence: Mapped[float] = mapped_column(Float, nullable=False)       # calibrated (0-1)
    raw_logit: Mapped[float] = mapped_column(Float, nullable=False)        # uncalibrated logit
    model_version: Mapped[str] = mapped_column(String(50), nullable=False) # e.g. "model-v001"
    cam_method: Mapped[str] = mapped_column(String(50), default="gradcam++", nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    lesion: Mapped["Lesion"] = relationship("Lesion", back_populates="predictions")
    consent: Mapped["Consent | None"] = relationship("Consent", back_populates="prediction", uselist=False)
    doctor_review: Mapped["DoctorReview | None"] = relationship("DoctorReview", back_populates="prediction", uselist=False)
```

What this model does:

- `lesion_id` connects the prediction to the lesion being analyzed.
- `image_s3_key` and `cam_s3_key` store object keys, not public file URLs.
- `label`, `confidence`, and `raw_logit` separate patient-facing probability from raw model output.
- `model_version` records which model produced the prediction.
- `cam_method` records the explanation method used for the heatmap.
- `consent` and `doctor_review` are one-to-one relationships for safety and review workflow.

### `app/models/consent.py`

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ConsentStatus(str, enum.Enum):
    # Consent is a state machine, not a boolean.
    # See docs/reference/09_SYSTEM_DESIGN_PATTERNS.md 11.2 Consent State Machine
    pending = "pending"
    consented = "consented"
    withdrawn = "withdrawn"
    deletion_requested = "deletion_requested"
    deleted = "deleted"


class StorageMode(str, enum.Enum):
    full_clinical_history = "full_clinical_history"
    privacy_balanced = "privacy_balanced"
    maximum_privacy = "maximum_privacy"
    delete_after_analysis = "delete_after_analysis"
    metadata_only = "metadata_only"


class Consent(Base):
    __tablename__ = "consents"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    patient_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    prediction_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("predictions.id"), unique=True, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)

    status: Mapped[ConsentStatus] = mapped_column(
        Enum(ConsentStatus), default=ConsentStatus.pending, nullable=False
    )
    storage_mode: Mapped[StorageMode] = mapped_column(
        Enum(StorageMode), default=StorageMode.privacy_balanced, nullable=False
    )
    consent_version: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g. "v1.2"

    consented_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    withdrawn_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    patient: Mapped["User"] = relationship("User", back_populates="consents")
    prediction: Mapped["Prediction"] = relationship("Prediction", back_populates="consent")
```

What this model does:

- `ConsentStatus` models consent as a workflow, not a boolean.
- `StorageMode` records how much data the patient allows the system to keep.
- `idempotency_key` prevents duplicate consent records when a request is retried.
- `consent_version` records the exact legal/product text version the patient agreed to.
- `consented_at` and `withdrawn_at` preserve the consent timeline.

### `app/models/doctor_review.py`

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ReviewDecision(str, enum.Enum):
    pending = "pending"
    validated = "validated"       # doctor confirms AI label is correct
    corrected = "corrected"       # doctor provides a different label
    inconclusive = "inconclusive" # not enough information
    rejected = "rejected"         # image quality or consent issue


class DoctorReview(Base):
    __tablename__ = "doctor_reviews"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    prediction_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("predictions.id"), unique=True, nullable=False)
    doctor_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)

    decision: Mapped[ReviewDecision] = mapped_column(
        Enum(ReviewDecision), default=ReviewDecision.pending, nullable=False
    )
    corrected_label: Mapped[str | None] = mapped_column(String(50), nullable=True)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)

    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    prediction: Mapped["Prediction"] = relationship("Prediction", back_populates="doctor_review")
```

What this model does:

- `ReviewDecision` captures the doctor's review outcome.
- `prediction_id` links one review to one prediction.
- `doctor_id` records who reviewed it.
- `corrected_label` allows a clinician to override the AI label.
- `notes` stores review context.
- `reviewed_at` separates the time the row was created from the time the review was completed.

Import all models in `app/models/__init__.py` so Alembic can see them:

```python
from app.models.user import User
from app.models.lesion import Lesion
from app.models.prediction import Prediction
from app.models.consent import Consent
from app.models.doctor_review import DoctorReview
from app.models.training_case import TrainingCase

__all__ = ["User", "Lesion", "Prediction", "Consent", "DoctorReview", "TrainingCase"]
```

What this file does: imports every model module once so SQLAlchemy registers all tables on `Base.metadata`. Alembic needs that metadata to autogenerate migrations.

## Step 5: Initialize Alembic

From backend folder:

```powershell
alembic init alembic
```

What this does: creates the Alembic migration folder and configuration files under the backend repo.

Update `alembic/env.py` so it imports all models before Alembic reads the metadata.
Import the package, not individual models, so new files are picked up automatically:

```python
from app.db.base import Base
import app.models  # noqa: F401 - side-effect import registers all tables

target_metadata = Base.metadata
```

What this code does:

- `Base.metadata` is the full SQLAlchemy table registry.
- `import app.models` runs the model imports from `app/models/__init__.py`.
- `target_metadata = Base.metadata` tells Alembic what schema to compare against the database.

Update `alembic.ini`:

```ini
sqlalchemy.url = postgresql+psycopg://postgres:postgres@localhost:5432/skin_lesion
```

What this setting does: points Alembic at the same local Postgres database URL used by the app.

## Step 6: Create Migration

Make sure Step 0 is passing before running these commands. If `Test-NetConnection 127.0.0.1 -Port 5432` returns `TcpTestSucceeded : False`, stop here and start local Postgres first.

```powershell
alembic revision --autogenerate -m "create training cases"
alembic upgrade head
```

What this does:

- `alembic revision --autogenerate ...` compares SQLAlchemy models to the current database and creates a migration file.
- `alembic upgrade head` applies all pending migrations to the database.

Check:

```powershell
alembic current
```

What this checks: prints the migration revision currently applied to the database.

## Step 7: Test The Model

Create `tests/test_training_case_model.py`:

```python
from app.models.training_case import TrainingCase, TrainingCaseStatus


def test_training_case_defaults() -> None:
    case = TrainingCase(image_key="local/sample.jpg")

    assert case.image_key == "local/sample.jpg"
    assert case.status == TrainingCaseStatus.uploaded
```

What this test does: creates a `TrainingCase` in memory and verifies the model defaults before involving the database.

Run:

```powershell
pytest
```

**What this does:** runs the test suite including `test_training_case_defaults`. Since this test creates a model in memory without the database, it will pass even if Postgres is not running. It proves the model class and its defaults are correct before any database operations.

## Stop Point

You are ready for upload and mock prediction only after:

```powershell
pytest
alembic current
```

**What these verify:** `pytest` confirms the model code is correct. `alembic current` connects to the database and prints the latest applied migration revision - seeing a revision hash here confirms that Alembic can connect and that migrations were applied successfully.

Expected result:

```text
Tests pass and Alembic reports the current migration revision.
```

**What this means:** the test suite is green and the database schema matches the migration history. Both conditions must be true before moving to the upload guide.

## Concepts You Just Touched

- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service) - process is stateless because the DB holds the state
- [Session Cache vs Session Store (1.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#13-session-cache-versus-session-store) - DB is the store, not the cache
- [Optimistic Concurrency Control (3.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#32-optimistic-concurrency-control) - design space (add version columns now if you can)
- [Connection Pooling (4.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#44-connection-pooling)
- [Audit-Immutable Log (11.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#113-audit-immutable-log) - design space, build it from day 1
- [Consent State Machine (11.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#112-consent-state-machine) - design space

## Questions You Should Be Able To Answer

1. What is a migration, and why must every schema change go through one?
2. Why is the audit log a separate table that nothing can UPDATE or DELETE?
3. If two doctors validate the same case at the same time, what mechanism in your schema stops the second one from silently overwriting the first?
4. Why is consent a state machine, not a boolean column?
5. When you eventually move to Aurora DSQL, which of your local Postgres assumptions hold and which break?

If you cannot answer Q1-Q2, re-read the migration and schema sections above.
If you cannot answer Q3-Q5, read [System Design Patterns: Family 3 Consistency](../reference/09_SYSTEM_DESIGN_PATTERNS.md#family-3---consistency) and [Family 11 Healthcare-Specific](../reference/09_SYSTEM_DESIGN_PATTERNS.md#family-11---healthcare-specific-patterns).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| `psycopg.OperationalError` connecting to `127.0.0.1:5432` | local Postgres is not running, Docker Desktop is stopped, or the `skin_lesion` database was not created | run Step 0 and confirm `TcpTestSucceeded : True` |
| `alembic upgrade head` says "Target database is not up to date" | migrations missing from `versions/` or version table out of sync | `alembic current` then compare to `versions/` |
| Migration runs locally, fails in staging | DB has different baseline | always `alembic upgrade head` from empty in CI |
| Foreign key violation on insert | parent row missing or seed order wrong | check seed script ordering |
| `psycopg2.errors.UndefinedTable` at runtime | migration not applied | run `alembic upgrade head` before starting the app |
| Test DB and dev DB drift | tests use a different schema source | use the same migrations against an isolated test DB |

## Local Docker Pause / Resume

This guide starts a local Postgres Docker container. Stop it before stepping away so Postgres is not left running in the background.

Run from any PowerShell terminal:

```powershell
docker stop skin-lesion-postgres
```

**What this does:** stops the local Postgres container but keeps the database data and container configuration, so you can continue later without recreating the database.

Check:

```powershell
docker ps --filter "name=skin-lesion-postgres"
Test-NetConnection 127.0.0.1 -Port 5432
```

Expected:

```text
docker ps shows no running skin-lesion-postgres container
TcpTestSucceeded : False
```

Before starting the next database step, resume Postgres:

```powershell
docker start skin-lesion-postgres
Test-NetConnection 127.0.0.1 -Port 5432
```

Expected:

```text
TcpTestSucceeded : True
```

Only delete the container when you intentionally want to erase the local database and start over:

```powershell
docker stop skin-lesion-postgres
docker rm skin-lesion-postgres
```

**What this deletes:** removes the local Postgres container. Because this guide uses the container's internal storage, deleting the container also deletes the local `skin_lesion` database data.

## Cost Pause / Resume

This guide is local-only and does not create cloud resources.

Do not run cloud pause or shutdown commands for this guide unless a later staging or production guide explicitly tells you to use cloud resources.
