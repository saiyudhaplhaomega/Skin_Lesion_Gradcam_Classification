# Security And Compliance Handholding Guide

Use this after the basic API, database, and workflow exist.

## Current Project Implementation

The first application security boundary is now implemented in the analysis upload endpoint.

Files created or edited:

```text
Skin_Lesion_Classification_backend/app/api/v1/router.py
Skin_Lesion_Classification_backend/tests/test_security.py
```

Checks:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_security.py -v
```

Expected result:

```text
text/plain upload returns 400
empty PNG upload returns 400
image larger than 10 MB returns 413
```

Why: the upload endpoint is the first untrusted input boundary in the skin-lesion workflow. Type, empty-file, and size checks should exist before relying on staging or production perimeter controls.

## Goal

Add security controls in the same order the app becomes risky.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root before changing into the backend or Terraform directories for their respective commands.

Backend validation, authorization, and audit code belongs in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** Python security middleware, role checks, and audit log code go in the backend repo. Run `cd Skin_Lesion_Classification_backend` before running tests or the backend server.

Terraform security controls belong in:

```text
infra/terraform
```

**What this means:** WAF rules, security group rules, CloudTrail config, and GuardDuty enablement go in Terraform files here. Run `cd infra/terraform` before any `terraform` command.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Terraform root: `infra/terraform/`
- Create or edit validation, authorization, and audit code under `Skin_Lesion_Classification_backend/`.
- Create or edit cloud security controls under `infra/terraform/`.

## Step 1: Input Validation

Add limits:

- only JPEG and PNG
- max file size: 10 MB for the current learning API boundary
- reject empty file
- reject unknown content type

Tests:

```text
bad file type returns 400
empty file returns 400
large file returns 413
valid image returns 200
```

**What these test cases verify:** each HTTP status code represents a specific rejection reason. `400 Bad Request` for invalid file types and empty files - the request is malformed. `413 Payload Too Large` for oversized files - a correct type but too large. `200 OK` only when the file passes every check. These four cases cover the input boundary completely.

## Step 2: Secrets

Use `.env` locally.

Never commit:

```text
DATABASE_URL with password
AWS keys
JWT secrets
API keys
```

Check:

```powershell
git status --short
```

**What this does:** shows modified and untracked files in a compact one-line-per-file format. Before committing, scan this list for `.env` files, credential files, or anything that should not be committed. If a sensitive file appears, add it to `.gitignore` before staging.

## Step 3: Authorization Later

Roles:

```text
patient
doctor
admin
worker
```

**What these roles mean:** four distinct principals with different capabilities. `patient` can upload their own image and consent to training use - nothing else. `doctor` can validate cases assigned to them and set labels. `admin` is the final approver before training data is written. `worker` is a service account (Kubernetes pod) that automates the approved-to-training-bucket write - no human user logs in as worker.

Rules:

- patient can upload and consent for own case
- doctor can validate assigned cases
- admin can approve training use
- worker can write approved cases to training bucket

## Step 4: Audit Trail

Every protected action writes:

```text
who
what
when
case id
old status
new status
reason
```

**What each field captures:** `who` is the actor ID (user ID, service account). `what` is the action name (e.g., `doctor_validated`, `admin_approved`). `when` is the UTC timestamp. `case id` links the audit entry to the specific patient case. `old status` and `new status` make the state change explicit so auditors can reconstruct the full case history. `reason` captures optional context like a rejection explanation.

## Step 5: Cloud Security Later

Add:

- private app subnets
- private data subnets
- S3 block public access
- least-privilege IAM
- Secrets Manager
- KMS later
- WAF later
- CloudTrail later

**What this build order means:** network isolation (private subnets) prevents accidental public exposure. S3 block public access prevents storage data leaks. Least-privilege IAM limits blast radius if credentials are compromised. Secrets Manager replaces plaintext passwords in environment variables. KMS, WAF, and CloudTrail add encryption-at-rest, request filtering, and API audit logging once the core app is running - they are listed as "later" because they require the basic infrastructure to exist first.

## Compliance Learning Check

Before using data for training, prove:

```text
patient consent exists
doctor validation exists
admin approval exists
audit trail exists
training bucket write is logged
```

**What this gate means:** each condition maps to a database record or log entry that can be queried. Before a case's image enters model training, all five conditions must be true for that case. This is the minimum proof of compliance for a medical AI training dataset.

## Check

Run from the backend repo:

```powershell
python -m pytest tests/test_security.py -v
```

**What this does:** runs only the security-specific test file in verbose mode. Tests here verify that bad inputs are rejected, that role-based access rules are enforced, and that audit log entries are created for protected actions.

Run from the repo root:

```powershell
make backend-test
```

**What this does:** runs the full backend test suite using the Makefile target. Broader than the single test file above - covers all tests including security, workflow, and API tests together.

Expected result: all security and compliance checks pass.

## Cost Pause / Resume

Expected result:

```text
Sensitive actions are auditable, private data is not exposed in analytics, and cloud security controls are sequenced after local app boundaries exist.
```

**What this means:** the three properties hold together - you can trace who did what to any case, analytics queries cannot reach raw patient data, and cloud hardening was added in the right order rather than bolted on after production traffic starts.

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports running dev resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
