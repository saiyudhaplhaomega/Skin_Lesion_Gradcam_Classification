# Backend Domain Architecture Handholding Guide

Use this before building the larger post-30 features. It explains where code belongs so the backend does not turn into one giant file.

## Command Location

Run commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

What this command block does:

- The first `cd` moves your terminal to the main workspace.
- The second `cd` moves into the backend repository where FastAPI code lives.
- Run backend commands here so imports like `app.services...` resolve correctly.

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this means: every path in this guide starts inside `Skin_Lesion_Classification_backend/`, not inside the root workspace or frontend repo.

Every file path below is relative to `Skin_Lesion_Classification_backend`.

## Goal

Use a layered backend:

```text
API routes
  -> Pydantic schemas
  -> services
  -> repositories
  -> database / storage / ML / LLM providers
```

What this layer diagram means:

- `API routes` receive HTTP requests and return HTTP responses.
- `Pydantic schemas` define the request and response shapes.
- `services` contain business rules such as consent checks, review workflows, or analysis orchestration.
- `repositories` contain database access logic.
- `database / storage / ML / LLM providers` are adapters around concrete tools such as PostgreSQL, S3, PyTorch, or an LLM API.
- The arrows show dependency direction: routes call schemas/services; services call repositories/providers; lower layers should not import route code.

Why: routes should receive requests and return responses. They should not directly run models, touch object storage, write audit logs, parse lab reports, and generate PDFs.

## Step 1: Create The Folder Shape

Create this structure as the product grows:

```text
app/
  api/v1/
  schemas/
  services/
  repositories/
  models/
  providers/
    storage/
    classifiers/
    explainability/
    segmentation/
    llm/
    reports/
    lab_extraction/
  core/
```

What this folder structure does:

- `app/api/v1/` holds versioned FastAPI route modules.
- `app/schemas/` holds Pydantic request and response models.
- `app/services/` holds business logic.
- `app/repositories/` holds database query/write code.
- `app/models/` holds SQLAlchemy database models.
- `app/providers/storage/` holds storage adapters such as local storage or S3.
- `app/providers/classifiers/` holds classifier model adapters.
- `app/providers/explainability/` holds Grad-CAM or other explanation adapters.
- `app/providers/segmentation/` holds segmentation model adapters.
- `app/providers/llm/` holds LLM adapter implementations.
- `app/providers/reports/` holds PDF/report generation adapters.
- `app/providers/lab_extraction/` holds OCR or lab parsing adapters.
- `app/core/` holds shared config, security, logging, and infrastructure utilities.

Check:

```powershell
Get-ChildItem app
```

What this command does: lists the backend `app/` folder so you can verify the expected architecture folders exist.

Expected result: the backend has clear folders for routes, schemas, services, repositories, models, providers, and core utilities.

## Step 2: Keep API Routes Thin

Example route responsibility:

```text
validate request shape
call one service method
return response schema
```

What this route responsibility block means:

- `validate request shape` means the route accepts a Pydantic model or FastAPI parameters and lets validation happen at the boundary.
- `call one service method` means the route should delegate business logic instead of implementing it inline.
- `return response schema` means the route returns a Pydantic response object or a shape FastAPI can serialize.

Avoid:

```text
route directly calls boto3
route directly calls torch
route directly edits SQLAlchemy models
route directly writes PDFs
route directly builds LLM prompts
```

Why this avoid-list matters:

- `boto3` belongs behind a storage provider, not in route code.
- `torch` belongs behind model/classifier services, not in route code.
- SQLAlchemy model edits belong in repositories or services.
- PDF generation belongs in a report service/provider.
- LLM prompt construction belongs in a safe explanation service, where validation and refusal rules can be centralized.

Check:

```powershell
make test
```

What this command does: runs the backend test target so route/service boundaries are verified by tests.

Expected result: route tests can mock services cleanly.

## Step 3: Add Service Boundaries

Create services with one responsibility each:

```text
app/services/image_quality_service.py
app/services/model_inference_service.py
app/services/gradcam_service.py
app/services/segmentation_service.py
app/services/lesion_service.py
app/services/body_location_service.py
app/services/consent_service.py
app/services/storage_service.py
app/services/audit_service.py
app/services/report_service.py
app/services/review_service.py
app/services/lab_result_service.py
app/services/llm_explanation_service.py
app/services/triage_service.py
app/services/dashboard_service.py
app/services/reminder_service.py
app/services/notification_service.py
app/services/preference_service.py
```

What these service files do:

- `image_quality_service.py` validates whether an image is good enough for analysis.
- `model_inference_service.py` runs model prediction orchestration.
- `gradcam_service.py` creates explanation heatmaps.
- `segmentation_service.py` creates masks and lesion boundaries.
- `lesion_service.py` manages lesion identity and timelines.
- `body_location_service.py` manages patient and doctor body-location records.
- `consent_service.py` manages consent transitions and idempotency.
- `storage_service.py` saves and retrieves files through a storage provider.
- `audit_service.py` writes protected audit events.
- `report_service.py` builds report data and report files.
- `review_service.py` manages doctor review workflow.
- `lab_result_service.py` manages lab-result upload and review state.
- `llm_explanation_service.py` produces safe educational explanations.
- `triage_service.py` combines model/quality/context into safe triage categories.
- `dashboard_service.py` builds patient/customer dashboard summaries.
- `reminder_service.py` manages follow-up reminders.
- `notification_service.py` manages user notifications.
- `preference_service.py` manages user settings.

Why: each service should do one job. If a service uploads files, runs AI, manages reviews, creates reports, and writes audit logs, split it.

Check:

```powershell
make test
```

What this command does: runs backend tests after adding service boundaries.

## Step 4: Add Provider Interfaces

Create provider interfaces before hardcoding one tool:

```text
app/providers/storage/base.py
app/providers/classifiers/base.py
app/providers/explainability/base.py
app/providers/segmentation/base.py
app/providers/llm/base.py
app/providers/reports/base.py
app/providers/lab_extraction/base.py
```

What these provider interface files do:

- `storage/base.py` defines the common behavior storage providers must implement.
- `classifiers/base.py` defines how classifier providers expose prediction.
- `explainability/base.py` defines how Grad-CAM or similar explainability providers are called.
- `segmentation/base.py` defines segmentation provider behavior.
- `llm/base.py` defines safe LLM provider behavior.
- `reports/base.py` defines report generation provider behavior.
- `lab_extraction/base.py` defines OCR/lab extraction provider behavior.

Provider swaps this enables:

```text
LocalStorage -> S3Storage
EfficientNet -> ResNet -> ViT -> Ensemble
SimpleLLMProvider -> ADKAgentProvider
Manual lab entry -> OCR provider
Local model -> cloud model
```

What these swaps mean:

- `LocalStorage -> S3Storage` means services can move from local files to AWS S3 without route rewrites.
- `EfficientNet -> ResNet -> ViT -> Ensemble` means classifier implementations can change behind the same interface.
- `SimpleLLMProvider -> ADKAgentProvider` means the LLM implementation can evolve later.
- `Manual lab entry -> OCR provider` means lab parsing can start manually and later use OCR.
- `Local model -> cloud model` means inference can move from local PyTorch to a hosted model provider.

Check:

```powershell
make typecheck
```

What this command does: runs backend static type checking so interface contracts are caught before runtime.

Expected result: services depend on interfaces, not concrete libraries.

## Step 5: Apply SOLID And KISS

Rules:

```text
Single Responsibility: one service has one job.
Open/Closed: add providers without rewriting routes.
Liskov: all classifier providers return the same response shape.
Interface Segregation: no giant MedicalAIService.
Dependency Inversion: services depend on repositories/providers, not boto3, torch, OCR, or PDF libraries directly.
```

What these SOLID rules mean here:

- `Single Responsibility` keeps each service focused.
- `Open/Closed` lets you add new providers without editing route logic.
- `Liskov` means one classifier provider can replace another without changing callers.
- `Interface Segregation` prevents one huge interface that every feature depends on.
- `Dependency Inversion` keeps business logic depending on abstractions instead of concrete libraries.

KISS starting point:

```text
FastAPI
Next.js
PostgreSQL
Docker Compose
single classifier
Grad-CAM
2D body map
lesion timeline
privacy modes
basic consent
basic audit logs
customer dashboard
manual/PDF lab upload
doctor body-location approval workflow
```

What this starting point means: these are the smallest useful technologies and features that prove the product locally before advanced architecture work.

Avoid early:

```text
3D body map before 2D works
mobile before web/backend are stable
ADK agents before simple safe explanations work
multi-model ensemble before one model works
full AWS/EKS before Docker Compose works
automatic lab OCR before simple lab upload works
```

Why this avoid-list exists:

- Each item depends on a simpler workflow being stable first.
- Building advanced versions too early makes debugging harder because too many moving parts fail at once.

Check:

```powershell
make test
make typecheck
```

What this command block does:

- `make test` runs backend behavior tests.
- `make typecheck` runs backend static type checks.
- Run both after architecture changes so service boundaries are tested and typed.

Expected result: adding a new provider does not require rewriting the API route layer.

## Concepts You Just Touched

- Architect lens, hard.
- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service)
- [Bulkhead (2.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#22-bulkhead) - per-service semaphores or separate worker pools
- [Timeout Budget (2.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#24-timeout-budget) - propagated through the layers
- [Idempotency Keys (3.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#31-idempotency-keys)
- [Role Separation (11.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#114-role-separation) - the architecture must enforce this, not just middleware
- [Defense In Depth (8.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#83-defense-in-depth)

## Questions You Should Be Able To Answer

1. Why is the dependency direction `routes → services → repositories → providers` and never the reverse?
2. Where does the consent-check live - in the route, the service, or the repository? Why?
3. If you wanted to swap PostgreSQL for Aurora DSQL, which layers must change and which must not?
4. Why is "thin route + fat service + thin repository" the conventional shape, and when would you violate it?
5. How does the layered architecture make role separation easier to enforce?

If you cannot answer Q1-Q3, re-read the layering section and trace one endpoint through every layer.
If you cannot answer Q4-Q5, read [System Design Patterns: Family 11 Healthcare-Specific](../reference/09_SYSTEM_DESIGN_PATTERNS.md#family-11---healthcare-specific-patterns).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Route directly imports a SQLAlchemy session | layering violated | move DB access into a repository |
| Service depends on FastAPI types (Request, Response) | service is coupled to the transport | refactor to plain Python types |
| Repository contains business logic | the layer below is doing the layer above's job | move logic up to the service |
| Same DB query appears in three routes | abstraction missing | extract to a repository method |
| Circular import between service and repository | inverted dependency | use a Protocol or interface in services |

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
