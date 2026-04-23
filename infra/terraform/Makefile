# Skin Lesion Platform - Terraform Commands
# Usage: make apply, make destroy, make plan

ENV ?= prod
REGION ?= us-east-1
TFVARS = -var-file=environments/$(ENV).tfvars
TF_DIR = $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))

.PHONY: apply destroy plan format check validate output refresh dev prod init

init:
	@echo "Initializing Terraform..."
	cd $(TF_DIR) && terraform init

apply:
	@echo "Applying Terraform for $(ENV) environment..."
	cd $(TF_DIR) && terraform apply $(TFVARS) -auto-approve

destroy:
	@echo "Destroying Terraform for $(ENV) environment..."
	cd $(TF_DIR) && terraform destroy $(TFVARS) -auto-approve

plan:
	@echo "Planning Terraform for $(ENV) environment..."
	cd $(TF_DIR) && terraform plan $(TFVARS)

format:
	@echo "Formatting Terraform files..."
	cd $(TF_DIR) && terraform fmt -recursive

check:
	@echo "Checking Terraform files..."
	cd $(TF_DIR) && terraform fmt -check -recursive

validate:
	@echo "Validating Terraform modules..."
	cd $(TF_DIR) && terraform validate

output:
	@echo "Showing Terraform outputs..."
	cd $(TF_DIR) && terraform output

refresh:
	@echo "Refreshing Terraform state..."
	cd $(TF_DIR) && terraform refresh $(TFVARS)

init-and-plan:
	@echo "Initializing and planning..."
	cd $(TF_DIR) && terraform init && terraform plan $(TFVARS)

# Quick dev deployment (no MFA confirmation)
dev:
	@echo "Deploying to dev environment..."
	cd $(TF_DIR) && ENV=dev terraform init && ENV=dev terraform apply -var-file=environments/dev.tfvars -auto-approve

# Production deployment (requires MFA)
prod:
	@echo "Deploying to production - ensure you have MFA enabled!"
	@aws sts get-caller-identity | grep -q "arn:aws:iam::.*:user" && echo "User authenticated" || (echo "ERROR: Not authenticated"; exit 1)
	cd $(TF_DIR) && ENV=prod terraform init && ENV=prod terraform apply -var-file=environments/prod.tfvars -auto-approve

# Show what's missing for production
check-prod:
	@echo "Checking required variables for production..."
	@grep -r "REPLACE_ME\|CHANGE_THIS" $(TF_DIR)/environments/prod.tfvars 2>/dev/null && echo "WARNING: Found unfilled variables in prod.tfvars" || echo "All variables filled"
