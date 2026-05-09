# Skin Lesion Classification Learning Workspace

This workspace is for learning how to build the Skin Lesion platform step by step.

The goal is not to start with a finished cloud architecture. The goal is:

```text
build one small part -> understand why it exists -> run a check -> move to the next part
```

## Start Here

Read the guides in this order:

| Order | Guide | Purpose |
|---:|---|---|
| 1 | [`docs/00_START_HERE.md`](docs/00_START_HERE.md) | What exists now, what not to build yet |
| 2 | [`docs/01_BUILD_ORDER.md`](docs/01_BUILD_ORDER.md) | Full beginner build sequence |
| 3 | [`docs/02_LOCAL_BACKEND_FIRST.md`](docs/02_LOCAL_BACKEND_FIRST.md) | First FastAPI `/health` endpoint and test |
| 4 | [`docs/03_LOCAL_FRONTEND_AFTER_BACKEND.md`](docs/03_LOCAL_FRONTEND_AFTER_BACKEND.md) | Frontend only after backend shape exists |
| 5 | [`docs/04_TERRAFORM_FROM_EMPTY_MAIN.md`](docs/04_TERRAFORM_FROM_EMPTY_MAIN.md) | Create Terraform `main.tf` yourself from zero |
| 6 | [`docs/05_KUBERNETES_AFTER_DOCKER.md`](docs/05_KUBERNETES_AFTER_DOCKER.md) | Kubernetes only after Docker works |
| 7 | [`docs/06_EVENT_WORKFLOW_AFTER_LOCAL_API.md`](docs/06_EVENT_WORKFLOW_AFTER_LOCAL_API.md) | Consent workflow with database state, outbox, SQS, EventBridge |
| 8 | [`docs/07_CICD_ONLY_AFTER_TESTS.md`](docs/07_CICD_ONLY_AFTER_TESTS.md) | GitHub Actions only after useful local checks exist |
| 9 | [`docs/08_APPLICATION_FEATURES.md`](docs/08_APPLICATION_FEATURES.md) | Feature list for the application |

Then use the full-project handholding guides in dependency order. Some files were added later, so the guide number in the filename is not always the build order.

| Order | Guide |
|---:|---|
| 10 | [`docs/build/26_MAKEFILE_TESTING_HANDHOLDING.md`](docs/build/26_MAKEFILE_TESTING_HANDHOLDING.md) |
| 11 | [`docs/build/33_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md`](docs/build/33_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md) |
| 12 | [`docs/build/09_BACKEND_API_HANDHOLDING.md`](docs/build/09_BACKEND_API_HANDHOLDING.md) |
| 13 | [`docs/build/11_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md`](docs/build/11_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md) |
| 14 | [`docs/build/13_FRONTEND_WORKFLOW_HANDHOLDING.md`](docs/build/13_FRONTEND_WORKFLOW_HANDHOLDING.md) |
| 15 | [`docs/build/12_MODEL_AND_GRADCAM_HANDHOLDING.md`](docs/build/12_MODEL_AND_GRADCAM_HANDHOLDING.md) |
| 16 | [`docs/build/14_DOCKER_HANDHOLDING.md`](docs/build/14_DOCKER_HANDHOLDING.md) |
| 17 | [`docs/build/10_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`](docs/build/10_DATABASE_AND_MIGRATIONS_HANDHOLDING.md) |
| 18 | [`docs/build/34_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md`](docs/build/34_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md) |
| 19 | [`docs/build/28_LESION_BODY_MAPPING_HANDHOLDING.md`](docs/build/28_LESION_BODY_MAPPING_HANDHOLDING.md) |
| 20 | [`docs/build/35_CUSTOMER_DASHBOARD_HANDHOLDING.md`](docs/build/35_CUSTOMER_DASHBOARD_HANDHOLDING.md) |
| 21 | [`docs/build/27_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md`](docs/build/27_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md) |
| 22 | [`docs/build/36_LAB_RESULTS_HANDHOLDING.md`](docs/build/36_LAB_RESULTS_HANDHOLDING.md) |
| 23 | [`docs/build/25_PROFESSIONAL_FEATURE_SEQUENCE.md`](docs/build/25_PROFESSIONAL_FEATURE_SEQUENCE.md) |
| 24 | [`docs/build/29_XAI_LLM_AGENTS_HANDHOLDING.md`](docs/build/29_XAI_LLM_AGENTS_HANDHOLDING.md) |
| 25 | [`docs/build/30_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md`](docs/build/30_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md) |
| 26 | [`docs/build/31_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md`](docs/build/31_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md) |
| 27 | [`docs/build/22_FULL_PROJECT_TEST_PLAN.md`](docs/build/22_FULL_PROJECT_TEST_PLAN.md) |
| 28 | [`docs/build/15_TERRAFORM_VPC_HANDHOLDING.md`](docs/build/15_TERRAFORM_VPC_HANDHOLDING.md) |
| 29 | [`docs/build/16_KUBERNETES_LOCAL_HANDHOLDING.md`](docs/build/16_KUBERNETES_LOCAL_HANDHOLDING.md) |
| 30 | [`docs/build/17_ECR_AND_EKS_HANDHOLDING.md`](docs/build/17_ECR_AND_EKS_HANDHOLDING.md) |
| 31 | [`docs/build/18_EVENTS_SQS_WORKER_HANDHOLDING.md`](docs/build/18_EVENTS_SQS_WORKER_HANDHOLDING.md) |
| 32 | [`docs/build/19_SECURITY_COMPLIANCE_HANDHOLDING.md`](docs/build/19_SECURITY_COMPLIANCE_HANDHOLDING.md) |
| 33 | [`docs/build/20_OBSERVABILITY_RELIABILITY_HANDHOLDING.md`](docs/build/20_OBSERVABILITY_RELIABILITY_HANDHOLDING.md) |
| 34 | [`docs/build/21_CICD_HANDHOLDING.md`](docs/build/21_CICD_HANDHOLDING.md) |
| 35 | [`docs/build/32_MOBILE_APP_HANDHOLDING.md`](docs/build/32_MOBILE_APP_HANDHOLDING.md) |
| 36 | [`docs/build/23_FUTURE_PLANS_REBUILT.md`](docs/build/23_FUTURE_PLANS_REBUILT.md) |
| 37 | [`docs/build/24_RECOVERY_AND_SOURCE_NOTES.md`](docs/build/24_RECOVERY_AND_SOURCE_NOTES.md) |

Use the advanced guides for architecture reasoning:

| Order | Guide |
|---:|---|
| 30 | [`docs/advanced/30_FULL_PROJECT_ROADMAP.md`](docs/advanced/30_FULL_PROJECT_ROADMAP.md) |
| 31 | [`docs/advanced/31_REQUIREMENTS_SECURITY_COMPLIANCE.md`](docs/advanced/31_REQUIREMENTS_SECURITY_COMPLIANCE.md) |
| 32 | [`docs/advanced/32_CLOUD_INFRASTRUCTURE_PATH.md`](docs/advanced/32_CLOUD_INFRASTRUCTURE_PATH.md) |
| 33 | [`docs/advanced/33_KUBERNETES_EKS_PATH.md`](docs/advanced/33_KUBERNETES_EKS_PATH.md) |
| 34 | [`docs/advanced/34_EVENT_WORKFLOW_PATH.md`](docs/advanced/34_EVENT_WORKFLOW_PATH.md) |
| 35 | [`docs/advanced/35_DATABASE_MULTI_REGION_PATH.md`](docs/advanced/35_DATABASE_MULTI_REGION_PATH.md) |
| 36 | [`docs/advanced/36_OPERATIONS_RELIABILITY_COST.md`](docs/advanced/36_OPERATIONS_RELIABILITY_COST.md) |
| 37 | [`docs/advanced/37_3D_BODY_MAPPING_PATH.md`](docs/advanced/37_3D_BODY_MAPPING_PATH.md) |
| 38 | [`docs/advanced/38_AGENTIC_XAI_ADK_PATH.md`](docs/advanced/38_AGENTIC_XAI_ADK_PATH.md) |
| 39 | [`docs/advanced/39_MOBILE_REACT_NATIVE_PATH.md`](docs/advanced/39_MOBILE_REACT_NATIVE_PATH.md) |
| 40 | [`docs/advanced/40_MODEL_FAIRNESS_MONITORING_PATH.md`](docs/advanced/40_MODEL_FAIRNESS_MONITORING_PATH.md) |

## Current Rule

No GitHub Actions workflows are included right now.

No Terraform root `infra/terraform/main.tf` is included right now.

You will create those files yourself when the guide reaches that step.

Each handholding guide should tell you:

1. which directory to run commands from
2. which exact file path to create or edit
3. which check proves the step worked

## Repository Roles

| Path | Purpose |
|---|---|
| `Skin_Lesion_Classification_backend/` | Backend repo. Build local FastAPI here first. |
| `Skin_Lesion_Classification_frontend/` | Frontend repo. Build after backend health/mock analysis works. |
| `Skin_Lesion_XAI_research/` | Research notebooks and model experiments. |
| `infra/terraform/` | Terraform learning area. Root `main.tf` starts absent. |
| `docs/` | Beginner guides and feature list. |
| `docs/build/` | Copy-paste handholding guides for building the full project. |
| `docs/advanced/` | Architecture explanations for later decisions. |

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
- SQS and EventBridge
- Aurora DSQL or Postgres
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
