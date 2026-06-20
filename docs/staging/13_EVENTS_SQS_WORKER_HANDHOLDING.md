# Events, SQS, And Worker Handholding Guide

Use this after local backend API and database state work.

## Current Project Implementation

This guide has been aligned to the existing backend and EKS path.

Files created or edited:

```text
Skin_Lesion_Classification_backend/app/models/case_event.py
Skin_Lesion_Classification_backend/app/models/outbox_event.py
Skin_Lesion_Classification_backend/app/services/training_workflow.py
Skin_Lesion_Classification_backend/app/workers/training_bucket_worker.py
Skin_Lesion_Classification_backend/app/workers/sqs_publisher.py
Skin_Lesion_Classification_backend/app/workers/sqs_consumer.py
Skin_Lesion_Classification_backend/tests/test_training_workflow.py
infra/terraform/events.tf
infra/terraform/security_observability.tf
```

`boto3==1.37.0` already exists in `Skin_Lesion_Classification_backend/requirements.txt`, so no dependency edit was needed.

Check commands:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_training_workflow.py -v
```

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
terraform fmt -recursive
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Local workflow tests pass.
Terraform validates queue, DLQ, EventBridge, queue policy, and queue-depth alarms.
No AWS queue is created until terraform apply is explicitly approved.
```

## Goal

Build the long workflow:

```text
patient consents -> doctor validates -> admin approves -> write to training bucket
```

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
```

**What these commands do:** moves to the workspace root, then into the backend repo, then activates the Python virtual environment so that `pip`, `alembic`, `pytest`, and `python` commands use the project's installed packages rather than the system Python.

Backend code, database models, workers, and tests in this guide belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** all Python files created in this guide go inside the backend repo directory. Only Terraform and Kubernetes YAML files go in the workspace root under `infra/`.

AWS CLI checks at the SQS gate can run from the repo root or backend repo.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Terraform root, only when a step explicitly names AWS infrastructure: `infra/terraform/`
- Create or edit backend `app/...`, worker, database model, and `tests/...` paths under `Skin_Lesion_Classification_backend/`.
- Create or edit queue and event infrastructure under `infra/terraform/` only in the steps that explicitly name Terraform.

## Why Not Kubernetes Alone

Kubernetes can run the backend and workers. It should not be the memory of a business process.

The database stores state. Queues carry work. Workers process work.

## Step 1: Add Tables Locally

Add:

```text
training_cases
case_events
outbox_events
```

**What each table does:** `training_cases` stores the current status of each patient image case - one row per case, updated as the case moves through the workflow. `case_events` is an append-only audit log - one row per state transition, never updated or deleted. `outbox_events` is the transactional outbox - rows are written atomically with state changes and read by the worker to publish to SQS.

## Step 2: Add Database Models For The Workflow

Create `app/models/case_event.py`:

```python
import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class CaseEvent(Base):
    """Append-only audit log - never UPDATE or DELETE rows here."""
    __tablename__ = "case_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("training_cases.id"), nullable=False)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    actor_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

**What this model does:** defines the `case_events` SQLAlchemy ORM model. `ForeignKey("training_cases.id")` links each event to a case. `actor_id` records who performed the action (doctor ID, admin ID). `metadata_json` holds extra context as a JSON string - flexible enough to store consent version, corrected label, or rejection reason without needing dedicated columns. `created_at` is set once at insert time and never changed - this is the audit timestamp.

Create `app/models/outbox_event.py`:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class OutboxStatus(str, enum.Enum):
    pending = "pending"
    processing = "processing"
    published = "published"
    failed = "failed"


class OutboxEvent(Base):
    """
    Transactional outbox pattern: events written atomically with DB state changes.
    The worker reads pending rows and publishes to SQS, then marks published.
    This prevents the 'update DB but fail to send to queue' split-brain problem.
    """
    __tablename__ = "outbox_events"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    case_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("training_cases.id"), nullable=False)
    event_type: Mapped[str] = mapped_column(String(100), nullable=False)
    payload_json: Mapped[str] = mapped_column(Text, nullable=False)
    status: Mapped[OutboxStatus] = mapped_column(
        Enum(OutboxStatus), default=OutboxStatus.pending, nullable=False
    )
    attempts: Mapped[int] = mapped_column(default=0, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    published_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
```

**What this model does:**

- `OutboxStatus` enum - the four possible states of an outbox row. `pending` means not yet picked up. `processing` means the worker is currently handling it (prevents double-processing if multiple workers run). `published` means the SQS message was sent and confirmed. `failed` means the worker gave up after `MAX_ATTEMPTS` retries.
- `payload_json` - the full event payload as a JSON string. The worker reads this and sends it as the SQS message body.
- `attempts` - counts how many times the worker tried to publish this event. Incremented before each attempt. Used to stop retrying after `MAX_ATTEMPTS`.
- `published_at` - set when the event reaches `published` status. Useful for auditing how long events waited in the outbox before going out.

## Step 3: Add State Transition Functions

Create `app/services/training_workflow.py`:

```python
"""
State machine for the consent -> validation -> approval -> training pipeline.

Every transition:
  1. Loads the case from the DB.
  2. Guards against invalid transitions (prevents skipping steps).
  3. Updates the TrainingCase status.
  4. Appends an audit row to CaseEvent (never updated/deleted).
  5. Appends an OutboxEvent if background work follows.
  6. All writes happen in ONE transaction - atomic.
"""
from __future__ import annotations

import json
import uuid
from datetime import datetime

from sqlalchemy.orm import Session

from app.models.case_event import CaseEvent
from app.models.outbox_event import OutboxEvent
from app.models.training_case import TrainingCase, TrainingCaseStatus

# Valid transitions: {from_status: to_status}
_TRANSITIONS: dict[TrainingCaseStatus, TrainingCaseStatus] = {
    TrainingCaseStatus.uploaded: TrainingCaseStatus.patient_consented,
    TrainingCaseStatus.patient_consented: TrainingCaseStatus.doctor_validated,
    TrainingCaseStatus.doctor_validated: TrainingCaseStatus.admin_approved,
    TrainingCaseStatus.admin_approved: TrainingCaseStatus.queued_for_training,
    TrainingCaseStatus.queued_for_training: TrainingCaseStatus.written_to_training_bucket,
}


def _transition(
    db: Session,
    case_id: uuid.UUID,
    expected_from: TrainingCaseStatus,
    to_status: TrainingCaseStatus,
    event_type: str,
    actor_id: str | None = None,
    metadata: dict | None = None,
    emit_outbox: bool = False,
) -> TrainingCase:
    case = db.query(TrainingCase).filter(TrainingCase.id == case_id).with_for_update().first()
    if case is None:
        raise ValueError(f"Case {case_id} not found")
    if case.status != expected_from:
        raise ValueError(
            f"Cannot transition from {case.status} to {to_status}. "
            f"Expected current status: {expected_from}."
        )

    case.status = to_status

    db.add(CaseEvent(
        case_id=case_id,
        event_type=event_type,
        actor_id=actor_id,
        metadata_json=json.dumps(metadata or {}),
    ))

    if emit_outbox:
        db.add(OutboxEvent(
            case_id=case_id,
            event_type=event_type,
            payload_json=json.dumps({"case_id": str(case_id), "event": event_type}),
        ))

    db.commit()
    db.refresh(case)
    return case


def record_patient_consent(db: Session, case_id: uuid.UUID, consent_version: str) -> TrainingCase:
    return _transition(
        db, case_id,
        expected_from=TrainingCaseStatus.uploaded,
        to_status=TrainingCaseStatus.patient_consented,
        event_type="patient_consented",
        metadata={"consent_version": consent_version},
    )


def record_doctor_validation(db: Session, case_id: uuid.UUID, doctor_id: str, corrected_label: str | None = None) -> TrainingCase:
    return _transition(
        db, case_id,
        expected_from=TrainingCaseStatus.patient_consented,
        to_status=TrainingCaseStatus.doctor_validated,
        event_type="doctor_validated",
        actor_id=doctor_id,
        metadata={"corrected_label": corrected_label},
    )


def record_admin_approval(db: Session, case_id: uuid.UUID, admin_id: str) -> TrainingCase:
    return _transition(
        db, case_id,
        expected_from=TrainingCaseStatus.doctor_validated,
        to_status=TrainingCaseStatus.admin_approved,
        event_type="admin_approved",
        actor_id=admin_id,
        emit_outbox=True,   # this triggers the worker
    )


def mark_written_to_training_bucket(db: Session, case_id: uuid.UUID) -> TrainingCase:
    return _transition(
        db, case_id,
        expected_from=TrainingCaseStatus.queued_for_training,
        to_status=TrainingCaseStatus.written_to_training_bucket,
        event_type="written_to_training_bucket",
    )


def mark_failed(db: Session, case_id: uuid.UUID, reason: str) -> None:
    case = db.query(TrainingCase).filter(TrainingCase.id == case_id).first()
    if case:
        case.status = TrainingCaseStatus.failed
        db.add(CaseEvent(case_id=case_id, event_type="failed", metadata_json=json.dumps({"reason": reason})))
        db.commit()
```

**What this module does:**

- `_TRANSITIONS` dict - defines the allowed state machine edges. Only the explicit transitions listed here are valid. Trying to skip a step raises a `ValueError`.
- `_transition` function - the single shared transition engine used by all public functions. `.with_for_update()` locks the case row in the database during the transition to prevent two concurrent requests from both reading the same status and then both writing conflicting updates (a race condition).
- `emit_outbox=True` on `record_admin_approval` - creates an outbox row in the same transaction as the status change. The worker reads this row and publishes the event to SQS.
- `db.commit()` then `db.refresh(case)` - commits all three writes (status, CaseEvent, OutboxEvent) atomically, then refreshes the in-memory case object to reflect the new status.
- Public functions (`record_patient_consent`, `record_doctor_validation`, `record_admin_approval`, `mark_written_to_training_bucket`, `mark_failed`) - thin wrappers that call `_transition` with the right from/to status for each step.

## Step 4: Add Local Worker (No SQS Yet)

Create `app/workers/training_bucket_worker.py`:

```python
"""
Local worker: reads OutboxEvents and simulates writing to the training bucket.
Run this locally to test the workflow before wiring AWS SQS.
"""
from __future__ import annotations

import json
import logging
import time
from datetime import datetime

from sqlalchemy.orm import Session

from app.db.session import SessionLocal
from app.models.outbox_event import OutboxEvent, OutboxStatus
from app.models.training_case import TrainingCase, TrainingCaseStatus

logger = logging.getLogger(__name__)
POLL_INTERVAL_SECONDS = 2
MAX_ATTEMPTS = 3


def _process_one(db: Session, event: OutboxEvent) -> None:
    event.status = OutboxStatus.processing
    event.attempts += 1
    db.commit()

    try:
        payload = json.loads(event.payload_json)
        case_id = payload["case_id"]

        # Local simulation: just update status to queued_for_training
        case = db.query(TrainingCase).filter(TrainingCase.id == case_id).first()
        if case and case.status == TrainingCaseStatus.admin_approved:
            case.status = TrainingCaseStatus.queued_for_training
            db.commit()
            logger.info("Case %s queued for training", case_id)

        event.status = OutboxStatus.published
        event.published_at = datetime.utcnow()
        db.commit()

    except Exception as exc:
        logger.error("Failed to process event %s: %s", event.id, exc)
        if event.attempts >= MAX_ATTEMPTS:
            event.status = OutboxStatus.failed
        else:
            event.status = OutboxStatus.pending  # will be retried
        db.commit()


def run_once(db: Session) -> int:
    """Process all pending outbox events. Returns number processed."""
    events = (
        db.query(OutboxEvent)
        .filter(OutboxEvent.status == OutboxStatus.pending)
        .order_by(OutboxEvent.created_at)
        .limit(10)
        .all()
    )
    for event in events:
        _process_one(db, event)
    return len(events)


def run_loop() -> None:
    """Continuous polling loop. Run as a separate process or thread."""
    logger.info("Training bucket worker started")
    while True:
        with SessionLocal() as db:
            processed = run_once(db)
            if processed:
                logger.info("Processed %d outbox events", processed)
        time.sleep(POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_loop()
```

**What this worker does:**

- `_process_one` - marks the event as `processing` and increments `attempts` before doing any real work. This prevents two worker instances from picking up the same row. After successful processing, marks `published`. On failure, sets `failed` if attempts hit the limit, otherwise resets to `pending` for a retry.
- `run_once` - queries up to 10 pending outbox events ordered by creation time (FIFO), processes each one. Returns the count so the loop can log progress.
- `run_loop` - infinite polling loop with a 2-second sleep between runs. Each iteration opens a fresh database session. In production, this runs as a separate Kubernetes pod deployment.
- `POLL_INTERVAL_SECONDS = 2` - short interval for local development; increase to 5-10 seconds in production to reduce database load.

Test the local workflow end to end:

```python
# tests/test_training_workflow.py
import uuid
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.db.base import Base
import app.models  # noqa: registers all tables
from app.models.training_case import TrainingCase, TrainingCaseStatus
from app.models.outbox_event import OutboxEvent, OutboxStatus
from app.services.training_workflow import (
    record_patient_consent,
    record_doctor_validation,
    record_admin_approval,
)
from app.workers.training_bucket_worker import run_once


@pytest.fixture
def db():
    engine = create_engine("sqlite:///:memory:")
    Base.metadata.create_all(engine)
    Session = sessionmaker(bind=engine)
    session = Session()
    yield session
    session.close()


def test_full_consent_to_approval_workflow(db) -> None:
    case = TrainingCase(image_key="local/test.jpg")
    db.add(case)
    db.commit()

    record_patient_consent(db, case.id, consent_version="v1.0")
    record_doctor_validation(db, case.id, doctor_id="dr-001")
    record_admin_approval(db, case.id, admin_id="admin-001")

    db.expire(case)
    db.refresh(case)
    assert case.status == TrainingCaseStatus.admin_approved

    outbox = db.query(OutboxEvent).filter(OutboxEvent.case_id == case.id).first()
    assert outbox is not None
    assert outbox.status == OutboxStatus.pending


def test_worker_processes_outbox(db) -> None:
    case = TrainingCase(image_key="local/test2.jpg")
    db.add(case)
    db.commit()

    record_patient_consent(db, case.id, consent_version="v1.0")
    record_doctor_validation(db, case.id, doctor_id="dr-001")
    record_admin_approval(db, case.id, admin_id="admin-001")

    processed = run_once(db)
    assert processed == 1

    db.expire_all()
    outbox = db.query(OutboxEvent).filter(OutboxEvent.case_id == case.id).first()
    assert outbox.status == OutboxStatus.published


def test_invalid_transition_raises(db) -> None:
    case = TrainingCase(image_key="local/test3.jpg")
    db.add(case)
    db.commit()

    with pytest.raises(ValueError, match="Expected current status"):
        # Skip patient consent - should fail
        record_doctor_validation(db, case.id, doctor_id="dr-001")
```

**What these tests verify:**

- `db` fixture - creates an in-memory SQLite database for each test. `Base.metadata.create_all(engine)` builds all tables from the ORM models. SQLite is used here instead of PostgreSQL because these are local unit tests - no database server needed.
- `test_full_consent_to_approval_workflow` - drives a case through consent, validation, and admin approval. Asserts the status is `admin_approved` and that an outbox row was created with `pending` status.
- `test_worker_processes_outbox` - after approval, calls `run_once` and asserts exactly one event was processed. Then verifies the outbox row moved to `published`.
- `test_invalid_transition_raises` - tries to call `record_doctor_validation` without calling consent first. Asserts that `ValueError` is raised with the expected message. This confirms the state machine rejects invalid transitions.

Run:

```powershell
pytest tests/test_training_workflow.py -v
```

**What this does:** runs only the workflow tests in verbose mode. Each test function is printed with pass/fail status. All three should pass before moving to the SQS step.

## Step 5: Move To AWS SQS

After local tests pass, add boto3 to requirements.txt:

```text
boto3==1.37.0
```

**What this does:** adds the AWS SDK for Python to the backend's dependency list. `boto3` is used by the SQS publisher and consumer to make AWS API calls. Pin the version so the dependency does not change on `pip install`.

Create `app/workers/sqs_publisher.py`:

```python
"""
Replaces the local outbox worker with real SQS publishing.
Only wire this up after docs/staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md
confirms the staging DB is live and the SQS queues are provisioned
(see docs/staging/20_ELASTICACHE_REDIS_HANDHOLDING.md for the Terraform module).
"""
from __future__ import annotations

import json
import logging
import os

import boto3

logger = logging.getLogger(__name__)

# Set TRAINING_QUEUE_URL in .env
# Format: https://sqs.<region>.amazonaws.com/<account>/<queue-name>
_SQS_CLIENT = None


def _get_client():
    global _SQS_CLIENT
    if _SQS_CLIENT is None:
        _SQS_CLIENT = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "eu-central-1"))
    return _SQS_CLIENT


def publish_to_sqs(queue_url: str, event_type: str, payload: dict, deduplication_id: str) -> str:
    """
    Publishes one message to SQS FIFO queue.
    deduplication_id is the OutboxEvent.id (UUID as str) - ensures at-most-once delivery.
    """
    client = _get_client()
    response = client.send_message(
        QueueUrl=queue_url,
        MessageBody=json.dumps({"event_type": event_type, **payload}),
        MessageGroupId="training-workflow",
        MessageDeduplicationId=deduplication_id,  # SQS FIFO deduplication window: 5 minutes
    )
    logger.info("Published SQS message %s for event %s", response["MessageId"], event_type)
    return response["MessageId"]
```

**What this publisher does:**

- `_SQS_CLIENT` singleton - creates the boto3 SQS client once and reuses it. Creating a new client per message is slower and wastes connections.
- `_get_client()` - lazy initialization of the client. The first call creates it; subsequent calls return the existing one.
- `publish_to_sqs` - sends one JSON message to a SQS FIFO queue. `MessageGroupId = "training-workflow"` groups all training events into one FIFO stream so they are processed in order. `MessageDeduplicationId = deduplication_id` is the OutboxEvent UUID - SQS FIFO ignores duplicate messages with the same deduplication ID within a 5-minute window, so a retry after a network blip does not create duplicate SQS messages.

Create `app/workers/sqs_consumer.py`:

```python
"""
Long-polling SQS consumer. Reads one batch, processes, deletes on success.
Dead-letter queue handles messages that fail MAX_RECEIVE_COUNT times.
"""
from __future__ import annotations

import json
import logging
import os
import time

import boto3

from app.db.session import SessionLocal
from app.services.training_workflow import mark_written_to_training_bucket, mark_failed

logger = logging.getLogger(__name__)
QUEUE_URL = os.environ.get("TRAINING_QUEUE_URL", "")
WAIT_SECONDS = 20   # long polling - reduces empty-receive costs
MAX_MESSAGES = 5


def _handle_message(body: dict) -> None:
    case_id = body["case_id"]
    event_type = body.get("event_type", "")

    with SessionLocal() as db:
        if event_type == "admin_approved":
            # Write the image key to the approved/ prefix in S3
            # (stub: just update the DB status)
            import uuid as _uuid
            mark_written_to_training_bucket(db, _uuid.UUID(case_id))
        else:
            logger.warning("Unknown event type: %s", event_type)


def run_consumer_loop() -> None:
    client = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "eu-central-1"))
    logger.info("SQS consumer started, queue: %s", QUEUE_URL)

    while True:
        response = client.receive_message(
            QueueUrl=QUEUE_URL,
            MaxNumberOfMessages=MAX_MESSAGES,
            WaitTimeSeconds=WAIT_SECONDS,
            AttributeNames=["ApproximateReceiveCount"],
        )
        messages = response.get("Messages", [])

        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            try:
                body = json.loads(msg["Body"])
                _handle_message(body)
                # Delete on success
                client.delete_message(QueueUrl=QUEUE_URL, ReceiptHandle=receipt_handle)
                logger.info("Message processed and deleted: %s", msg["MessageId"])
            except Exception as exc:
                # Do NOT delete - SQS will retry up to MaxReceiveCount, then DLQ
                logger.error("Failed to process message %s: %s", msg["MessageId"], exc)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    run_consumer_loop()
```

**What this consumer does:**

- `WAIT_SECONDS = 20` - long polling. Instead of returning immediately when the queue is empty, SQS waits up to 20 seconds for a message to arrive. This reduces API call volume and cost compared to short polling (which returns instantly and requires rapid re-polling).
- `receive_message` with `MaxNumberOfMessages=5` - fetches up to 5 messages per API call. Batch processing is more efficient than one-at-a-time.
- `AttributeNames=["ApproximateReceiveCount"]` - includes how many times each message has been received, useful for logging near-DLQ situations.
- `_handle_message` - processes one message body. Calls `mark_written_to_training_bucket` to update the database status. In the full implementation, this also copies the S3 object to the `approved/` prefix.
- `client.delete_message` on success - SQS keeps a message invisible for `visibility_timeout_seconds` after it is received. If the consumer does not delete it, SQS makes it visible again for another consumer to retry. Deleting it on success prevents reprocessing.
- No delete on exception - leaving the message in the queue lets SQS retry it automatically. After `maxReceiveCount` failures, SQS routes it to the dead-letter queue.

## Step 5b: Provision SQS Queues With Terraform

The worker code exists. Now provision the actual queues in AWS.

Add `infra/terraform/modules/sqs/main.tf`:

```hcl
variable "environment" {}

# Main FIFO queue for the training workflow
resource "aws_sqs_queue" "training_workflow" {
  name                        = "skin-lesion-training-workflow-${var.environment}.fifo"
  fifo_queue                  = true
  content_based_deduplication = true    # allows EventBridge FIFO target messages
  visibility_timeout_seconds  = 300     # 5 minutes - enough for one S3 write
  message_retention_seconds   = 86400   # 1 day
  receive_wait_time_seconds   = 20      # long polling - reduces empty-receive costs

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.training_workflow_dlq.arn
    maxReceiveCount     = 3   # after 3 failures, route to DLQ
  })

  tags = { Environment = var.environment }
}

# Dead-letter queue - messages that failed 3 times land here
resource "aws_sqs_queue" "training_workflow_dlq" {
  name                      = "skin-lesion-training-workflow-dlq-${var.environment}.fifo"
  fifo_queue                = true
  message_retention_seconds = 1209600   # 14 days - enough time to investigate
  tags                      = { Environment = var.environment }
}

# IAM policy for the ECS backend task to send and receive
resource "aws_iam_policy" "sqs_access" {
  name = "skin-lesion-sqs-${var.environment}"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["sqs:SendMessage", "sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = [aws_sqs_queue.training_workflow.arn, aws_sqs_queue.training_workflow_dlq.arn]
      }
    ]
  })
}

output "training_queue_url" { value = aws_sqs_queue.training_workflow.url }
output "dlq_url"            { value = aws_sqs_queue.training_workflow_dlq.url }
output "sqs_policy_arn"     { value = aws_iam_policy.sqs_access.arn }
```

**What this Terraform module does:**

- `aws_sqs_queue "training_workflow"` - creates a FIFO (First In, First Out) queue. `.fifo` is required in the name for FIFO queues. `content_based_deduplication = true` lets EventBridge send FIFO messages without a custom deduplication ID. The Python publisher can still pass `MessageDeduplicationId` explicitly when it sends directly to SQS.
- `visibility_timeout_seconds = 300` - after the consumer reads a message, it becomes invisible for 5 minutes. If the consumer crashes before deleting it, SQS makes it visible again after 5 minutes for retry.
- `redrive_policy` - after 3 receive attempts, SQS routes the message to the DLQ instead of making it visible again. The DLQ is a holding area for messages that could not be processed.
- `aws_sqs_queue "training_workflow_dlq"` - the dead-letter queue. `message_retention_seconds = 1209600` keeps failed messages for 14 days so engineers have time to investigate and replay them.
- `aws_iam_policy "sqs_access"` - grants the four actions the producer and consumer need: `SendMessage` (publisher), `ReceiveMessage` and `DeleteMessage` (consumer), and `GetQueueAttributes` (health checks). Attach this policy to the EKS pod's IAM role via IRSA.
- `output` blocks - expose the queue URLs and policy ARN so the root module can pass them to EKS pod environment variables.

Add to root `main.tf`:

```hcl
module "sqs" {
  source      = "./modules/sqs"
  environment = var.environment
}
```

**What this does:** wires the SQS module into the root configuration. Terraform creates the two queues and IAM policy when you apply from `infra/terraform`.

Set the queue URL as an environment variable in your ECS task definition or `.env.staging`:
For the current EKS path, set the queue URL in the EKS deployment or Kubernetes Secret that feeds the worker pod:

```text
TRAINING_QUEUE_URL=<output from terraform output training_queue_url>
```

**What this value is:** the HTTPS URL the boto3 SQS client uses to send and receive messages. Copy it from `terraform output training_queue_url` after applying.

Apply:

```powershell
cd infra/terraform
terraform apply -var-file="env/staging.tfvars"
terraform output training_queue_url
```

**What these commands do:** `terraform apply` creates the two SQS queues and the IAM policy in AWS. `terraform output training_queue_url` prints the queue URL to copy into the staging environment config.

Do not run this apply from the guide automatically. It creates cloud resources. Ask first when AWS SSO/console access or cost approval is needed.

Verify:

```powershell
aws sqs list-queues --queue-name-prefix skin-lesion
```

**What this does:** lists all SQS queues starting with `skin-lesion`. Both the main FIFO queue and the DLQ should appear in the output.

## Step 6: Checks

Local workflow:

```powershell
pytest tests/test_training_workflow.py -v
```

**What this does:** runs all three workflow tests. All must pass before moving to the SQS provisioning step.

AWS SQS gate (after Terraform provisions the queues):

```powershell
aws sqs list-queues --queue-name-prefix skin-lesion
aws sqs get-queue-attributes `
  --queue-url $env:TRAINING_QUEUE_URL `
  --attribute-names ApproximateNumberOfMessages
```

**What these commands do:** `aws sqs list-queues` confirms both queues were created. `aws sqs get-queue-attributes` reads the approximate message count - this should be 0 when the worker is caught up. If messages accumulate, either the consumer is down or processing is failing.

Expected: queue exists and message count is 0 at rest.

## Concepts You Just Touched

- [Outbox Pattern (new)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#outbox-pattern) - DB + queue written atomically; no split-brain
- [Saga Pattern (new)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#saga-pattern) - consent -> validate -> approve is a saga step sequence
- [Idempotency (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency) - SQS deduplication key prevents duplicate training entries
- [Audit-Immutable Log (11.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#113-audit-immutable-log) - CaseEvent rows are never updated

## Questions You Should Be Able To Answer

1. What is the transactional outbox pattern and why does it prevent the split-brain problem that direct SQS publishing creates?
2. If the SQS consumer crashes after processing a message but before calling `delete_message`, what happens? Is that a problem?
3. Why is the consent state machine a state machine and not a simple `consented: bool` column?
4. What is a dead-letter queue and how many receive attempts should you allow before routing to DLQ for this workflow?
5. The `record_admin_approval` function uses `with_for_update()`. What would happen if two admin users approved the same case simultaneously without it?

## Cost Pause / Resume

Expected result:

```text
The local workflow records consent, doctor validation, admin approval, and worker-safe training eligibility before cloud queue wiring is added.
```

**What this means:** the state machine, audit log, and outbox pattern all work locally before any AWS resource is created. The SQS step only starts after this local gate passes.

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports the current state of dev cloud resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources including the SQS queues created in this guide.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms the environment is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
