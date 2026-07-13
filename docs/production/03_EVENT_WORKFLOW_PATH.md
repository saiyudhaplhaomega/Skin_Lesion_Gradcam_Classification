# Event Workflow Path

This project needs events for long workflows.

The important flow is:

```text
patient consents -> doctor validates -> admin approves -> write to training bucket
```

**What this flow means:**

- Each arrow represents a separate human decision. Patient consent may happen at upload time; doctor validation may happen hours later; admin approval may happen the next day.
- Putting all of this inside a single HTTP request would require keeping a connection open for days, which is not practical.
- Instead, each step transitions the database record to a new state and publishes an event, so the next participant can pick up the workflow independently.

Do not put this entire flow inside one HTTP request.

## Why Events

Events help because:

- approvals may happen hours or days apart
- workers can retry failed steps
- queues survive restarts
- each step can be audited
- Kubernetes pods can restart without losing the workflow

## First Build It Without AWS

Start with database state:

```text
training_cases
case_events
outbox_events
```

**What these tables do:**

- `training_cases` holds the current state of each case moving through the workflow. One row per case, updated as each approval step completes.
- `case_events` is an append-only history of every state transition. It is the audit log - you never update or delete rows here.
- `outbox_events` is a staging area for events that need to be published to SQS or EventBridge. Writing to the outbox in the same database transaction as the state update ensures the event is never lost, even if the network goes down before the message reaches the queue.

Then add one worker process locally.

Only after that, use SQS and EventBridge.

## Suggested Components

| Component | Purpose |
|---|---|
| `training_cases` table | Current state |
| `case_events` table | Audit history |
| `outbox_events` table | Reliable events to publish |
| SQS queue | Durable background work |
| EventBridge rule | Routing between services later |
| worker pod | Processes queued work |

## Why Not Airflow Now

Airflow is useful for scheduled data pipelines and complex DAGs.

This project first needs user-driven approval workflow, queue retries, and audit state. SQS, EventBridge, and workers are a better first learning step.

## Failure Handling

Every worker should handle:

- invalid case state
- missing file
- duplicate event
- temporary S3 failure
- permanent rejection

## Learning Check

Before using AWS queues, prove this locally:

```text
Create case -> change status -> create outbox event -> worker processes event -> status changes
```

**What this local check means:**

- `Create case` - insert a new row into `training_cases` with the initial state.
- `change status` - update the case row to the next state (e.g., PENDING_DOCTOR_REVIEW).
- `create outbox event` - in the same database transaction, insert a row into `outbox_events` describing what happened.
- `worker processes event` - the local worker reads the outbox, finds the new event, and processes it.
- `status changes` - the worker updates `training_cases` to the next state as a result.

Completing this cycle locally with just a database and a worker proves the logic before you add any AWS services.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of dev cloud resources.
- `make cloud-pause ENV=dev` pauses resources that support pausing.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the explicit flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` verifies it is healthy before you begin.

If this guide was local-only, no cloud shutdown is needed.
