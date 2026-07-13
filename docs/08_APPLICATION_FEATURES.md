# Application Features

This is the feature list for the project.

Use this file when you ask:

```text
What does my application actually do?
```

What this question means: use this feature list to connect implementation guides to actual user-facing, backend, frontend, and platform capabilities.

## Core User Features

| Feature | User | Build guide |
|---|---|---|
| Upload a skin lesion image | Patient/user | `local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md` |
| Receive a benign/malignant prediction | Patient/user | `local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md` |
| See model confidence | Patient/user | `local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md` |
| See Grad-CAM explanation heatmap | Patient/user | `local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md` |
| Give consent for training use | Patient/user | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| See clinical safety triage | Patient/user | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Answer optional symptom/context questions | Patient/user, doctor | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Receive smart retake guidance | Patient/user | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Set storage and retention mode | Patient/user | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` |
| Track lesion history over time | Patient/user, doctor | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| Mark lesion on a 2D body map | Patient/user | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| Mark lesion on a 3D body map | Patient/user | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md`, `reference/05_3D_BODY_MAPPING_PATH.md` |
| View segmentation mask and boundary overlay | Patient/user, doctor | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Use ABCDE educational assistant | Patient/user | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| View change detection over time | Patient/user, doctor | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Export case report PDF | Patient/user, doctor | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Use customer dashboard | Patient/user | `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md` |
| Upload lab result PDF/image | Patient/user, doctor | `product/11_LAB_RESULTS_HANDHOLDING.md` |
| Manage reminders and notifications | Patient/user | `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md` |

## Review And Governance Features

| Feature | User | Build guide |
|---|---|---|
| Doctor validates submitted case | Doctor | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| Admin approves training eligibility | Admin | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| Audit history records protected actions | Admin/compliance | `staging/14_SECURITY_COMPLIANCE_HANDHOLDING.md` |
| Rejected cases do not enter training bucket | Admin/compliance | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| Doctor reviews full lesion timeline | Doctor | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Doctor verifies body-map location | Doctor | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md`, `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Doctor reviews lab-result context | Doctor | `product/11_LAB_RESULTS_HANDHOLDING.md`, `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Doctor receives dermatology-style summary | Doctor | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Admin manages roles and permissions | Admin | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Admin/researcher views dataset dashboard | Admin/research reviewer | `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` |
| Research reviewer uses de-identified approved data | Research reviewer | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` |
| Admin, doctor, and researcher use embedded analytics | Admin/doctor/research reviewer | `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` |
| Admin uses market research RAG and decision briefs | Admin | `product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md` |
| Doctor uses reviewed workflow agent support | Doctor | `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` |
| Customer uses scoped education agent support | Patient/user | `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` |
| Research reviewer uses de-identified fairness agent summaries | Research reviewer | `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` |

## Backend Features

| Feature | Why it exists | Build guide |
|---|---|---|
| `/health` endpoint | Proves the process is alive | `local-dev/01_LOCAL_BACKEND_FIRST.md` |
| `/api/v1/ready` endpoint | Proves the app is ready for traffic | `local-dev/03_BACKEND_API_HANDHOLDING.md` |
| `/api/v1/analysis` endpoint | Accepts image upload and returns prediction | `local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md` |
| Model service | Keeps inference logic out of API routes | `local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md` |
| Database state model | Tracks consent, review, approval, and failures | `local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md` |
| Worker process | Handles background training-bucket workflow | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| Image quality service | Stops unreliable image analysis safely | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Triage service | Converts model, quality, symptoms, and history into safe UX categories | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Lesion service | Maintains lesion identity and timelines | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| Storage service | Enforces privacy mode and signed URL rules | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` |
| De-identification service | Reduces research/training privacy risk | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` |
| Segmentation service | Produces mask and boundary overlays | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Safe LLM explanation endpoint | Explains structured facts without diagnosis | `product/06_SAFE_LLM_EXPLANATION_HANDHOLDING.md` |
| Agentic XAI orchestrator | Runs sequential, parallel, and loop explanation workflows | `product/07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md`, `reference/06_AGENTIC_XAI_ADK_PATH.md` |
| LLM/RAG boundary policy | Separates clinical, admin, doctor, customer, and research agents | `product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md` |
| Admin market research RAG | Builds Golden Docs, source approval, vector retrieval, and decision briefs | `product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md` |
| Role-based evolving agents | Keeps doctor, customer, and research agents evolving safely | `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` |
| Calibration service | Converts raw confidence into safer reliability display | `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` |
| Body location service | Preserves patient-submitted and doctor-verified location history | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| Lab result service | Manages private lab-report uploads and doctor notes | `product/11_LAB_RESULTS_HANDHOLDING.md` |
| Dashboard service | Builds patient summary and activity feed | `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md` |
| Reminder and notification services | Track follow-up tasks and important user messages | `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md` |
| Power BI embed token service | Generates role-checked report embed configs without frontend secrets | `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` |
| Analytics-safe SQL views | Expose aggregated and pseudonymous monitoring data, not raw medical data | `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` |

## Frontend Features

| Feature | Why it exists | Build guide |
|---|---|---|
| Upload screen | Main user entry point | `local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md` |
| Loading state | Shows upload/analysis is running | `local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md` |
| Result state | Shows prediction and confidence | `local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md` |
| Error state | Handles invalid image or API failure | `local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md` |
| Explanation viewer | Shows Grad-CAM output later | `local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md` |
| Retake assistant | Guides better photo capture | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| Symptom questionnaire | Captures optional context for review | `product/03_PROFESSIONAL_FEATURE_SEQUENCE.md` |
| 2D body map | Lets users place lesion pins | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| 3D body map | Lets users place lesion pins on a body model | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md`, `reference/05_3D_BODY_MAPPING_PATH.md` |
| Lesion timeline | Shows history, images, predictions, Grad-CAM, masks, and notes | `product/05_LESION_BODY_MAPPING_HANDHOLDING.md` |
| Doctor dashboard | Supports case review and notes | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Admin dashboard | Supports approvals, audit, roles, and training eligibility | `product/10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md` |
| Research/model dashboard | Shows performance, fairness, and active learning queues | `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` |
| Customer dashboard | Shows lesions, body map, activity, reminders, lab status, reports, privacy | `product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md` |
| Lab results page | Uploads PDF/image lab reports with metadata and doctor review status | `product/11_LAB_RESULTS_HANDHOLDING.md` |
| Lab OCR extraction | Adds clinician-reviewed OCR drafts after simple lab upload works | `product/18_LAB_OCR_EXTRACTION_HANDHOLDING.md` |
| Power BI analytics pages | Embed internal admin, doctor, and research reports after backend token generation | `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` |
| Admin market research page | Uploads Golden Docs, reviews sources, asks strategy questions, and shows decision briefs | `product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md` |

## Platform Features

| Feature | Why it exists | Build guide |
|---|---|---|
| Docker backend image | Makes runtime repeatable | `staging/01_DOCKER_HANDHOLDING.md` |
| Docker Compose local stack | Runs local database/backend services together before Kubernetes | `local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md` |
| Cloud cost start/stop | Starts, pauses, resumes, and shuts down dev/staging/prod cloud resources with guarded commands | `staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md` |
| Local Kubernetes deployment | Teaches pods, services, probes, logs, rollout | `staging/07_KUBERNETES_LOCAL_HANDHOLDING.md` |
| ECR image registry | Stores backend image for AWS | `staging/08_ECR_AND_EKS_HANDHOLDING.md` |
| EKS dev deployment | Runs Kubernetes in AWS later | `staging/08_ECR_AND_EKS_HANDHOLDING.md` |
| Terraform VPC | Teaches public/private networking | `staging/03_TERRAFORM_VPC_HANDHOLDING.md` |
| Terraform bootstrap parameters | Teaches remote state bucket, lock table, and environment parameters | `staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md` |
| Terraform storage, secrets, and ECR | Teaches KMS, S3 buckets, Secrets Manager placeholders, and image repository setup | `staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md` |
| Terraform database and events | Teaches DSQL-oriented database access, fallback rules, SNS, and SQS/EventBridge placement | `staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md` |
| Aurora DSQL staging database | Validates the planned cloud database target before production or multi-region work | `staging/11_AURORA_DSQL_STAGING_HANDHOLDING.md` |
| Terraform security and observability | Teaches VPC flow logs, CloudWatch alarms, CloudTrail, GuardDuty, WAF, and Cognito order | `staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md` |
| SQS/EventBridge workflow | Handles long business workflow reliably | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| CI/CD checks | Automates tests only after they pass locally | `staging/17_CICD_HANDHOLDING.md` |
| Root Makefile command menu | Runs checks from the correct repo | `local-dev/08_MAKEFILE_TESTING_HANDHOLDING.md` |
| Environment promotion guide | Connects local dev, Docker, Kubernetes, AWS dev, staging, and production gates | `staging/18_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md` |
| Power BI embedded analytics | Adds analytics dashboards without replacing patient/customer UX | `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` |
| EKS Ingress and ALB Controller | Wires EKS services to ALB without using the ECS ALB module | `staging/09_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md` |
| Runtime alternatives | Explains EKS as the main path and ECS as an alternate/reference path | `production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md` |
| Blue-green, canary, and AppConfig | Teaches advanced release strategies after staging deploy works | `production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md` |
| ECS auto-heal and auto-rollback Lambda | Documents that existing Lambda code is ECS/ALB-only | `production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md` |
| EKS auto-heal and rollback | Teaches probes, HPA, rollout undo, and alarm runbooks for the main EKS path | `production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md` |
| AppConfig feature flags | Teaches runtime feature flags and safe app defaults | `production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md` |
| Redis/ElastiCache cache | Teaches short-lived cache without moving truth out of DSQL/Postgres | `production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md` |
| Observability metrics | Tracks latency, inference, Grad-CAM, LLM safety, queue, storage, and error rates | `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` |
| Training pipeline and model registry | Connects approved training cases to versioned datasets, model cards, and promotion | `product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md` |
| RAG and model evaluation plan | Adds repeatable eval gates for role-scoped RAG, the 14-class and 12-class XAI models, and multi-agent review loops | `07_RAG_EVAL_AND_MULTI_AGENT_EXECUTION_PLAN.md` |
| Mobile app | Adds React Native/Expo capture, offline storage, reminders, and sync | `product/16_MOBILE_APP_HANDHOLDING.md`, `reference/07_MOBILE_REACT_NATIVE_PATH.md` |
| Multi-model ensemble | Compares EfficientNet, ResNet, ViT, uncertainty, and disagreement | `product/16_MOBILE_APP_HANDHOLDING.md` |
| Synthetic/demo mode | Demonstrates the product without real user data | `product/16_MOBILE_APP_HANDHOLDING.md` |
| Domain architecture guide | Keeps backend KISS/SOLID and layered | `product/01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md` |
| Domain API contracts | Documents entity, table, endpoint, and immutability rules | `product/02_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md` |

## Later In The Sequence

Do not build these before their prerequisite guide:

- Airflow
- multi-region active-active
- production deploy automation
- patient-facing Power BI
- blue/green deployment
- canary deployment
- mobile app
- 3D body mapping
- ADK-style agent orchestration
- fairness dashboard

They are still documented and planned in:

```text
docs/reference/03_FUTURE_PLANS_REBUILT.md
docs/product/03_PROFESSIONAL_FEATURE_SEQUENCE.md
docs/product/01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md
docs/product/02_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md
docs/product/08_CUSTOMER_DASHBOARD_HANDHOLDING.md
docs/product/11_LAB_RESULTS_HANDHOLDING.md
docs/product/16_MOBILE_APP_HANDHOLDING.md
docs/product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md
docs/product/18_LAB_OCR_EXTRACTION_HANDHOLDING.md
docs/staging/18_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md
docs/staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md
docs/staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md
docs/staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md
docs/staging/10_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md
docs/staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md
docs/production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md
docs/production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md
docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md
docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md
docs/production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md
docs/production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md
docs/reference/05_3D_BODY_MAPPING_PATH.md
docs/reference/06_AGENTIC_XAI_ADK_PATH.md
docs/reference/07_MOBILE_REACT_NATIVE_PATH.md
docs/production/06_MODEL_FAIRNESS_MONITORING_PATH.md
docs/production/04_DATABASE_MULTI_REGION_PATH.md
docs/production/05_OPERATIONS_RELIABILITY_COST.md
```

What this path list means:

- These are existing guides that document planned advanced features.
- `docs/reference/03_FUTURE_PLANS_REBUILT.md` preserves broader future plans.
- Product guides describe user-facing, workflow, mobile, OCR, training, and dashboard features.
- Staging guides describe cloud, analytics, Terraform, database, security, and promotion work.
- Production guides describe runtime alternatives, release strategies, rollback, feature flags, cache, fairness, multi-region, and operations.
- The list is not a build command; it tells you where the later feature documentation lives.

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
- `make cloud-pause ENV=dev` pauses resources that support pausing.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev resources when you confirm destruction.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` starts or resumes the dev cloud environment.
- `make cloud-status ENV=dev` verifies the environment after startup.

If this guide was local-only, no cloud shutdown is needed.
