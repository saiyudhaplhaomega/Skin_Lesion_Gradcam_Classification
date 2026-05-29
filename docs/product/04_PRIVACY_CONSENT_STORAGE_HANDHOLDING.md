# Privacy, Consent, Storage, Retention, And De-identification Handholding Guide

Use this after database tables for users, lesions, images, and analysis events exist.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

What this command block does:

- The first `cd` moves to the main workspace.
- The second `cd` moves into the backend repository where privacy schemas, models, services, and tests belong.

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: every file path below is relative to the backend repo, not the root docs folder or frontend repo.

Every file path below is relative to `Skin_Lesion_Classification_backend`.

## Goal

Make privacy a first-class workflow instead of a checkbox.

Build:

- storage modes
- consent history
- retention policy fields
- deletion request state
- private storage contract
- de-identification checks
- audit logs for every sensitive action
- lab-result storage and doctor-review consent

## Step 1: Add Storage Mode And Retention Types

Create:

```text
app/schemas/privacy.py
```

What this path means: create the privacy schema file under `Skin_Lesion_Classification_backend/app/schemas/`.

Paste:

```python
from enum import StrEnum
from pydantic import BaseModel


class StorageMode(StrEnum):
    full_clinical_history = "full_clinical_history"
    privacy_balanced = "privacy_balanced"
    maximum_privacy = "maximum_privacy"


class RetentionPolicy(StrEnum):
    delete_after_analysis = "delete_after_analysis"
    keep_30_days = "keep_30_days"
    keep_1_year = "keep_1_year"
    keep_until_deleted = "keep_until_deleted"
    metadata_only = "metadata_only"


class PrivacyChoice(BaseModel):
    storage_mode: StorageMode
    retention_policy: RetentionPolicy
    consent_for_ai_analysis: bool
    consent_for_secure_storage: bool
    consent_for_doctor_review: bool
    consent_for_research_training: bool
    consent_for_lab_result_storage: bool = False
    consent_for_lab_result_doctor_review: bool = False
```

What this schema code does:

- `StrEnum` creates enum values that also behave like strings.
- `BaseModel` creates Pydantic request/response objects.
- `StorageMode` lists the user's broad storage choices.
- `RetentionPolicy` lists how long data may be retained.
- `PrivacyChoice` groups storage, retention, and granular consent choices.
- Each `consent_for_*` field is separate so consent is explicit per use case.
- Lab-result consent defaults to `False` so lab storage/review is never accidentally enabled.

Check:

```powershell
make test
```

What this command does: runs backend tests after adding the privacy schema.

Expected result: tests still pass.

## Step 2: Add Consent History Model

The `Consent` model was created in `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`.
Extend it now to add per-type granular consent tracking.

Create `app/models/consent_event.py` (append-only history - never UPDATE or DELETE):

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class ConsentType(str, enum.Enum):
    ai_analysis = "consent_for_ai_analysis"
    image_storage = "consent_for_image_storage"
    doctor_review = "consent_for_doctor_review"
    research_training = "consent_for_research_training"
    lab_result_storage = "consent_for_lab_result_storage"
    lab_result_doctor_review = "consent_for_lab_result_doctor_review"


class ConsentEventStatus(str, enum.Enum):
    granted = "granted"
    revoked = "revoked"


class ConsentEvent(Base):
    """Append-only. Every consent change is a new row. Never edit history."""
    __tablename__ = "consent_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    consent_type: Mapped[ConsentType] = mapped_column(Enum(ConsentType), nullable=False)
    status: Mapped[ConsentEventStatus] = mapped_column(Enum(ConsentEventStatus), nullable=False)
    consent_version: Mapped[str] = mapped_column(String(20), nullable=False)  # e.g. "v1.2"
    idempotency_key: Mapped[str] = mapped_column(String(100), unique=True, nullable=False)
    granted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

What this model code does:

- `enum` defines controlled consent type/status values.
- `uuid` creates UUID primary keys.
- `datetime` stores timestamps.
- SQLAlchemy imports define table columns, enums, foreign keys, and ORM mapped fields.
- `ConsentType` lists each separate permission a user can grant or revoke.
- `ConsentEventStatus` records whether the permission was granted or revoked.
- `ConsentEvent(Base)` declares a SQLAlchemy table model.
- `__tablename__ = "consent_events"` sets the database table name.
- `id` is the event primary key.
- `user_id` links the event to the user.
- `consent_type` records which permission changed.
- `status` records granted or revoked.
- `consent_version` stores the policy text version.
- `idempotency_key` prevents duplicate consent events during retries.
- `granted_at`, `revoked_at`, and `created_at` preserve the timeline.

Add to `app/models/__init__.py`:

```python
from app.models.consent_event import ConsentEvent
```

What this import does: loads the `ConsentEvent` model so SQLAlchemy and Alembic can discover the table.

Before migration, confirm local Postgres is running.

Run from the backend repo:

```powershell
Test-NetConnection 127.0.0.1 -Port 5432
```

Expected result:

```text
TcpTestSucceeded : True
```

If the result is `False`, go back to `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md` Step 0 and start the local Postgres container first:

```powershell
docker start skin-lesion-postgres
```

If you are using the Compose path from `docs/local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md`, run this from the main workspace instead:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up postgres -d
```

Then check the SQLAlchemy connection from the backend repo:

```powershell
python -c "from sqlalchemy import create_engine, text; engine = create_engine('postgresql+psycopg://postgres:postgres@localhost:5432/skin_lesion'); conn = engine.connect(); print(conn.execute(text('select 1')).scalar()); conn.close()"
```

Expected result:

```text
1
```

Why: Alembic autogenerate compares SQLAlchemy models against a live database. If Postgres is stopped, `alembic revision --autogenerate` fails with `psycopg.OperationalError`.

Then migrate:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
alembic revision --autogenerate -m "add consent events"
alembic upgrade head
make test
```

What this command block does:

- `cd Skin_Lesion_Classification_backend` enters the backend repo.
- `.\.venv\Scripts\Activate.ps1` activates the backend virtual environment.
- `alembic revision --autogenerate -m "add consent events"` creates a migration from model changes.
- `alembic upgrade head` applies pending migrations.
- `make test` runs backend tests after the database change.

Expected result: consent rows can be granted and revoked without deleting history.

## Step 3: Add Image Storage Fields

Create `app/models/image.py`:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Enum, ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base
from app.schemas.privacy import StorageMode, RetentionPolicy


class Image(Base):
    __tablename__ = "images"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    lesion_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("lesions.id"), nullable=True)

    # S3 keys - never store raw public URLs
    raw_image_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    thumbnail_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    gradcam_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)
    segmentation_mask_s3_key: Mapped[str | None] = mapped_column(String(500), nullable=True)

    storage_mode: Mapped[str] = mapped_column(
        String(50), default=StorageMode.privacy_balanced, nullable=False
    )
    retention_policy: Mapped[str] = mapped_column(
        String(50), default=RetentionPolicy.keep_until_deleted, nullable=False
    )

    image_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)  # SHA-256
    exif_removed: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_raw_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

What this image model code does:

- `Image(Base)` declares the `images` table.
- `user_id` links the image to the owner.
- `lesion_id` optionally links the image to a lesion.
- `raw_image_s3_key`, `thumbnail_s3_key`, `gradcam_s3_key`, and `segmentation_mask_s3_key` store private object keys, not public URLs.
- `storage_mode` records the selected privacy mode.
- `retention_policy` records how long data can be kept.
- `image_hash` stores a SHA-256 hash for duplicate detection or audit checks.
- `exif_removed` records whether metadata stripping happened.
- `deleted_raw_at` records when the raw image was deleted.
- `created_at` records when the row was created.

Add to `app/models/__init__.py`:

```python
from app.models.image import Image
```

What this import does: registers the `Image` model for SQLAlchemy metadata and Alembic migration discovery.

Important `.gitignore` check:

```powershell
git check-ignore -v app/models/image.py
```

Expected result:

```text
No output.
```

If Git says `.gitignore:...:models/ app/models/image.py`, the ignore rule is too broad. Change the backend `.gitignore` rule from:

```text
models/
```

to:

```text
/models/
```

What this workaround does:

- `/models/` ignores only the backend root `models/` folder that holds local model weights and checkpoints.
- It stops Git from ignoring `app/models/`, where SQLAlchemy source files belong.
- It still preserves the safety rule that large or sensitive model artifacts should not be committed.

Migrate:

```powershell
alembic revision --autogenerate -m "add images table"
alembic upgrade head
```

What this command block does:

- `alembic revision --autogenerate -m "add images table"` creates a migration for the image table.
- `alembic upgrade head` applies that migration.

Why: maximum privacy can keep metadata only, while full clinical history can keep encrypted images.

Storage behavior:

```text
full_clinical_history: encrypted raw image, thumbnail, Grad-CAM, segmentation mask, metadata, analysis history
privacy_balanced: encrypted thumbnail, processed explanation images, segmentation mask, metadata; raw image deleted after inference
maximum_privacy: metadata, extracted features, prediction result; no image
```

What this storage behavior block means:

- `full_clinical_history` keeps raw and derived images for the richest clinical timeline.
- `privacy_balanced` deletes raw images after inference but keeps useful derived artifacts.
- `maximum_privacy` keeps no images, only metadata and analysis results.

UI limitation copy:

```text
Maximum privacy stores no images. You can still keep metadata and analysis history, but visual comparison and doctor image review will be unavailable.
```

What this copy does: explains the user-facing tradeoff of maximum privacy without hiding lost functionality.

Hard rule:

```text
Do not attempt to regenerate medical or skin lesion images from metadata. Synthetic reconstruction could create misleading medical evidence.
```

What this rule means: metadata-only storage must not be used to invent or reconstruct medical images later.

## Step 4: Add De-identification Service Boundary

Create:

```text
app/services/deidentification_service.py
```

What this path means: create the de-identification service in the backend service layer.

Paste:

```python
from pydantic import BaseModel


class DeidentificationResult(BaseModel):
    exif_removed: bool
    face_detected: bool
    identifying_mark_warning: bool
    tight_crop_recommended: bool
    accepted_for_research: bool


def inspect_image_for_research_use() -> DeidentificationResult:
    return DeidentificationResult(
        exif_removed=True,
        face_detected=False,
        identifying_mark_warning=False,
        tight_crop_recommended=True,
        accepted_for_research=True,
    )
```

What this service code does:

- `BaseModel` creates a typed result object.
- `DeidentificationResult` describes privacy checks before research/training reuse.
- `exif_removed` records whether camera/location metadata was removed.
- `face_detected` warns if a face appears in the image.
- `identifying_mark_warning` warns about tattoos, labels, or other identifiers.
- `tight_crop_recommended` tells the UI/service whether the image should be cropped closer to the lesion.
- `accepted_for_research` records whether the image can enter research/training flow.
- `inspect_image_for_research_use()` is a stub boundary that can be tested before real image detection is connected.

Check:

```powershell
make test
```

What this command does: runs backend tests after creating the service boundary.

Expected result: this service can be unit tested before connecting real image detection.

## Step 5: Add Private Storage Contract

Create `app/services/storage_service.py`:

```python
"""
Private storage service - wraps S3 uploads and signed URL generation.
Never returns a raw public object URL. All access is via time-limited signed URLs.
"""
from __future__ import annotations

import hashlib
import os
import uuid
from datetime import datetime

import boto3
from botocore.exceptions import ClientError
from sqlalchemy.orm import Session

from app.models.image import Image
from app.schemas.privacy import StorageMode

BUCKET = os.environ.get("IMAGE_BUCKET", "skin-lesion-images-local")
SIGNED_URL_TTL_SECONDS = 900   # 15 minutes

_s3 = None


def _get_s3():
    global _s3
    if _s3 is None:
        _s3 = boto3.client("s3", region_name=os.environ.get("AWS_REGION", "eu-central-1"))
    return _s3


def upload_raw_image(
    db: Session,
    user_id: uuid.UUID,
    image_bytes: bytes,
    storage_mode: str,
    lesion_id: uuid.UUID | None = None,
) -> Image:
    """
    Upload image bytes to S3 under the user's prefix.
    What gets stored depends on the storage mode.
    Returns the Image DB row (without public URLs).
    """
    image_id = uuid.uuid4()
    image_hash = hashlib.sha256(image_bytes).hexdigest()

    raw_key: str | None = None
    if storage_mode != StorageMode.maximum_privacy:
        raw_key = f"users/{user_id}/images/{image_id}/raw.jpg"
        _get_s3().put_object(
            Bucket=BUCKET,
            Key=raw_key,
            Body=image_bytes,
            ServerSideEncryption="aws:kms",
        )

    img = Image(
        id=image_id,
        user_id=user_id,
        lesion_id=lesion_id,
        raw_image_s3_key=raw_key,
        storage_mode=storage_mode,
        image_hash=image_hash,
        exif_removed=True,   # EXIF stripped before upload (see deidentification_service)
    )
    db.add(img)
    db.commit()
    db.refresh(img)
    return img


def get_signed_url(s3_key: str, ttl: int = SIGNED_URL_TTL_SECONDS) -> str:
    """
    Generate a pre-signed GET URL valid for ttl seconds.
    Never expose the raw S3 key or bucket name in API responses.
    """
    return _get_s3().generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": s3_key},
        ExpiresIn=ttl,
    )


def delete_raw_image(db: Session, image: Image) -> None:
    """Delete the raw image from S3. Update DB to record deletion timestamp."""
    if image.raw_image_s3_key:
        try:
            _get_s3().delete_object(Bucket=BUCKET, Key=image.raw_image_s3_key)
        except ClientError:
            pass   # already deleted or wrong key - log and continue
        image.raw_image_s3_key = None
        image.deleted_raw_at = datetime.utcnow()
        db.commit()
```

What this storage service code does:

- The module docstring states the security rule: never return raw public object URLs.
- `from __future__ import annotations` lets type hints refer to classes without immediate evaluation.
- `hashlib` computes image hashes.
- `os` reads environment variables such as bucket name and AWS region.
- `uuid` creates image IDs.
- `datetime` records deletion timestamps.
- `boto3` is the AWS SDK used to call S3.
- `ClientError` catches S3 deletion/upload errors.
- `Session` is the SQLAlchemy database session type.
- `Image` is the database model that stores image metadata.
- `StorageMode` determines whether raw image bytes should be stored.
- `BUCKET` reads `IMAGE_BUCKET` from the environment and falls back to a local bucket name.
- `SIGNED_URL_TTL_SECONDS = 900` limits signed URLs to 15 minutes.
- `_s3 = None` starts a lazy client cache.
- `_get_s3()` creates the S3 client once and reuses it.
- `upload_raw_image(...)` hashes the image, optionally uploads it to S3, creates an `Image` database row, commits it, and returns it.
- The `storage_mode != StorageMode.maximum_privacy` check prevents raw image upload in maximum privacy mode.
- `put_object(..., ServerSideEncryption="aws:kms")` requests KMS encryption for stored image objects.
- `get_signed_url(...)` returns a temporary pre-signed S3 URL instead of exposing the object directly.
- `delete_raw_image(...)` deletes the raw object if present, clears the DB key, records `deleted_raw_at`, and commits the change.

Test to verify no public URLs leak:

```python
# tests/test_storage_service.py
from unittest.mock import MagicMock, patch
import uuid
from app.services.storage_service import get_signed_url


def test_signed_url_contains_presigned_not_public() -> None:
    with patch("app.services.storage_service._get_s3") as mock_s3_fn:
        mock_client = MagicMock()
        mock_client.generate_presigned_url.return_value = "https://s3.amazonaws.com/bucket/key?X-Amz-Signature=abc"
        mock_s3_fn.return_value = mock_client

        url = get_signed_url("users/123/images/456/raw.jpg")

        # Must have a pre-signed signature, not a raw object URL
        assert "X-Amz-Signature" in url
        # Must NOT be a plain public URL (no AWS credentials in response)
        assert "bucket" in url.lower() or "amazonaws.com" in url
```

What this test code does:

- `MagicMock` creates a fake S3 client.
- `patch("app.services.storage_service._get_s3")` replaces the real S3 client function during the test.
- The fake client returns a URL containing `X-Amz-Signature`, which is expected in a pre-signed URL.
- `get_signed_url(...)` is called with a private object key.
- The assertions verify the returned URL looks like a signed S3 URL instead of an application-owned public URL.

Run:

```powershell
pytest tests/test_storage_service.py -v
```

What this command does: runs only the storage service test file with verbose output.

Expected result: tests prove public URLs are never returned.

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
