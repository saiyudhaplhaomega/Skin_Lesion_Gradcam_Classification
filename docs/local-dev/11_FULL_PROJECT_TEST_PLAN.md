# Full Project Test Plan

This guide lists the tests to build as the project grows.

Do not create every test on day one. Add each test when the matching feature exists.

## Current Local-Dev Note

If you have just finished `docs/local-dev/01_LOCAL_BACKEND_FIRST.md` through `docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md`, treat this guide as a roadmap, not as the next full build step.

Do now:

```text
backend health, readiness, upload, and analysis tests
frontend render, upload, loading, success, and error tests
docs-check from the repo root
```

Wait until later:

```text
Docker checks
Kubernetes checks
Terraform checks
event workflow checks
cloud pause/resume commands
```

What this means: the Docker, Kubernetes, Terraform, event workflow, and cloud sections are intentionally included for the future, but they are not relevant until those matching guides and project features exist. After local-dev guide 10, the next hands-on infrastructure guide is `docs/local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md`.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this does: moves your terminal to the main workspace before choosing the backend, frontend, Terraform, or Kubernetes test location.

Run backend tests from `Skin_Lesion_Classification_backend`.

Run frontend tests from `Skin_Lesion_Classification_frontend`.

Run Terraform checks from `infra/terraform`.

Run Kubernetes checks from the repo root.

## Backend Tests

Start:

```text
GET /health returns 200
GET /api/v1/ready returns 200
POST /api/v1/analysis rejects bad file type
POST /api/v1/analysis accepts image
```

What these first backend tests prove: the basic API is alive, ready, validates uploads, and accepts a valid image before any advanced workflow is added.

Then:

```text
database model default status is uploaded
patient consent moves status correctly
doctor validation requires consent first
admin approval requires doctor validation first
worker does not process unapproved case
duplicate event does not duplicate training bucket write
```

What these later backend tests prove: consent, doctor validation, admin approval, event processing, and training export follow the intended state machine without unsafe duplicate side effects.

## Frontend Tests

Start:

```text
page renders
upload control exists
loading state appears during upload
prediction appears after success
error appears after failed upload
```

What these frontend tests prove: the patient-facing upload flow handles initial render, interaction, waiting, success, and failure states.

## Docker Checks

```powershell
docker build -t skin-lesion-backend:local .
docker run --rm -p 8080:8080 skin-lesion-backend:local
curl http://localhost:8080/health
```

What these Docker checks prove:

- `docker build` creates a local backend image.
- `docker run` starts a container from that image and maps local port `8080`.
- `curl` confirms the containerized app responds to `/health`.

## Kubernetes Checks

```powershell
kubectl get pods -n skin-lesion-dev
kubectl rollout status -n skin-lesion-dev deployment/skin-lesion-backend
kubectl logs -n skin-lesion-dev deployment/skin-lesion-backend
curl http://localhost:8080/health
```

What these Kubernetes checks prove:

- Pods exist in the dev namespace.
- The backend deployment rolled out successfully.
- Logs are accessible for debugging.
- The service health endpoint responds through the configured local access path.

## Terraform Checks

```powershell
terraform fmt
terraform validate
terraform plan
```

What these Terraform checks prove:

- `terraform fmt` normalizes formatting.
- `terraform validate` checks configuration syntax and provider usage.
- `terraform plan` previews infrastructure changes before applying them.

## Event Workflow Checks

```text
case starts uploaded
patient consent creates audit event
doctor validation creates audit event
admin approval creates outbox event
worker processes event
case ends written_to_training_bucket
```

What these event checks prove: the training-data workflow moves through consent, review, approval, event emission, worker processing, and final export in the correct order.

## Security Checks

```text
no secrets in git
training bucket is not public
uploads are not public
protected actions require role
audit trail exists for protected actions
```

What these security checks prove: sensitive data is not public, protected actions require roles, and important healthcare actions leave an audit trail.

## Concepts You Just Touched

- [Frozen Reference Test Set (9.7)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#97-frozen-reference-test-set) - ML test discipline parallels software test discipline
- [Idempotency Keys (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys) - integration tests must cover retry behaviour
- [RED And USE Metrics (10.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#101-red-and-use-metrics) - tests measure latency and error rate; production measures the same

## Questions You Should Be Able To Answer

1. What is the difference between unit, integration, and end-to-end tests in this project? When do you add each?
2. Why must integration tests hit a real (test) database, not a mocked one?
3. What is a "smoke test" and why is it the first test you run after a deploy?
4. Why are tests around the consent state machine more important than tests around the upload form?
5. How does the frozen reference test set for ML fit alongside the software test suite?

If you cannot answer Q1-Q3, re-read the test categorisation section.
If you cannot answer Q4-Q5, read [System Design Patterns: 11.2 Consent](../reference/09_SYSTEM_DESIGN_PATTERNS.md#112-consent-state-machine) and [9.7 Frozen Reference Set](../reference/09_SYSTEM_DESIGN_PATTERNS.md#97-frozen-reference-test-set).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Test passes locally, fails in CI | env / dependency / DB state difference | run the failing test in a clean container |
| One slow test makes the suite skipped | no timeout enforced | add `pytest --timeout=30` |
| Flaky test that "passes most of the time" | hidden order dependency or time/randomness | use a fixed seed and isolate fixtures |
| 100% coverage but bugs in prod | tests test the code, not the behaviour | shift to test the contract |
| E2E suite takes 30 minutes | running against full data | sample data for E2E |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What these do:** report cloud resource status, pause running compute, and optionally destroy all dev resources to stop costs.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What these do:** recreate the dev environment and verify it is running before continuing.

If this guide was local-only, no cloud shutdown is needed.
