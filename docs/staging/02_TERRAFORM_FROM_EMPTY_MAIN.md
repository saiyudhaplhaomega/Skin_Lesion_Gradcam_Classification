# Terraform From Empty Main

This guide intentionally starts from an empty Terraform lesson.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root before changing into `infra/terraform` for the Terraform commands.

After `cd infra/terraform`, every Terraform command in this guide runs from:

```text
infra/terraform
```

**What this means:** Terraform commands look for `.tf` files, `.tfvars` files, and the `.terraform` state directory relative to where they are run. Always `cd infra/terraform` first.

## Why

If `main.tf` already creates many services, you cannot learn what each service does. You also get errors for resources you are not ready to understand.

The repo does not include `infra/terraform/main.tf` now. You will create it yourself.

```text
infra/terraform/main.tf
```

**What this means:** `main.tf` is the root Terraform configuration file. You create it yourself in this guide so you understand exactly what it contains from the start. Nothing is pre-populated.

## Goal

Build a minimal Terraform setup from scratch - provider only - to understand how Terraform validates and plans before applying infrastructure changes.

## Step 1: Check Terraform Is Installed

```powershell
terraform version
```

**What this does:** prints the installed Terraform version. If the command is not found, Terraform is not installed or not on the system PATH.

If this fails with this message, Terraform is not installed or not on `PATH`:

```text
terraform : The term 'terraform' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

On this Windows workspace, Chocolatey is available. Open PowerShell as Administrator and run:

```powershell
choco install terraform -y
```

**What this does:** installs the Terraform CLI into Chocolatey's system package location and puts `terraform` on `PATH`.

Expected result:

```text
Chocolatey installed 1/1 packages.
```

If you run Chocolatey from a non-Administrator terminal, it can download Terraform but fail before installing it:

```text
terraform not installed. An error occurred during installation:
Access to the path 'C:\ProgramData\chocolatey\lib\terraform' is denied.
```

**What this means:** the install did not complete. Close that terminal, reopen PowerShell with `Run as Administrator`, rerun `choco install terraform -y`, then open a normal repo terminal and check again:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
terraform version
```

Do not continue to `terraform init`, `terraform validate`, or `terraform plan` until `terraform version` works.

## Step 2: Create The Smallest `main.tf`

Create this file:

```text
infra/terraform/main.tf
```

**What this file is:** the root Terraform configuration. All resource definitions, provider declarations, and backend configuration live here (or in files Terraform loads from the same directory).

Paste:

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

**What this HCL does:**

- `terraform { required_version = ">= 1.5.0" }` - declares the minimum Terraform version required. Terraform fails if the installed version is older.
- `required_providers` - declares which provider plugins Terraform needs and where to download them from.
- `aws { source = "hashicorp/aws", version = "~> 5.0" }` - pins the AWS provider to any version in the 5.x range. The `~>` operator allows patch updates but not major version bumps.
- `provider "aws" { region = "us-east-1" }` - configures the AWS provider to operate in the `us-east-1` region. All resources created by this provider go into this region unless overridden.

Why: this only teaches Terraform and the AWS provider. It does not create cloud resources yet.

## Step 3: Run Local Checks

```powershell
cd infra/terraform
terraform fmt
terraform init
terraform validate
```

**What these commands do:**

- `cd infra/terraform` - moves to the Terraform directory where `main.tf` lives.
- `terraform fmt` - reformats all `.tf` files in the current directory according to Terraform's canonical style. Run this before committing to keep formatting consistent.
- `terraform init` - downloads the provider plugins listed in `required_providers`, initialises the backend, creates the local `.terraform/` directory, and creates `.terraform.lock.hcl`. Must be run once before other commands.
- `terraform validate` - checks the configuration for syntax errors and logical issues without connecting to AWS.

Expected:

```text
Success! The configuration is valid.
```

**What this result means:** Terraform parsed and validated the configuration successfully. No syntax errors, invalid block types, or missing required arguments.

After `terraform init`, keep this generated file:

```text
infra/terraform/.terraform.lock.hcl
```

**What this file is:** Terraform's provider dependency lock file. It records the exact AWS provider version and checksums selected during `terraform init`.

Check:

```powershell
Test-Path .terraform.lock.hcl
```

**What this does:** confirms the lock file exists in `infra/terraform/`.

Expected result:

```text
True
```

Commit this lock file with `main.tf`. Do not commit the `.terraform/` directory.

Why: `.terraform.lock.hcl` makes later Terraform runs use the same provider version. The `.terraform/` directory is a local plugin/cache directory and can be recreated by running `terraform init`.

## Step 4: Continue To The VPC Plan-Only Lesson

Your first real resource lesson is the VPC in:

```text
docs/staging/03_TERRAFORM_VPC_HANDHOLDING.md
```

**What this guide covers:** adds the VPC resource to `main.tf` and runs `terraform plan`. It does not apply yet.

That guide teaches the VPC plan only. Do not apply it until the remote-state bootstrap in `docs/staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md` is complete.

Do not create VPC, EKS, Aurora, SQS, and WAF in the same lesson.

## Rule

Every Terraform lesson should follow this pattern:

```text
Add one resource -> terraform fmt -> terraform validate -> terraform plan -> explain the plan -> stop before apply unless the guide explicitly says to apply
```

**What this pattern means:** the learning loop is: add one resource, check the syntax, validate the configuration, preview what Terraform will do, understand the output, then decide whether to apply. Applying before understanding the plan leads to unexpected resources being created.

## Check

Run from `infra/terraform/`:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** the same as Step 3. `terraform plan` here only shows the provider-level plan since no resources are defined yet. The output should be "No changes. Your infrastructure matches the configuration."

Expected result: provider-only plan succeeds with no errors.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of dev cloud resources.
- `make cloud-pause ENV=dev` scales pods to zero to reduce cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` creates or resumes the dev environment.
- `make cloud-status ENV=dev` confirms the environment is healthy.

If this guide was local-only, no cloud shutdown is needed.
