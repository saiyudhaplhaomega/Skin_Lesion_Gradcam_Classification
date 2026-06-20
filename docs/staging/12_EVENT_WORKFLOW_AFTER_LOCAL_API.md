# Event Workflow After Local API

This comes after the local API has database-backed training case state.

## Current Project Implementation

The backend now has the local database workflow pieces that this guide requires.

Files created or edited:

```text
Skin_Lesion_Classification_backend/app/models/case_event.py
Skin_Lesion_Classification_backend/app/models/outbox_event.py
Skin_Lesion_Classification_backend/app/models/__init__.py
Skin_Lesion_Classification_backend/app/services/training_workflow.py
Skin_Lesion_Classification_backend/app/workers/training_bucket_worker.py
Skin_Lesion_Classification_backend/alembic/versions/i4j5k6l7m829_add_case_events_and_outbox_events.py
Skin_Lesion_Classification_backend/tests/test_training_workflow.py
```

Check command:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_training_case_model.py tests/test_training_workflow.py -v
```

Expected result:

```text
TrainingCase defaults pass.
Consent, doctor validation, admin approval, case audit rows, and outbox row creation pass.
Local worker processes pending outbox rows and marks the case queued_for_training.
```

Why: this proves the business state machine locally before the cloud queue/worker path is used.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. AWS CLI checks for SQS and EventBridge run from here.

Backend code and tests in this guide belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** Python code, Alembic migrations, and pytest commands are run from inside the backend repo directory. `cd Skin_Lesion_Classification_backend` before running those commands.

AWS CLI checks can run from the repo root after the AWS resources exist.

## Why

The workflow:

```text
patient consents -> doctor validates -> admin approves -> write to training bucket
```

**What this workflow means:** each arrow is a separate human action that can happen at any time. A patient might consent on Monday, a doctor might validate on Wednesday, and the admin approval might come a week later. A single HTTP request cannot wait for all of that - each step must be stored in the database and picked up independently.

can take minutes or days. It should not be one long HTTP request.

## Goal

Build the database state model for the training case workflow before introducing event queues and workers.

## The Simple Version

First build the state in the database:

```text
pending_doctor_review
pending_admin_approval
approved_for_training
training_ready
rejected
withdrawn
```

**What these states mean:** each value is a valid status for a training case row in the database. `pending_doctor_review` is the initial state after the patient consents. `pending_admin_approval` means the doctor approved it and it is waiting for the admin. `approved_for_training` means the admin approved it and the image can be used. `training_ready` means the image was written to the `approved/` prefix in the training bucket. `rejected` and `withdrawn` are terminal states that prevent further processing.

Then add events and queues.

## Correct Order

1. Create `training_cases` table.
2. Make `POST /consent` idempotent.
3. Store the consented image in S3 immediately.
4. Create `outbox_events` table.
5. Add one outbox publisher worker.
6. Add SQS queues.
7. Add EventBridge rules.
8. Add worker for training-bucket write.
9. Add DLQ monitoring.

Current status:

```text
Steps 1, 4, and 5 are implemented locally.
Steps 6 and 7 are represented in Terraform in infra/terraform/events.tf.
Step 8 has a local worker stub and an SQS consumer shell.
Step 9 has initial CloudWatch queue-depth alarms in infra/terraform/security_observability.tf.
```

## Why Outbox Exists

Bad flow:

```text
update database -> publish event
```

**What goes wrong here:** if the app crashes or the event bus is unavailable between the database update and the event publish, the database change is committed but no event is ever sent. The workflow is stuck and nobody is notified.

Better flow:

```text
update database and insert outbox row in one transaction -> worker publishes event later
```

**What this fixes:** both the state change and the outbox row are written in the same database transaction. If either fails, both roll back - the database stays consistent. The outbox worker retries publishing until the event goes through, then marks the outbox row as published.

Now failed event publishing can retry.

## Checks

After SQS exists:

```powershell
aws sqs list-queues --queue-name-prefix skin-lesion-dev
```

**What this does:** lists all SQS queues whose names start with `skin-lesion-dev`. The main queue and the dead-letter queue should both appear.

After EventBridge exists:

```powershell
aws events describe-event-bus --name skin-lesion-dev-events
```

**What this does:** fetches the configuration of the custom EventBridge event bus. Confirms the bus was created with the right name and is available for rules to be attached to.

After workers exist:

```powershell
kubectl config current-context
kubectl get pods
kubectl logs deployment/worker-outbox-publisher
```

**What these commands do:** `kubectl config current-context` confirms your terminal is pointing to the correct Kubernetes cluster (dev, not staging or prod). `kubectl get pods` lists running pods including the outbox publisher worker. `kubectl logs deployment/worker-outbox-publisher` shows the worker's stdout - should show it polling the outbox table and publishing events to SQS or EventBridge.

## Stop Point

Do not add Airflow. This workflow is still simple enough for database state, EventBridge, SQS, and workers.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports what dev cloud resources are running. `make cloud-pause ENV=dev` scales worker pods to zero to stop compute charges. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources including SQS queues and EventBridge rules created in this guide.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms the environment is healthy before continuing to the next guide.

If this guide was local-only, no cloud shutdown is needed.
