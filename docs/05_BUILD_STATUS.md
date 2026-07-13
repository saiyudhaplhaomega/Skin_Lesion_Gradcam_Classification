# Build Status

This page shows what is **actually built vs planned**. Keep it current by marking items done after running the guide's checks.

---

## How to Update This Page

After completing a guide:
1. Find the guide in the table below
2. Change the status from `PLANNED` or `IN PROGRESS` to `DONE`
3. Record the date and any notes in the Last Updated column
4. Add a checkmark in `02_ULTIMATE_PRODUCTION_GUIDE.md` gap table if it closes a gap

---

## Phase 1 - Local Development (15 guides)

| # | Guide | Status | Notes |
|---|-------|--------|-------|
| 01 | 01_LOCAL_BACKEND_FIRST.md | DONE | 2026-06-24 - pytest 114/114, ruff clean, mypy 0 errors |
| 02 | 02_LOCAL_FRONTEND_AFTER_BACKEND.md | DONE | 2026-06-24 - tsc typecheck + next build pass |
| 03 | 03_BACKEND_API_HANDHOLDING.md | DONE | 2026-06-24 - /api/v1/ready + /api/v1/analysis return 200 |
| 04 | 04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md | DONE | 2026-06-24 - all 11 Alembic migrations apply cleanly on fresh DB |
| 05 | 05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md | DONE | 2026-06-24 - /api/v1/analysis returns prediction + image quality (untrained_stub) |
| 06 | 06_MODEL_AND_GRADCAM_HANDHOLDING.md | DONE | 2026-06-24 - test_checkpoint.pth wired; GradCAM++ generates 156KB PNG; cam_png_b64 non-empty |
| 07 | 07_FRONTEND_WORKFLOW_HANDHOLDING.md | PLANNED | |
| 08 | 08_MAKEFILE_TESTING_HANDHOLDING.md | DONE | 2026-06-24 - backend-test, backend-lint, backend-typecheck, frontend-typecheck, frontend-build all pass |
| 09 | 09_DOCS_VALIDATION_HANDHOLDING.md | PLANNED | |
| 10 | 10_FRONTEND_SEO_HANDHOLDING.md | PLANNED | |
| 11 | 11_FULL_PROJECT_TEST_PLAN.md | PLANNED | |
| 12 | 12_DOCKER_COMPOSE_HANDHOLDING.md | DONE | 2026-06-24 - postgres:16 + redis:7-alpine both healthy via compose |
| 13 | 13_CIRCUIT_BREAKER_HANDHOLDING.md | DONE | 2026-06-24 - CircuitBreaker CLOSED/OPEN/HALF_OPEN + INFERENCE_SEMAPHORE(4) wired; tests pass |
| 14 | 14_CONFIDENCE_CALIBRATION_HANDHOLDING.md | DONE | 2026-06-24 - temperature=1.6842 calibration in calibration_service.py; patient-safe labels |
| 15 | 15_AMP_TRAINING_OPTIMIZATION.md | PLANNED | |

**Phase 1 Gate:** `make backend-test`, `make frontend-build`, `make docs-check` all green.
**Gate status as of 2026-06-24: PASSED** - pytest 114/114, ruff clean, mypy 0 errors, tsc pass, next build pass.

---

## Phase 2 - Product Features (18 guides)

| # | Guide | Status | Notes |
|---|-------|--------|-------|
| 01 | 01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md | DONE | 2026-06-25 - domain service stubs all implemented |
| 02 | 02_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md | DONE | 2026-06-25 - MulticlassAnalysisResponse, ExpertChatRequest schemas added |
| 03 | 03_PROFESSIONAL_FEATURE_SEQUENCE.md | PLANNED | |
| 04 | 04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md | DONE | 2026-06-25 - consent_service: 5-state machine (pending/consented/withdrawn/deletion_requested/deleted), 11 tests |
| 05 | 05_LESION_BODY_MAPPING_HANDHOLDING.md | DONE | 2026-06-25 - lesion_service CRUD + body_location_service (2D/3D, patient/doctor), 12 tests |
| 06 | 06_SAFE_LLM_EXPLANATION_HANDHOLDING.md | DONE | 2026-06-25 - minimax_explanation_service: 4 expert personas (Dermatologist/Pathologist/Risk/Uncertainty), 16 tests |
| 07 | 07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md | PLANNED | |
| 08 | 08_CUSTOMER_DASHBOARD_HANDHOLDING.md | PLANNED | |
| 09 | 09_SEO_AND_PUBLIC_PAGES_HANDHOLDING.md | PLANNED | |
| 10 | 10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md | DONE | 2026-06-25 - review_service (validate/correct/inconclusive/reject) + report_service + case_summary_service, 11 tests |
| 11 | 11_LAB_RESULTS_HANDHOLDING.md | PLANNED | |
| 12 | 12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md | PLANNED | |
| 13 | 13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md | DONE | 2026-06-25 - admin_market_research_service: pgvector RAG + MiniMax brief generation |
| 14 | 14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md | PLANNED | |
| 15 | 15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md | DONE | 2026-06-25 - source CRUD + approval flow + pgvector indexing |
| 16 | 16_MOBILE_APP_HANDHOLDING.md | PLANNED | |
| 17 | 17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md | PLANNED | |
| 18 | 18_LAB_OCR_EXTRACTION_HANDHOLDING.md | DONE | 2026-06-14 - manual-stub OCR provider, draft tables, review API, doctor UI, tests |

**Phase 2 Gate:** All 5 roles can log in and see only their own data. Role boundary test passes.

---

## Phase 3 - Staging Transition (21 guides)

| # | Guide | Status | Notes |
|---|-------|--------|-------|
| 00 | 00_CLOUD_COST_CONTROL_HANDHOLDING.md | PLANNED | |
| 01 | 01_DOCKER_HANDHOLDING.md | PLANNED | |
| 02 | 02_TERRAFORM_FROM_EMPTY_MAIN.md | PLANNED | |
| 03 | 03_TERRAFORM_VPC_HANDHOLDING.md | PLANNED | |
| 04 | 04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md | PLANNED | |
| 05 | 05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md | PLANNED | |
| 06 | 06_KUBERNETES_AFTER_DOCKER.md | PLANNED | |
| 07 | 07_KUBERNETES_LOCAL_HANDHOLDING.md | PLANNED | |
| 08 | 08_ECR_AND_EKS_HANDHOLDING.md | PLANNED | |
| 09 | 09_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md | PLANNED | |
| 10 | 10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md | PLANNED | |
| 11 | 11_AURORA_DSQL_STAGING_HANDHOLDING.md | PLANNED | |
| 12 | 12_EVENT_WORKFLOW_AFTER_LOCAL_API.md | PLANNED | |
| 13 | 13_EVENTS_SQS_WORKER_HANDHOLDING.md | PLANNED | |
| 14 | 14_SECURITY_COMPLIANCE_HANDHOLDING.md | PLANNED | |
| 15 | 15_OBSERVABILITY_RELIABILITY_HANDHOLDING.md | PLANNED | |
| 16 | 16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md | PLANNED | |
| 17 | 17_CICD_HANDHOLDING.md | PLANNED | |
| 18 | 18_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md | PLANNED | |
| 19 | 19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md | PLANNED | |
| 20 | 20_ELASTICACHE_REDIS_HANDHOLDING.md | PLANNED | |
| 21 | 21_MLFLOW_SERVER_HANDHOLDING.md | DONE | 2026-06-24 - MLflow v2.19.0 running locally at :5000, experiment created, run logged, metrics queryable |

**Phase 3 Gate:** All staging resources can be created and destroyed via `make cloud-pause` / `make cloud-shutdown ENV=dev`.

### Pre-deploy implementation update (2026-07-13)

The staging Terraform and Kubernetes configuration has been extended, but nothing from this batch has been applied to AWS yet. The remaining staging guides therefore stay `PLANNED` until their environment checks have been run.

- Terraform state now uses a separate backend key for dev, staging, and prod. Initialize with `terraform init -backend-config=env/backend-<env>.hcl -reconfigure` when changing environments.
- Terraform now includes Cognito, GitHub Actions OIDC and an environment-scoped deploy role, DSQL IRSA output and deletion safeguards, KMS rotation, and the optional monthly cost budget.
- Kubernetes now has startup probes, a dedicated backend ServiceAccount with an IRSA ARN placeholder, HPA, PodDisruptionBudget, and NetworkPolicy manifests. `infra/k8s/eks-prod/` now exists with the production manifest set.
- Parent-repository deployment workflows are disabled stubs. The real staging and production deployment workflows now live in the separate backend repository and use GitHub OIDC.
- The backend now includes model files in its image, uses the local checkpoint convention, enforces production CORS configuration, and has inference timeouts. Frontend authentication and authenticated API calls now use the Terraform-provisioned Cognito settings after apply.

---

## Phase 4 - Embedded Analytics (Power BI)

| Guide | Status | Notes |
|-------|--------|-------|
| staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md | PLANNED | |

**Phase 4 Gate:** No PHI in any Power BI report. All reports from analytics-safe views.

---

## Phase 5 - Production Readiness (12 guides)

| # | Guide | Status | Notes |
|---|-------|--------|-------|
| 01 | 01_CLOUD_INFRASTRUCTURE_PATH.md | PLANNED | Study only |
| 02 | 02_KUBERNETES_EKS_PATH.md | PLANNED | Study only |
| 03 | 03_EVENT_WORKFLOW_PATH.md | PLANNED | Study only |
| 04 | 04_DATABASE_MULTI_REGION_PATH.md | PLANNED | Study only |
| 05 | 05_OPERATIONS_RELIABILITY_COST.md | PLANNED | Study only |
| 06 | 06_MODEL_FAIRNESS_MONITORING_PATH.md | PLANNED | Study only |
| 07 | 07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md | PLANNED | Study only |
| 08 | 08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md | PLANNED | Study only |
| 09 | 09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md | PLANNED | Study only |
| 10 | 10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md | PLANNED | Study only |
| 11 | 11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md | PLANNED | Study only |
| 12 | 12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md | PLANNED | Study only |

**Phase 5 Gate:** Can answer all questions in 02_ULTIMATE_PRODUCTION_GUIDE.md Section 5 Gate.

---

## Phase 6 - Reference (9 docs)

| Guide | Status | Notes |
|-------|--------|-------|
| reference/01_FULL_PROJECT_ROADMAP.md | DONE | Static reference |
| reference/02_REQUIREMENTS_SECURITY_COMPLIANCE.md | PLANNED | |
| reference/03_FUTURE_PLANS_REBUILT.md | DONE | Static reference |
| reference/04_RECOVERY_AND_SOURCE_NOTES.md | PLANNED | |
| reference/05_3D_BODY_MAPPING_PATH.md | PLANNED | |
| reference/06_AGENTIC_XAI_ADK_PATH.md | PLANNED | |
| reference/07_MOBILE_REACT_NATIVE_PATH.md | PLANNED | |
| reference/08_INFRA_MODULE_COVERAGE_AUDIT.md | PLANNED | |
| reference/09_SYSTEM_DESIGN_PATTERNS.md | DONE | Static reference |

---

## Research Repo Status (Skin_Lesion_XAI_research/)

| Item | Status | Notes |
|------|--------|-------|
| RQ1 notebooks (model comparison) | IN PROGRESS | ResNet50 baseline, EfficientNet, ViT |
| RQ2 notebooks (Grad-CAM faithfulness) | PLANNED | AblationCAM, ScoreCAM, GradCAM++ comparison |
| RQ3 notebooks (fairness) | PLANNED | Fitzpatrick subgroup analysis |
| RQ4 notebooks (CAM disagreement) | PLANNED | Multi-CAM ensemble disagreement scoring |
| RQ5 notebooks (uncertainty quantification) | PLANNED | MC dropout, deep ensembles |
| num_workers=0 fix (gap #17) | PLANNED | Must set >= 4 |
| No AMP fix (gap #18) | PLANNED | Must enable mixed precision |
| Undertrained model fix (gap #19) | PLANNED | DISCREPANCY — train_backbones.py=2, run_training.py=10, conflicting values |
| Model promotion to backend | PLANNED | See 06_RESEARCH_BRIDGE.md |

---

## 28-Gap Tracker

From 02_ULTIMATE_PRODUCTION_GUIDE.md Section 5:

| Gap | Status | Closed by |
|-----|--------|-----------|
| 1 | OPEN | staging/05 + production/12 |
| 2 | OPEN | staging/03 |
| 3 | OPEN | staging/13 |
| 4 | OPEN | product/04 |
| 5 | OPEN | product/04 |
| 6 | OPEN | product/17 |
| 7 | OPEN | local-dev/06 + production/12 |
| 8 | OPEN | product/12 |
| 9 | OPEN | product/17 |
| 10 | OPEN | product/17 |
| 11 | OPEN | staging/08 |
| 12 | OPEN | product/17 |
| 13 | OPEN | product/12 |
| 14 | OPEN | production/08 |
| 15 | OPEN | product/12 + research |
| 16 | OPEN | product/12 |
| 17 | OPEN | research repo |
| 18 | OPEN | research repo |
| 19 | OPEN | research repo |
| 20 | OPEN | product/17 |
| 21 | CLOSED | Decision: end-to-end CNN only |
| 22 | OPEN | product/06 + staging/13 |
| 23 | OPEN | product/01 |
| 24 | OPEN | product/01 |
| 25 | OPEN | staging/13 |
| 26 | OPEN | staging/13 |
| 27 | OPEN | product/13 |
| 28 | OPEN | product/14 + product/15 |
| M1 | No frozen reference evaluation | OPEN | product/12 + research repo |
| M2 | No model promotion gate | CLOSED | 2026-06-24 - app/services/model_promotion_gate.py: val_auc/val_loss/training_samples gate before champion alias promotion; 6 tests pass |
| M3 | Makefile facade — commands exist, implementation doesn't | CLOSED | 2026-06-24 - backend-test/lint/typecheck + frontend-typecheck/build all run and pass |

---

## Status Legend

| Badge | Meaning |
|-------|---------|
| DONE | Guide completed, checks pass |
| IN PROGRESS | Guide is being actively worked on |
| PLANNED | Not started yet |
| CLOSED | Gap or decision is resolved, no action needed |
| OPEN | Gap exists, needs work |

---

## Last Updated

- Last updated: 2026-07-13
- Updated by: infrastructure and application pre-deploy fixes documented; AWS changes remain unapplied

### Verified Local State (2026-07-13)
- Backend test suite: 470 tests passing after the identity, inference timeout, and test-fixture fixes.
- `terraform fmt` passed. `terraform validate` was not run because the local AWS SSO session had expired.
- No Terraform resources from today's batch have been applied to AWS.

### Verified Local State (2026-06-25)
- `pytest`: 214/214 passing (was 122 - added 92 new tests for D1-D8 features)
- `ruff check`: all checks passed
- `mypy app`: 0 errors
- `docker compose up postgres redis`: both containers healthy
- `alembic upgrade head`: all 11 migrations apply cleanly on fresh DB
- `GET /api/v1/ready`: `{"status":"ready"}`
- `POST /api/v1/analysis`: 200 - prediction + CAM + faithfulness_score (D8) fields
- `POST /api/v1/analysis/multiclass`: 200 - 14-class and 12-class model endpoint (D1)
- `POST /api/v1/expert-chat/initial`: returns 4 MiniMax expert persona messages (D4)
- MLflow v2.19.0 at `http://localhost:5000`: healthy

### D1-D8 Implementation Summary (2026-06-25)
- D1: `multi_model_service.py` - 14-class (T=1.731) and 12-class (T=1.860) ResNet50 with per-model temperature
- D2: Per-model temperature from XAI project temperature.json files (binary T=1.684, 14class T=1.731, 12class T=1.860)
- D3: `cognito_auth.py` - Cognito JWKS JWT validation, `require_role()` dependency, bypass for tests; python-jose added to requirements.txt
- D4: `minimax_explanation_service.py` - 4 expert personas, MiniMax API via Anthropic-compatible endpoint
- D5-A: `consent_service.py` - 5-state machine, idempotent create, all transitions
- D5-B: `lesion_service.py` + `body_location_service.py` - CRUD + 2D/3D location with doctor verification
- D5-C: `review_service.py` - validate/correct/inconclusive/reject workflow
- D5-D: `notification_service.py`, `reminder_service.py`, `report_service.py`, `segmentation_service.py`, `triage_service.py`, `case_summary_service.py` - all implemented
- D6: `admin_market_research_service.py` - pgvector RAG + MiniMax brief generation; `admin_market_research_source_service.py` - source lifecycle
- D7: Aurora DSQL Terraform module ready (see infra/terraform/)
- D8: `faithfulness_service.py` - deletion/insertion AUC (30 steps), PredictionResult extended with faithfulness_score
