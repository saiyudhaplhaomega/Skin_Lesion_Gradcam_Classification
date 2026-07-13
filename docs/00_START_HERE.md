# Start Here

This project should be built in small steps. Do not create cloud infrastructure, Kubernetes manifests, analytics embeds, or GitHub Actions until the earlier local checks pass.

The rule is simple:

```text
Build one thing -> understand why it exists -> run one check -> then move on.
```

What this rule means:

- `Build one thing` means do not combine backend, frontend, database, Docker, and cloud work in one step.
- `understand why it exists` means every command or file should have a purpose before you paste it.
- `run one check` means prove the step worked before moving forward.
- `then move on` means the next guide should start only after the previous guide's check passes.

## What Exists Right Now

| Area | Current state | What you should do |
|---|---|---|
| Backend | Backend repo exists, but no FastAPI `app/` package yet | Build local `/health` first |
| Frontend | Frontend repo exists | Build UI only after backend `/health` and mock API work |
| Terraform | Old module and Lambda folders were removed after their ideas were integrated into guides; root `main.tf` is removed | Create `main.tf` only when the staging guide tells you |
| Kubernetes | No manifests yet | Create manifests only after Docker image works |
| GitHub Actions | No workflows | Add CI only after local tests exist |
| Power BI | Planned only | Add after native dashboards and analytics-safe views exist |
| Aurora DSQL | Planned cloud database target | Use local Postgres first, then validate DSQL in staging |
| Airflow | Not used | Skip it for now |

## Build Order

1. Read this file.
2. Read `01_BUILD_ORDER.md`.
3. Read `02_ULTIMATE_PRODUCTION_GUIDE.md` for the end-to-end narrative.
4. Skim `reference/09_SYSTEM_DESIGN_PATTERNS.md` for the concepts catalog you will return to as you build.
5. Check the feature list in `08_APPLICATION_FEATURES.md`.
6. Open `99_DOC_ORDER.md` and keep it as the canonical reading order.
7. Build local basics in `local-dev/`.
8. Add product features in `product/`.
9. Move toward staging in `staging/`.
10. Add Power BI only when you reach `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md`.
11. Study production readiness in `production/`.
12. Use `reference/` for roadmap and advanced explanations.

## Folder Map

| Folder | Work done there |
|---|---|
| `docs/local-dev/` | Local backend, frontend, database, model, Makefile, and test guides |
| `docs/product/` | Patient, doctor, admin, research, privacy, XAI, lab, OCR, training pipeline, dashboard, and mobile guides |
| `docs/staging/` | Docker, Terraform, Kubernetes, EKS dev, ALB Ingress, events, security, observability, CI/CD, staging promotion, and Power BI |
| `docs/production/` | Production-style cloud, EKS, ECS alternate path, event, database, AppConfig, cache, reliability, cost, and fairness operations |
| `docs/reference/` | Roadmap, requirements, recovery notes, 3D, agentic XAI, and mobile reference |

## Repo Map

| Repo/folder | Work done there |
|---|---|
| `Skin_Lesion_Classification_backend/` | FastAPI, models, Grad-CAM, LLM/XAI, consent, lab results, review, audit, reports, observability |
| `Skin_Lesion_Classification_frontend/` | Next.js upload UI, result viewer, customer dashboard, lab results, 2D/3D body maps, patient/doctor/admin dashboards |
| `Skin_Lesion_XAI_research/` | notebooks, training experiments, calibration, fairness, ensemble, research metrics |
| `infra/` | Docker, Kubernetes, Terraform, AWS learning path |
| `docs/` | build guides and architecture notes |

Before following a code snippet, check the guide's "Current repo" or "Command Location" line. Do not paste backend code into the frontend repo or frontend code into the main workspace.

## What Not To Do Yet

- Do not create or run `.github/workflows/*.yml` yet.
- Do not run Terraform against production.
- Do not build EKS before the backend has a Docker image.
- Do not build SQS/EventBridge before the local API state flow exists.
- Do not add Power BI before native doctor/admin/research dashboards and analytics-safe SQL views exist.
- Do not expose raw patient, image, lab file, or free-text medical data in Power BI.
- Do not wire ECS auto-heal Lambda code to EKS alarms.
- Do not add lab OCR before simple lab upload and doctor review work.
- Do not add Redis as source-of-truth state for consent, audit, or training eligibility.
- Do not add Airflow.
- Do not add multi-region.

These are sequencing rules, not cancellations. The complete professional path, including customer dashboard, lab results, 2D mapping, 3D mapping, mobile, agentic XAI, fairness, monitoring, Power BI, staging, and production learning, is documented in the later guides.

## Daily Habit

Before every session, ask:

```text
What is the next smallest thing I can build and check?
```

What this question does:

- It forces the task to stay small enough for a beginner to verify.
- If the answer includes multiple services or new cloud resources, split it into a smaller local step.

If the answer involves three services at once, make it smaller.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks the current dev cloud environment status.
- `make cloud-pause ENV=dev` pauses resources that can be stopped without deleting them.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources only when you intentionally confirm destruction.
- `CONFIRM_DESTROY=YES` is a safety guard so destructive cloud shutdown does not happen accidentally.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` verifies the environment state after starting it.

If this guide was local-only, no cloud shutdown is needed.
