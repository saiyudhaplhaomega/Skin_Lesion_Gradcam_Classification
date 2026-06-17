# Safe Terraform learning commands.
# Destructive shutdown requires CONFIRM_DESTROY=YES.

.PHONY: version fmt validate plan guard-prod guard-destroy workspace status start pause resume shutdown

ENV ?= dev
CONFIRM_DESTROY ?= NO
CONFIRM_PROD ?= NO
NAMESPACE ?= skin-lesion-$(ENV)
RESUME_REPLICAS ?= 1
VAR_FILE := env/$(ENV).tfvars

version:
	terraform version

fmt:
	terraform fmt -recursive

validate:
	terraform validate

plan: guard-prod
	terraform plan -var-file="$(VAR_FILE)"

guard-prod:
	@powershell -NoProfile -Command "if ('$(ENV)' -eq 'prod' -and '$(CONFIRM_PROD)' -ne 'YES') { Write-Host 'Refusing prod operation. Re-run with CONFIRM_PROD=YES'; exit 1 }"

guard-destroy:
	@powershell -NoProfile -Command "if ('$(CONFIRM_DESTROY)' -ne 'YES') { Write-Host 'Refusing terraform destroy. Re-run with CONFIRM_DESTROY=YES'; exit 1 }"

workspace:
	terraform init -input=false
	@powershell -NoProfile -Command "terraform workspace select '$(ENV)'; if ($$LASTEXITCODE -ne 0) { terraform workspace new '$(ENV)' }"

status: guard-prod workspace
	terraform workspace show
	terraform state list

start: guard-prod workspace
	terraform apply -var-file="$(VAR_FILE)"

pause: guard-prod
	@powershell -NoProfile -Command "kubectl get namespace '$(NAMESPACE)' > $$null 2>&1; if ($$LASTEXITCODE -ne 0) { Write-Host 'Namespace $(NAMESPACE) not found. Nothing to pause.'; exit 0 }; kubectl scale deployment --all --replicas=0 -n '$(NAMESPACE)'; kubectl get deploy -n '$(NAMESPACE)'"

resume: guard-prod
	@powershell -NoProfile -Command "kubectl get namespace '$(NAMESPACE)' > $$null 2>&1; if ($$LASTEXITCODE -ne 0) { Write-Host 'Namespace $(NAMESPACE) not found. Run make start ENV=$(ENV) first.'; exit 1 }; kubectl scale deployment --all --replicas=$(RESUME_REPLICAS) -n '$(NAMESPACE)'; kubectl rollout status deployment --all -n '$(NAMESPACE)'"

shutdown: guard-prod guard-destroy workspace
	terraform destroy -var-file="$(VAR_FILE)"
