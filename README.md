# Skin Lesion Classification Learning Workspace

This workspace is for learning how to build the Skin Lesion platform step by step.

The goal is not to start with a finished cloud architecture. The goal is:

```text
build one small part -> understand why it exists -> run a check -> move to the next part
```

## Start Here

Read these first:

| Order | Guide | Purpose |
|---:|---|---|
| 1 | [`docs/00_START_HERE.md`](docs/00_START_HERE.md) | Current state, folder map, and what not to build yet |
| 2 | [`docs/01_BUILD_ORDER.md`](docs/01_BUILD_ORDER.md) | Environment-based build sequence |
| 3 | [`docs/08_APPLICATION_FEATURES.md`](docs/08_APPLICATION_FEATURES.md) | Feature list for the application |
| 4 | [`docs/99_DOC_ORDER.md`](docs/99_DOC_ORDER.md) | Canonical reading order |

## Guide Folders

| Folder | Purpose |
|---|---|
| [`docs/local-dev/`](docs/local-dev) | Local backend, frontend, frontend SEO, database, model, Makefile, Docker Compose, and test guides |
| [`docs/product/`](docs/product) | Patient, doctor, admin, research, privacy, XAI, role-based RAG agents, admin market research, public SEO reference, lab, OCR, training pipeline, dashboard, and mobile guides |
| [`docs/staging/`](docs/staging) | Docker, Terraform from scratch, storage, secrets, database, events, security, observability, Kubernetes, EKS dev, ALB Ingress, CI/CD, staging promotion, and Power BI |
| [`docs/production/`](docs/production) | Production-style cloud, EKS, ECS alternatives, release strategies, EKS/ECS healing paths, AppConfig, cache, database, reliability, cost, and fairness operations |
| [`docs/reference/`](docs/reference) | Roadmap, requirements, recovery notes, 3D, agentic XAI, and mobile reference |

## Smooth Build Path

Follow this environment sequence:

```text
local-dev -> product -> staging -> Power BI analytics -> production -> reference
```

Use the detailed order in:

```text
docs/99_DOC_ORDER.md
```

Power BI belongs in:

```text
docs/staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md
```

It is for admin, doctor, research, model, image-quality, consent, lab-result, and operations analytics. It is not the patient/customer dashboard.

Public SEO and education pages belong in:

```text
docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md
```

Use `docs/product/09_SEO_AND_PUBLIC_PAGES_HANDHOLDING.md` only as the product reference companion. Build SEO after the customer dashboard and privacy/consent workflows are clear, but before staging or production deployment. SEO is only for public education and marketing pages, never private patient, doctor, admin, research, analytics, lesion, lab-result, or report pages.

Role-separated LLM/RAG agents belong in:

```text
docs/product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md
docs/product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md
docs/product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md
```

Clinical explanations, admin market research, doctor workflow support, customer education, and research/fairness summaries must use separate data boundaries and approval rules.

## Current Rule

No GitHub Actions workflows are included right now.

No Terraform root `infra/terraform/main.tf` is included right now.

You will create those files yourself when the guide reaches that step.

Before creating cloud resources, read:

```text
docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md
```

Daily cloud controls from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-start ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

Each handholding guide should tell you:

1. which directory to run commands from
2. which exact file path to create or edit
3. which code or command to paste
4. which check proves the step worked
5. what success looks like
6. why the choice was made

## Local Environment Files

Use one local environment contract, but keep env files separate by app:

```text
Skin_Lesion_Classification_backend/.env
Skin_Lesion_Classification_frontend/.env.local
```

Start from the safe examples:

```powershell
Copy-Item Skin_Lesion_Classification_backend\.env.example Skin_Lesion_Classification_backend\.env
Copy-Item Skin_Lesion_Classification_frontend\.env.example Skin_Lesion_Classification_frontend\.env.local
```

The frontend should only use browser-safe `NEXT_PUBLIC_*` values. Backend secrets, database credentials, AWS secrets, and Power BI secrets stay backend-side or in cloud secret stores later.

## Repository Roles

| Path | Purpose |
|---|---|
| `Skin_Lesion_Classification_backend/` | Backend repo. Build local FastAPI here first. |
| `Skin_Lesion_Classification_frontend/` | Frontend repo. Build after backend health/mock analysis works. |
| `Skin_Lesion_XAI_research/` | Research notebooks and model experiments. |
| `infra/terraform/` | Terraform learning area. Root `main.tf` starts absent. |
| `docs/` | Beginner guides, build guides, and architecture notes. |

## Final Product Direction

The app is an AI-assisted educational and monitoring tool. It helps users organize lesion history, understand model outputs, track visible changes, upload optional lab-result context for doctor review, and prepare better information for professional medical review.

It must not be positioned as a skin-cancer diagnosis app. The product copy should always say:

```text
This is not a medical diagnosis.
The AI result is supportive information only.
Please consult a qualified clinician for medical concerns.
```

## What Comes Later

Later, after the local app works:

- Docker
- Kubernetes
- EKS Auto Mode
- EKS Ingress with AWS Load Balancer Controller
- SQS and EventBridge
- Aurora DSQL as the planned cloud database target
- Aurora PostgreSQL only as fallback if DSQL blocks progress
- Power BI embedded analytics
- AppConfig feature flags
- Redis/ElastiCache cache boundary
- training pipeline and model registry
- lab OCR extraction after simple lab upload works
- GitHub Actions
- multi-region

Do not build those early. Each one gets easier after the previous step works.

## Workspace Checks

After the root Makefile guide is in place, run these from the main workspace:

```powershell
make help
make docs-check
```

Use `make check` before commits once the backend and frontend features in the current guide exist.
