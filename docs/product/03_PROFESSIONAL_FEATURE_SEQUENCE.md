# Professional Feature Sequence

This is the code-along order for the original 30 product points plus the post-30 planning brief. Nothing from the product plan is dropped. Some features are placed later because their database, API, or UI contracts must exist first.

## Goal

Provide the canonical feature build order so teams know what to build next and why - based on backend contracts, frontend contracts, and prerequisite dependencies.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:

- `cd` changes the current terminal directory.
- This path is the main workspace, where root docs, root Makefile, and sub-repo folders live.
- Start here because this guide moves between backend, frontend, research, and infra areas.

This guide moves across repos. Each section names the current repo before commands.

## Sequence Rule

Build one block, run the check, then move on:

```text
backend contract -> backend test -> frontend contract -> frontend build -> docs check
```

What this sequence means:

- `backend contract` means define the API shape or backend model first.
- `backend test` proves the backend behavior works before the UI depends on it.
- `frontend contract` means update TypeScript types/API client to match the backend.
- `frontend build` proves the UI still compiles.
- `docs check` proves the guides remain consistent after changes.

## Phase 1: Core MVP

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means:

- `Skin_Lesion_Classification_backend` is where FastAPI, tests, upload routes, and prediction logic are built.
- `Skin_Lesion_Classification_frontend` is where the Next.js UI, upload form, and result states are built.

Build:

- FastAPI `app/main.py`
- `/health`
- `/api/v1/ready`
- tests for both endpoints
- backend Makefile checks
- Next.js scaffold check
- image upload
- single model prediction or mock prediction
- Grad-CAM response shape
- medical disclaimer
- Docker Compose after local checks pass

Check from the main workspace:

```powershell
make backend-test
make docs-check
```

What this command block does:

- `make backend-test` runs backend tests from the root workspace.
- `make docs-check` validates documentation structure and links.
- The frontend build is not required in this first MVP check until frontend work exists.

Why: every later feature needs a backend that starts and can be tested.

## Phase 2: Data Model, Lesion History, Body Mapping, Customer Dashboard

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means: this phase touches both backend persistence/API contracts and frontend lesion history/body-map screens.

Build:

- PostgreSQL and Alembic
- `users`, `lesions`, `images`, `analysis_events`
- `body_location_records`
- same-lesion/new-lesion workflow
- 2D body map
- lesion timeline
- basic customer dashboard
- doctor body-location approval workflow

Detailed guides:

```text
docs/product/05_LESION_BODY_MAPPING_HANDHOLDING.md
docs/product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md
```

What these guide paths mean:

- `05_LESION_BODY_MAPPING_HANDHOLDING.md` teaches lesion identity, location records, and 2D/3D body mapping.
- `08_CUSTOMER_DASHBOARD_HANDHOLDING.md` teaches the patient/customer dashboard built on top of stable lesion data.

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does:

- `make backend-test` verifies backend model/API behavior.
- `make frontend-build` verifies the Next.js frontend compiles after dashboard/body-map changes.

Expected result: every upload belongs to a persistent lesion profile unless the user explicitly chooses temporary analysis.

## Phase 3: Privacy, Consent, Storage, Audit, And Lab Upload

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means: privacy, consent, storage, audit, and lab upload require backend enforcement plus frontend user controls.

Build:

- storage modes: full clinical history, privacy balanced, maximum privacy
- consent history
- image deletion
- EXIF removal
- audit logs
- signed URLs
- basic role permissions
- privacy center
- lab result PDF/image upload
- lab result doctor visibility

Detailed guides:

```text
docs/product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md
docs/product/11_LAB_RESULTS_HANDHOLDING.md
```

What these guide paths mean:

- `04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` teaches consent, storage modes, deletion, audit, and signed URL rules.
- `11_LAB_RESULTS_HANDHOLDING.md` teaches lab-report upload and doctor visibility workflow.

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does: reruns backend and frontend checks after privacy and lab-result changes.

Expected result: images and lab files are private, consented, auditable, and never stored as raw binary in PostgreSQL.

## Phase 4: Better AI/XAI

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means: better AI/XAI changes affect backend analysis services and frontend explanation/triage UI.

Build:

- blur, lighting, glare, centering, distance, resolution, multiple-lesion, hair obstruction checks
- smart retake guidance
- `not_enough_information` response mode
- safety triage labels: `low_concern`, `monitor`, `retake_image`, `professional_review_recommended`, `urgent_review_recommended`
- symptom questionnaire fields
- segmentation mask
- ABCDE educational assistant
- calibrated confidence
- longitudinal change detection

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does:

- Backend tests verify quality gates, triage, segmentation, and calibration behavior.
- Frontend build verifies the UI still compiles with the new response shapes.

Expected result: poor images can safely stop analysis and explain why.

## Phase 5: Safe LLM Explanation

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this repo block means: safe LLM explanation begins in backend service code before the frontend displays it.

Build:

- structured facts builder
- simple explanation mode
- technical explanation mode
- doctor-facing summary
- safety validator
- body-location verification-aware explanation
- lab-result status-aware explanation

Detailed guide:

```text
docs/product/06_SAFE_LLM_EXPLANATION_HANDHOLDING.md
```

What this guide path means: this guide owns the safe explanation prompt, structured facts, validator, and refusal behavior.

Check:

```powershell
make backend-test
```

What this command does: runs backend tests for the explanation service and safety validator.

Expected result: the LLM may display unverified location and lab context, but never treats it as confirmed clinical fact.

## Phase 6: Doctor, Admin, Research, And Reports

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
```

What this repo block means: doctor/admin/research features require backend role enforcement and frontend dashboards.

Build:

- doctor dashboard
- review queue
- doctor notes
- body location approval/correction/rejection
- lab result review notes
- case summary
- PDF report
- admin training approval
- research dataset dashboard

Detailed guide:

```text
docs/product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md
docs/product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md
```

What these guide paths mean:

- `10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` covers doctor review, admin approval, reports, and role dashboards.
- `12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` covers research/fairness dashboards and model monitoring.

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does: verifies backend workflow behavior and frontend dashboard/report compilation.

Expected result: doctor/admin workflows preserve audit trails and do not modify immutable analysis events.

## Phase 7: Agentic XAI

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this repo block means: agentic XAI orchestration starts in backend services where safety, logs, and evaluation tests can be enforced.

Build:

- Google ADK-style SequentialAgent
- parallel explanation agents
- loop-based safety refinement
- agent logs
- agent evaluation tests

Detailed guide:

```text
docs/product/07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md
docs/reference/06_AGENTIC_XAI_ADK_PATH.md
```

What these guide paths mean:

- The product guide gives the implementation path.
- The reference guide gives broader architecture context for agentic XAI.

Check:

```powershell
make backend-test
```

What this command does: runs backend tests for agent orchestration, safety refinement, and logging behavior.

## Phase 8: Production And Cloud

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
infra
```

What this repo block means:

- Backend and frontend must already be repeatable locally.
- `infra` becomes active for Docker, Terraform, Kubernetes, observability, and cloud resources.

Build:

- S3 or equivalent object storage
- Aurora DSQL as the planned cloud database target
- Aurora PostgreSQL only as fallback if DSQL blocks progress
- CI/CD
- monitoring and observability
- environment promotion from local dev to staging
- embedded analytics with Power BI after analytics-safe views exist
- Terraform
- EKS later
- performance dashboards

Detailed guide:

```text
docs/staging/01_DOCKER_HANDHOLDING.md
docs/staging/15_OBSERVABILITY_RELIABILITY_HANDHOLDING.md
docs/staging/18_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md
docs/staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md
docs/production/01_CLOUD_INFRASTRUCTURE_PATH.md
```

What these guide paths mean:

- Staging guides cover Docker, observability, promotion, and Power BI.
- The production guide introduces production-style cloud architecture after staging basics work.

Check:

```powershell
make backend-test
make frontend-build
make docs-check
```

What this command block does:

- `make backend-test` verifies backend behavior.
- `make frontend-build` verifies frontend compilation.
- `make docs-check` verifies guide consistency before infrastructure changes.

Expected result: the local product has repeatable checks before cloud deployment, staging promotion, Power BI, or production work begins.

## Phase 9: Mobile And Advanced Body Mapping

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_Classification_frontend
Skin_Lesion_XAI_research
```

What this repo block means: mobile and advanced body mapping reuse backend/frontend contracts and may also depend on research outputs such as model or visualization methods.

Build:

- React Native / Expo
- camera capture
- offline encrypted mode
- push reminders
- 3D body map
- advanced lesion pins
- mobile lab result upload
- multi-model ensemble

Detailed guide:

```text
docs/product/16_MOBILE_APP_HANDHOLDING.md
docs/reference/05_3D_BODY_MAPPING_PATH.md
docs/reference/07_MOBILE_REACT_NATIVE_PATH.md
```

What these guide paths mean:

- `16_MOBILE_APP_HANDHOLDING.md` gives the product mobile build path.
- `05_3D_BODY_MAPPING_PATH.md` gives 3D body-map reference architecture.
- `07_MOBILE_REACT_NATIVE_PATH.md` gives React Native/Expo reference guidance.

Check:

```powershell
make backend-test
make frontend-build
```

What this command block does: verifies backend contracts and web frontend still work while mobile/3D work is introduced.

Expected result: mobile and 3D reuse stable backend contracts instead of creating a separate product.

## Architecture Guides To Read Before Large Features

Read these before implementing Phase 2 or later:

```text
docs/product/01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md
docs/product/02_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md
```

What these guide paths mean:

- The architecture guide explains where backend code belongs.
- The contracts guide defines domain entities and API shapes.
- Read them before large features so later code does not become tangled.

Why: KISS keeps the MVP simple, while SOLID boundaries prevent rewrites when adding ADK agents, 3D mapping, mobile, lab extraction, research dashboards, and cloud providers.

Check:

```powershell
make docs-check
```

What this command does: validates the documentation after changing feature sequencing or cross-guide references.

## Concepts You Just Touched

- [Saga (3.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#34-saga-choreography-versus-orchestration) - the multi-step training pipeline
- [Ensemble And Disagreement (9.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#95-ensemble-and-disagreement) - the safety triage layer
- [Active Learning Queue (9.6)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#96-active-learning-queue)
- [Refusal Patterns (12.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#122-refusal-patterns) - the retake assistant, the ABCDE assistant
- [Role-Scoped Agents (12.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#124-role-scoped-agents)
- [Output Validation (12.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#125-output-validation)

## Questions You Should Be Able To Answer

1. Why does image quality service come before the model service in the user flow? What happens if you skip it?
2. What is the safety triage layer doing that the model alone cannot?
3. Why is "retake guidance" a service, not a single rule?
4. How does the ABCDE educational assistant differ from a diagnosis?
5. Where in this sequence does the consent state machine intersect with model prediction?

If you cannot answer Q1-Q3, re-read the feature dependency map.
If you cannot answer Q4-Q5, read [System Design Patterns: 12.2 Refusal](../reference/09_SYSTEM_DESIGN_PATTERNS.md#122-refusal-patterns) and `04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md`.

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Patient sees a prediction on a blurry image | image quality gate skipped | check the triage flow |
| Educational assistant generates diagnosis-like text | refusal pattern not enforced | inspect prompt + output validator |
| Retake guidance always says the same thing | rule-based instead of model-driven | feature work after rule baseline |
| Symptom questionnaire optional fields are skipped silently | API treats `null` and missing identically | distinguish in the response |
| ABCDE assistant cites generic info | RAG corpus too broad | tighten the curated knowledge base |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks the dev cloud environment state.
- `make cloud-pause ENV=dev` pauses resources that can be paused.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev resources after confirmation.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes dev cloud resources.
- `make cloud-status ENV=dev` verifies state after startup.

If this guide was local-only, no cloud shutdown is needed.
