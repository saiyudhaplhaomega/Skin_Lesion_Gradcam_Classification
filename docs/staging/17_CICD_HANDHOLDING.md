# CI/CD Handholding Guide

Use this after the backend tests and a manual EKS deployment work. This guide explains the workflow layout that exists now and the two setup tasks a human still needs to complete.

## Current Project Implementation

The parent repository does not contain the backend source in its Git history. `Skin_Lesion_Classification_backend/` is ignored here and is its own GitHub repository:

```text
saiyudhaplhaomega/Skin_Lesion_Classification_backend
```

The old parent-repository deployment workflows checked out this parent repository and then tried to run `docker build` from `Skin_Lesion_Classification_backend/`. On a fresh GitHub Actions checkout that directory has no backend source, so those workflows could never build or deploy the application.

The parent workflow files are now disabled `workflow_dispatch` stubs. They point to the real location so the broken checkout pattern is not added again.

```text
Parent repository
  .github/workflows/docs-terraform-ci.yml     -> documentation and Terraform checks
  .github/workflows/staging-deploy.yml        -> disabled pointer only
  .github/workflows/production-deploy.yml     -> disabled pointer only

Backend repository
  .github/workflows/backend-ci.yml            -> backend tests, lint, and type checks
  .github/workflows/staging-deploy.yml        -> real staging deployment
  .github/workflows/production-deploy.yml     -> real production deployment
```

Why: a GitHub Actions job can only build source that its repository checkout actually contains. Backend deployment automation belongs with the backend source repository.

## Goal

Automate the backend release path only after local checks and a manual EKS rollout are understood:

```text
backend tests pass -> authenticate with OIDC -> build and push image -> deploy image digest -> watch rollout -> undo on failure
```

The deployment workflows wait for the existing backend CI job to pass first. They build and push the image, deploy the resulting image by digest instead of a mutable tag, and run `kubectl rollout undo` automatically if the rollout fails.

Why: a digest identifies exactly one image. A tag such as `latest` can point to a different image later, which makes a rollback or incident investigation less clear.

## Command Location

Start from the parent workspace when you need to inspect docs or Terraform:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

For backend workflow files and backend checks, move into the separate backend repository:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
```

Terraform commands run from:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
```

Why: each GitHub repository has its own checkout in Actions. Keeping the command location explicit prevents the old parent-repository build mistake.

## What GitHub Actions Does Here

A workflow is a YAML file in a repository's `.github/workflows/` directory. It defines a trigger, a runner, and a sequence of steps. In this project:

- `backend-ci.yml` checks the backend code before a release can proceed.
- `staging-deploy.yml` in the backend repository performs the staging image build and EKS rollout.
- `production-deploy.yml` in the backend repository performs the production rollout and uses the GitHub `production` Environment as the approval gate.
- `docs-terraform-ci.yml` remains in the parent repository because its work is limited to parent-repository docs and Terraform configuration.

Do not create another backend deployment workflow in this parent repository.

## Authentication: GitHub OIDC Instead Of Static Keys

The backend deployment workflows authenticate to AWS through GitHub OpenID Connect, or OIDC. GitHub issues a short-lived token for the running workflow. AWS accepts it only when the token matches the trusted backend repository and then allows it to assume the Terraform-created deploy role.

Do not store `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY` as backend repository secrets for these deployments. The only AWS secret the backend repository needs is:

```text
AWS_DEPLOY_ROLE_ARN
```

The value comes from Terraform after staging has been applied. The OIDC provider is global to the AWS account and Terraform creates it only when staging is applied. Apply staging first, then run this command from `infra/terraform`:

```powershell
terraform init -backend-config=env/backend-staging.hcl -reconfigure
terraform output github_actions_deploy_role_arn
```

Expected result: Terraform prints an IAM role ARN for the staging deployment role.

Why: OIDC avoids leaving a long-lived AWS access key in GitHub. The role is limited to the configured backend repository and environment.

## Human Setup Step 1: Add The Deploy Role Secret

In GitHub, open the separate backend repository, not this parent repository:

```text
saiyudhaplhaomega/Skin_Lesion_Classification_backend
```

1. Open `Settings`.
2. Open `Secrets and variables`, then `Actions`.
3. Select `New repository secret`.
4. Set the name to exactly `AWS_DEPLOY_ROLE_ARN`.
5. Paste the value from `terraform output github_actions_deploy_role_arn`.
6. Save the secret.

Check: open the backend repository's Actions secrets page. `AWS_DEPLOY_ROLE_ARN` should appear by name, with its value hidden.

Expected result: the backend deployment workflows can request the AWS role through OIDC without static AWS credentials.

Why: the role ARN tells the workflow which short-lived AWS identity to assume. It is not an access key.

## Human Setup Step 2: Create The Production Approval Gate

In the same backend GitHub repository:

1. Open `Settings`.
2. Open `Environments`.
3. Create an environment named exactly `production`.
4. Enable required reviewers and choose the people who must approve a production deployment.
5. Save the protection rule.

Check: the Environments page shows `production` and shows that required reviewers are enabled.

Expected result: the production workflow pauses before its protected deployment step until an approved reviewer allows it to continue.

Why: production delivery needs a human decision even when staging deployment is automated.

## Backend CI Gate

Before relying on a deployment workflow, run the backend checks locally from the backend repository:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
pytest
```

Expected result: the backend tests pass. The current deployment workflows require the existing `backend-ci.yml` job to pass before they deploy.

Why: CI should fail on a real code regression, not because a command was never proven locally.

## What A Deployment Workflow Does

The real backend-repository staging and production workflows follow this order:

```text
checkout backend source
wait for backend CI success
authenticate to AWS with GitHub OIDC and AWS_DEPLOY_ROLE_ARN
build the backend image
push the image to ECR
deploy the image digest to the target Kubernetes Deployment
wait for rollout status
run kubectl rollout undo if the rollout fails
```

For production, GitHub's `production` Environment adds the required-reviewer stop before the protected deployment continues.

If a rollout fails, inspect the backend repository Actions log and then check the target cluster from a terminal that has cluster access:

```powershell
kubectl rollout status deployment/skin-lesion-backend -n skin-lesion-staging
kubectl get pods -n skin-lesion-staging
```

Expected result: a successful run completes its rollout. A failed rollout is automatically returned to the prior Kubernetes revision by the workflow.

Why: rollout status catches a deployment that started but never became ready. Automatic undo shortens the time the failed revision is active.

## Parent Repository Terraform And Docs Check

The parent repository still has a safe CI workflow for its own files. Run its local equivalent from the parent workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
terraform fmt -recursive -check
terraform init -backend=false -input=false
terraform validate
cd ..\..
.\scripts\docs-validate.ps1
```

Expected result: Terraform formatting and validation pass without reading AWS state, and the documentation check passes.

Why: the parent repository owns these files. Its CI deliberately does not attempt to build or deploy backend source it does not contain.

## Current Stop Point

Before a first AWS staging deploy, complete these items in order:

1. Apply the staging Terraform environment so the global GitHub OIDC provider and staging deploy role exist.
2. Copy the staging `github_actions_deploy_role_arn` output into the backend repository's `AWS_DEPLOY_ROLE_ARN` secret.
3. Create the `production` Environment with required reviewers in the backend repository.
4. Confirm the backend CI workflow passes in the backend repository.
5. Start the backend repository's staging workflow only after the staging cluster and manifests are ready.

Nothing in this guide applies Terraform or changes GitHub settings by itself. Those are deliberate human actions because they create real AWS and repository state.
