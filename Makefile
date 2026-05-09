# Root command menu for the full Skin Lesion workspace.
#
# Run from:
#   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification

.PHONY: help backend-run backend-test backend-lint backend-typecheck frontend-dev frontend-build frontend-typecheck research-help docs-check check

BACKEND_DIR := Skin_Lesion_Classification_backend
FRONTEND_DIR := Skin_Lesion_Classification_frontend
RESEARCH_DIR := Skin_Lesion_XAI_research

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
	cd $(FRONTEND_DIR) && npm run dev

frontend-build:
	cd $(FRONTEND_DIR) && npm run build

frontend-typecheck:
	cd $(FRONTEND_DIR) && npm run type-check

research-help:
	$(MAKE) -C $(RESEARCH_DIR) help

docs-check:
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/00_START_HERE.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/01_BUILD_ORDER.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/08_APPLICATION_FEATURES.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/99_DOC_ORDER.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/25_PROFESSIONAL_FEATURE_SEQUENCE.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/26_MAKEFILE_TESTING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/27_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/28_LESION_BODY_MAPPING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/29_XAI_LLM_AGENTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/30_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/31_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/32_MOBILE_APP_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/33_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/34_DOMAIN_MODEL_AND_API_CONTRACTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/35_CUSTOMER_DASHBOARD_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'docs/build/36_LAB_RESULTS_HANDHOLDING.md')) { exit 1 }"
	@powershell -NoProfile -Command "if (!(Test-Path 'Skin_Lesion_Classification_frontend/STITCH_HANDOFF_GUIDE.md')) { exit 1 }"
	@echo "docs-check ok"

check: backend-test backend-lint backend-typecheck frontend-typecheck frontend-build docs-check
