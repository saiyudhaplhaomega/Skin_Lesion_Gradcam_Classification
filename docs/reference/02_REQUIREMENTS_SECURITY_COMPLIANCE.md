# Requirements, Security, And Compliance

This guide explains what to think about before turning the app into a production-style healthcare project.

It is not legal advice. It is an engineering checklist for learning secure system design.

## Requirement Types

| Requirement | Meaning | Example |
|---|---|---|
| Functional | What the system does | Patient uploads image |
| Security | What the system protects | Only authorized doctors can review cases |
| Compliance | What must be auditable | Consent and approval history is stored |
| Reliability | How it behaves during failure | Worker retries failed queue messages |
| Cost | How you avoid waste | Dev EKS can be shut down |
| Performance | How fast it should respond | `/health` replies quickly |
| Operations | How you run it | Logs, alarms, rollback |
| Sustainability | How you avoid idle resources | Stop unused dev resources |

## Security Safeguards Before Microservices

Do not add many microservices first. Add safeguards to the simple app first.

Start with:

1. input validation
2. authentication later
3. authorization by role
4. no secrets in code
5. structured logs
6. least-privilege IAM in cloud
7. private subnets for internal services
8. encrypted storage

## Patient Workflow Requirements

The training data workflow should be explicit:

```text
patient consents -> doctor validates -> admin approves -> write to training bucket
```

**What this workflow means:**

- `patient consents` - the patient explicitly grants permission for their data to be used in training. Without this step, no training use is permitted regardless of what the doctor or admin decides.
- `doctor validates` - the doctor reviews the case, confirms the prediction and heatmap quality, and marks it as valid clinical data.
- `admin approves` - an admin reviews training eligibility and confirms the case meets data quality requirements.
- `write to training bucket` - only after all three prior steps complete successfully does the case get written to the training S3 bucket.

Each step needs:

- who did it
- when it happened
- current status
- reason for approval or rejection
- audit record

## Basic Data States

Use states before events:

```text
uploaded
patient_consented
doctor_validated
admin_approved
queued_for_training
written_to_training_bucket
rejected
failed
```

**What these data states mean:**

- `uploaded` - the image has been received by the backend. No analysis or consent yet.
- `patient_consented` - the patient has granted explicit consent for training use of this specific image.
- `doctor_validated` - a doctor has reviewed the case and confirmed it is valid for training.
- `admin_approved` - an admin has approved training eligibility for this case.
- `queued_for_training` - the case has been placed in the SQS training queue and is waiting for a worker to process it.
- `written_to_training_bucket` - the worker has successfully written the approved case to the training S3 bucket.
- `rejected` - the case was rejected at any step (patient withdrew consent, doctor invalidated, admin rejected). It never enters the training bucket.
- `failed` - a technical failure occurred during processing. The case may be retried or moved to a dead-letter queue.

Why: if the process crashes, the database still tells you where the case stopped.

## Compliance Checks

Before production-style deployment, verify:

- uploads are not public
- training bucket is not public
- protected actions require authorization
- consent is stored before training use
- deletions and rejections are auditable
- logs do not include raw secrets

## Learning Check

Before adding cloud services, write down:

```text
What data do I store?
Who can read it?
Who can change it?
How do I prove what happened?
What happens if one step fails?
```

**What this learning checklist means:**

- `What data do I store?` - before adding a new table or field, be specific about every piece of information persisted. Unexamined data is a compliance liability.
- `Who can read it?` - define the exact role set that can access each data type. "Admins can read everything" is not a valid answer.
- `Who can change it?` - some data should be immutable after creation (audit logs, consent records). Others can be updated with restrictions.
- `How do I prove what happened?` - every state change should have a timestamp, actor, and reason. The audit log is the proof.
- `What happens if one step fails?` - define the failure mode explicitly. Does the case stay in the current state? Does it move to `failed`? Does it retry automatically?

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current dev cloud resource state.
- `make cloud-pause ENV=dev` pauses resources that support pausing.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag is a deliberate safety guard.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before work begins.

If this guide was local-only, no cloud shutdown is needed.
