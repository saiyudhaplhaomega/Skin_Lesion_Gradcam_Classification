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
	@echo "  make docs-check         - Check guide order, links, stale paths, and cloud doc gates"
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
	@powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-validate.ps1
	@echo "docs-check ok"

check: backend-test backend-lint backend-typecheck frontend-typecheck frontend-build docs-check
