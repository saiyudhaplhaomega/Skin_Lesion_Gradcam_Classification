# Root command menu for the full Skin Lesion workspace.
#
# Run from:
#   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification

.PHONY: help backend-run backend-test backend-lint backend-typecheck frontend-dev frontend-build frontend-typecheck research-help cloud-status cloud-start cloud-pause cloud-resume cloud-shutdown cloud-start-dev cloud-shutdown-dev cloud-start-staging cloud-shutdown-staging cloud-start-prod cloud-shutdown-prod docs-check check

BACKEND_DIR := Skin_Lesion_Classification_backend
FRONTEND_DIR := Skin_Lesion_Classification_frontend
RESEARCH_DIR := Skin_Lesion_XAI_research
TERRAFORM_DIR := infra/terraform
ENV ?= dev
CONFIRM_PROD ?= NO

help:
	@echo "Skin Lesion workspace commands"
	@echo "  make backend-run        - Start FastAPI from the backend repo"
	@echo "  make backend-test       - Run backend pytest"
	@echo "  make backend-lint       - Run backend ruff"
	@echo "  make backend-typecheck  - Run backend mypy"
	@echo "  make frontend-dev       - Start Next.js from the frontend repo"
	@echo "  make frontend-build     - Build the Next.js frontend"
	@echo "  make frontend-typecheck - Run TypeScript checks"
	@echo "  make research-help      - Show research/notebook Makefile commands"
	@echo "  make cloud-status ENV=dev|staging|prod"
	@echo "  make cloud-start ENV=dev|staging|prod"
	@echo "  make cloud-pause ENV=dev|staging|prod"
	@echo "  make cloud-resume ENV=dev|staging|prod"
	@echo "  make cloud-shutdown ENV=dev|staging|prod CONFIRM_DESTROY=YES"
	@echo "  add CONFIRM_PROD=YES for any prod cloud operation"
	@echo "  make docs-check         - Check required guide files exist"
	@echo "  make check              - Run local backend/frontend/docs checks"

backend-run:
	$(MAKE) -C $(BACKEND_DIR) run

backend-test:
	$(MAKE) -C $(BACKEND_DIR) test

backend-lint:
	$(MAKE) -C $(BACKEND_DIR) lint

backend-typecheck:
	$(MAKE) -C $(BACKEND_DIR) typecheck

frontend-dev:
	$(MAKE) -C $(FRONTEND_DIR) dev

frontend-build:
	$(MAKE) -C $(FRONTEND_DIR) build

frontend-typecheck:
	$(MAKE) -C $(FRONTEND_DIR) typecheck

research-help:
	$(MAKE) -C $(RESEARCH_DIR) help

cloud-status:
	$(MAKE) -C $(TERRAFORM_DIR) status ENV=$(ENV)

cloud-start:
	$(MAKE) -C $(TERRAFORM_DIR) start ENV=$(ENV) CONFIRM_PROD=$(CONFIRM_PROD)

cloud-pause:
	$(MAKE) -C $(TERRAFORM_DIR) pause ENV=$(ENV) CONFIRM_PROD=$(CONFIRM_PROD)

cloud-resume:
	$(MAKE) -C $(TERRAFORM_DIR) resume ENV=$(ENV) CONFIRM_PROD=$(CONFIRM_PROD)

cloud-shutdown:
	$(MAKE) -C $(TERRAFORM_DIR) shutdown ENV=$(ENV) CONFIRM_DESTROY=$(CONFIRM_DESTROY) CONFIRM_PROD=$(CONFIRM_PROD)

cloud-start-dev:
	$(MAKE) cloud-start ENV=dev

cloud-shutdown-dev:
	$(MAKE) cloud-shutdown ENV=dev CONFIRM_DESTROY=$(CONFIRM_DESTROY)

cloud-start-staging:
	$(MAKE) cloud-start ENV=staging

cloud-shutdown-staging:
	$(MAKE) cloud-shutdown ENV=staging CONFIRM_DESTROY=$(CONFIRM_DESTROY)

cloud-start-prod:
	$(MAKE) cloud-start ENV=prod CONFIRM_PROD=$(CONFIRM_PROD)

cloud-shutdown-prod:
	$(MAKE) cloud-shutdown ENV=prod CONFIRM_DESTROY=$(CONFIRM_DESTROY) CONFIRM_PROD=$(CONFIRM_PROD)

docs-check:
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/00_START_HERE.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/01_BUILD_ORDER.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/08_APPLICATION_FEATURES.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/99_DOC_ORDER.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/01_LOCAL_BACKEND_FIRST.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/02_LOCAL_FRONTEND_AFTER_BACKEND.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/03_BACKEND_API_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/05_UPLOAD_AND_MOCK_PREDICTION_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/07_FRONTEND_WORKFLOW_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/08_MAKEFILE_TESTING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/11_FULL_PROJECT_TEST_PLAN.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/01_PROFESSIONAL_FEATURE_SEQUENCE.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/02_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/03_LESION_BODY_MAPPING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/04_XAI_LLM_AGENTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/05_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/06_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/07_CUSTOMER_DASHBOARD_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/08_LAB_RESULTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/09_MOBILE_APP_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/10_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/11_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/12_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/product/13_LAB_OCR_EXTRACTION_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/01_DOCKER_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/02_TERRAFORM_FROM_EMPTY_MAIN.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/03_TERRAFORM_VPC_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/04_KUBERNETES_AFTER_DOCKER.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/05_KUBERNETES_LOCAL_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/06_ECR_AND_EKS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/07_EVENTS_SQS_WORKER_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/07A_EVENT_WORKFLOW_AFTER_LOCAL_API.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/08_SECURITY_COMPLIANCE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/09_OBSERVABILITY_RELIABILITY_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/10_CICD_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/11_LOCAL_TO_STAGING_TO_PRODUCTION_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/12_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/13_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/14_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/15_TERRAFORM_DATABASE_AND_EVENTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/15A_AURORA_DSQL_STAGING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/16_TERRAFORM_SECURITY_OBSERVABILITY_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/staging/17_EKS_INGRESS_ALB_CONTROLLER_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/01_CLOUD_INFRASTRUCTURE_PATH.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/04_DATABASE_MULTI_REGION_PATH.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/05_OPERATIONS_RELIABILITY_COST.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/07_RUNTIME_ALTERNATIVES_EKS_AND_ECS.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/09_AUTO_HEAL_AND_ROLLBACK_LAMBDA_PATH.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/10_EKS_AUTO_HEAL_AND_ROLLBACK_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/reference/01_FULL_PROJECT_ROADMAP.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/reference/03_FUTURE_PLANS_REBUILT.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/reference/08_INFRA_MODULE_COVERAGE_AUDIT.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'Skin_Lesion_Classification_backend/.env.example')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'Skin_Lesion_Classification_frontend/.env.example')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'Skin_Lesion_Classification_frontend/GOOGLE_STITCH_PROMPTS.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'Skin_Lesion_Classification_frontend/STITCH_HANDOFF_GUIDE.md')) { exit 1 }"
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-validate.ps1
	@echo "docs-check ok"

check: backend-test backend-lint backend-typecheck frontend-typecheck frontend-build docs-check
