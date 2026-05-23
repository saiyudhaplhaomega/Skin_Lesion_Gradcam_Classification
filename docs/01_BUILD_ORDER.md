# Build Order

This is the order to follow. Each step depends on the previous one.

The docs are grouped by environment so the path is easier to follow:

```text
local-dev -> product -> staging -> Power BI analytics -> production -> reference
```

What this sequence means:

- `local-dev` proves the app works on your machine.
- `product` adds patient, doctor, admin, research, and XAI features on top of local contracts.
- `staging` teaches production-like infrastructure one risk at a time.
- `Power BI analytics` is added only after native dashboards and analytics-safe data contracts exist.
- `production` is studied after staging is understood.
- `reference` preserves advanced design context and future plans.

## Phase 1: Local Development

Goal: prove the app works on your machine before adding cloud complexity.

Use:

```text
docs/local-dev/
```

What this path means: the local-dev folder contains the beginner guides for backend, frontend, database, model, tests, Makefiles, and local multi-service setup.

Build:

- FastAPI `/health`
- FastAPI `/api/v1/ready`
- local database and migrations
- image upload endpoint
- mocked prediction
- Grad-CAM response shape
- frontend upload, loading, result, and error states
- frontend SEO/public pages when the basic frontend route structure is clear
- root Makefile checks
- Docker Compose for local multi-service learning

Pass check from the main workspace:

```powershell
make backend-test
make frontend-build
make docs-check
```

What this command block does:

- `make backend-test` runs the backend repository test target from the root workspace.
- `make frontend-build` runs the frontend production build target from the root workspace.
- `make docs-check` validates the documentation reading order, links, and safety guardrails.

If a feature is not implemented yet, run only the check from the guide you are following.

## Phase 2: Product Features

Goal: build the user, doctor, admin, and research workflows on stable local contracts.

Use:

```text
docs/product/
```

What this path means: the product folder contains feature guides for user workflows, healthcare privacy, XAI explanations, dashboards, agents, mobile, OCR, and model registry work.

Build:

- privacy, consent, storage, and audit rules
- lesion history and body mapping
- safe XAI/LLM explanations
- separated LLM/RAG/agent boundaries across clinical, admin, doctor, customer, and research domains
- customer dashboard
- lab result upload and review
- doctor and admin dashboards
- research, fairness, calibration, and model monitoring
- role-based evolving agents for doctor workflow, customer education, and research/fairness
- admin market research RAG with Golden Docs and multi-agent decision briefs
- mobile app later
- training pipeline and model registry
- lab OCR and extraction after simple lab upload works
- backend architecture and API contract guides

Pass check:

```powershell
make backend-test
make frontend-build
make docs-check
```

What this command block does:

- Re-runs the backend tests after product feature changes.
- Rebuilds the frontend after UI or route changes.
- Revalidates the docs after guide edits.

Expected result: the native app experience works before external analytics or production deployment work.

Follow the product sequence in this order:

```text
domain architecture -> API contracts -> professional local features -> privacy/consent -> body mapping -> safe LLM -> LangChain/ADK/observability -> customer dashboard -> public SEO reference -> doctor/admin dashboards -> lab results -> research/fairness -> LLM/RAG boundaries -> role-based evolving agents -> admin market research RAG -> mobile app -> training pipeline/model registry -> lab OCR
```

What this sequence means:

- Start with backend/domain structure before UI-heavy features.
- Add privacy and consent before workflows that store or reuse sensitive health data.
- Build dashboards before external BI tools.
- Add RAG and agents with role separation instead of one shared assistant.
- Leave mobile, training registry, and OCR until the core web/backend workflows exist.

Build public SEO pages from:

```text
docs/local-dev/10_FRONTEND_SEO_HANDHOLDING.md
```

What this path means: SEO implementation is documented in the local-dev frontend SEO guide, even though it supports later public product pages.

SEO is only for public education and marketing pages. Do not index private patient, doctor, admin, research, analytics, lesion, lab-result, report, dashboard, or API pages.

Build role-separated RAG and multi-agent systems from:

```text
docs/product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md
docs/product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md
docs/product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md
```

What these guide paths mean:

- `13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md` defines safe boundaries between LLM, RAG, tools, and agents.
- `15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md` covers admin-only market research intelligence.
- `14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` covers separate role-based agents for doctor, customer, and research workflows.

Expected result: clinical explanations, admin market research, doctor workflow support, customer education, and research/fairness summaries use separate RAG sources, roles, traces, and approval rules.

## Phase 3: Staging Transition

Goal: move from local learning to production-like staging one risk at a time.

Use:

```text
docs/staging/
```

What this path means: the staging folder teaches Docker, Terraform, Kubernetes, AWS resources, observability, CI/CD, and analytics integration before production.

Build:

- cloud cost start/stop rules before creating AWS resources
- Docker image
- Terraform empty root
- Terraform VPC
- Terraform parameters and remote state bootstrap
- Terraform storage, secrets, and ECR
- local Kubernetes
- ECR and EKS dev path
- EKS Ingress and AWS Load Balancer Controller
- Terraform database and events
- Aurora DSQL staging database validation
- SQS/EventBridge worker path
- security and compliance controls
- observability and reliability checks
- Terraform security and observability
- CI/CD checks
- local-to-staging-to-production promotion map
- ElastiCache Redis after local Redis and staging VPC basics exist
- MLflow server after the training pipeline and model registry guide works locally

Pass check:

```powershell
make docs-check
```

What this command does: validates that the documentation order and links still work while staging guides evolve.

Run environment-specific checks from the guide you are following, such as:

```powershell
docker build -t skin-lesion-backend:local .
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-dev
terraform fmt
terraform validate
terraform plan
```

What these commands do:

- `docker build -t skin-lesion-backend:local .` builds a local backend container image and tags it.
- `kubectl rollout status ...` waits for a Kubernetes deployment rollout to finish.
- `terraform fmt` formats Terraform files.
- `terraform validate` checks Terraform syntax and provider configuration.
- `terraform plan` previews infrastructure changes before applying them.

Expected result: dev and staging are clearly separated from production.

## Phase 3 Step Order

Follow this staging order exactly:

```text
1. Cloud cost start/stop commands
2. Docker image
3. Terraform empty main
4. Terraform VPC
5. Terraform parameters and bootstrap
6. Terraform storage, secrets, and ECR
7. Local Kubernetes
8. ECR and EKS dev path
9. EKS Ingress and AWS Load Balancer Controller
10. Terraform database and events
11. Aurora DSQL staging database validation
12. Event workflow and worker
13. Security and compliance
14. Observability and reliability
15. Terraform security and observability
16. CI/CD checks
17. Local-to-staging-to-production promotion
18. Power BI embedded analytics
19. ElastiCache Redis
20. MLflow server
```

What this staging order does:

- Starts with cost controls before any cloud resources are created.
- Builds Docker and Terraform basics before Kubernetes.
- Adds networking, storage, secrets, databases, and events before observability and CI/CD.
- Leaves Power BI, Redis, and MLflow until the underlying app and staging infrastructure are ready.

## Phase 4: Embedded Analytics With Power BI

Goal: add Power BI as an internal analytics layer, not as the patient dashboard.

Use:

```text
docs/staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md
```

What this path means: Power BI is treated as staging/internal analytics work, not as the patient-facing dashboard.

Power BI consumes:

- analytics-safe SQL views
- de-identified or pseudonymous fields
- aggregated model, consent, quality, review, and operations data

Power BI must not expose:

- patient names or emails
- raw image URLs
- lab report file URLs
- free-text patient notes
- free-text doctor notes
- frontend secrets

Pass check:

```powershell
make docs-check
```

What this command does: revalidates documentation links and sequencing after analytics documentation changes.

Expected result: Power BI sits after native dashboards and research monitoring, and before production-only operating decisions.

## Phase 5: Production Readiness

Goal: understand production architecture after local, product, and staging paths work.

Use:

```text
docs/production/
```

What this path means: production guides explain the final operating model after local and staging paths are understood.

Plan:

- cloud infrastructure
- Kubernetes and EKS operations
- event workflow operations
- Aurora DSQL as the intended cloud database target, with Aurora PostgreSQL only as fallback
- reliability, cost, RTO, and RPO
- model fairness and production monitoring
- EKS versus ECS runtime decision
- blue-green, canary, and AppConfig release strategies
- ECS auto-heal and auto-rollback Lambda reference path
- EKS-native auto-heal and rollback path
- AppConfig feature flag implementation
- Redis/ElastiCache cache boundary

Do not build production deploy automation until manual staging deployment works.

## Phase 6: Reference And Advanced Topics

Use:

```text
docs/reference/
```

What this path means: reference docs are for roadmap, requirements, recovery notes, architecture options, and advanced design topics.

Read these for:

- full roadmap context
- requirements and compliance thinking
- future plans
- recovery/source notes
- 3D body mapping
- agentic XAI
- mobile React Native

## Rule

Before you paste code, every guide must tell you:

1. the directory to run commands from
2. the exact file path to create or edit
3. the code or command to paste
4. the check command to run
5. what success looks like
6. why the choice was made
7. whether the file may contain local secrets and how to keep those secrets out of Git

## Secret Hygiene Rule

Do not commit real secrets or password-shaped local values.

Use committed files for structure:

```text
docker-compose.local.yml
README.md
docs/**/*.md
```

Use ignored files for local values:

```text
.env
.env.local
.env.staging
.env.prod
infra/compose/.env.local
```

Before committing a guide or config that mentions Redis, databases, tokens, cloud credentials, LLM keys, OAuth secrets, or embed secrets, run:

```powershell
git status --short --ignored
git grep -n "PASSWORD=.*[^>]" -- .
git grep -n "SECRET=.*[^>]" -- .
git grep -n "TOKEN=.*[^>]" -- .
```

Expected result: only placeholder examples appear in documentation, and no runtime config contains a real value.

If a secret is pushed, rotate it first, then remove it from current files. Rewriting Git history is a separate explicit decision because it requires force-pushing.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks the dev cloud environment.
- `make cloud-pause ENV=dev` pauses resources where possible.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev cloud resources when confirmed.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes the dev cloud environment.
- `make cloud-status ENV=dev` confirms the environment state after startup.

If this guide was local-only, no cloud shutdown is needed.
