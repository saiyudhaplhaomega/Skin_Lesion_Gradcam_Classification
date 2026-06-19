# Terraform Storage, Secrets, And ECR Handholding Guide

Use this after `docs/staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md` completes successfully.

This guide integrates the ideas from the old `s3-training`, `s3-logging`, `secrets-manager`, `kms`, and ECR plan into a beginner build order.

## What This Guide Creates

This guide adds five categories of cloud foundation resources using Terraform:

```text
KMS key -> log bucket -> upload bucket + training bucket -> Secrets Manager placeholders -> ECR repository
```

**What this build order means:** KMS must come first because buckets and secrets reference it for encryption. The log bucket comes before app buckets so access logs have a destination before any traffic flows. Upload and training buckets come next because image storage is the core data path. Secrets Manager placeholders come before runtime clusters so credentials are ready when the first pod starts. ECR is last because the container registry is only needed once you are pushing images.

## Prerequisites

Before Step 1, confirm all of these are done:

1. Guide 02 created `infra/terraform/main.tf` with the provider block and `terraform init` works.
2. Guide 03 created the VPC and three subnets in `main.tf` and `terraform plan` shows 4 resources.
3. Guide 04 created the remote state S3 bucket and DynamoDB lock table.
4. Guide 04 created `infra/terraform/backend.tf` and `terraform init` connected to the S3 backend.
5. Guide 04 created `infra/terraform/env/dev.tfvars` with `environment`, `project_name`, and `aws_region`.

If any of these are missing, go back and complete the referenced guide first.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root before changing into `infra/terraform` for Terraform commands.

Terraform file paths in this guide are relative to:

```text
infra/terraform
```

**What this means:** when the guide shows a file path like `main.tf`, the full path is `infra/terraform/main.tf`. Always `cd infra/terraform` before running Terraform commands.

After `cd infra/terraform`, run every Terraform command from `infra/terraform`.

## Repo And File Map

Main workspace:

```text
C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

Every file this guide touches, in the order the steps touch it:

| Step | Action | Full file path | What goes in it |
|------|--------|---------------|-----------------|
| 0 | Create new file | `infra/terraform/variables.tf` | 5 `variable` blocks: `project_name`, `environment`, `aws_region`, `s3_unique_suffix`, `aws_account_id` |
| 0 | Edit existing file | `infra/terraform/env/dev.tfvars` | Add `s3_unique_suffix` and `aws_account_id` values to the existing `environment`, `project_name`, `aws_region` |
| 1 | No file edits — AWS Console only | (nothing) | Add 4 IAM inline policy statements to `SkinLesionVpcLearning` permission set in IAM Identity Center |
| 1.5 | No file edits — terminal only | (nothing) | Refresh SSO session |
| 2 | Edit existing file | `infra/terraform/main.tf` | Append `aws_kms_key.main` and `aws_kms_alias.main` resource blocks |
| 3 | Edit existing file | `infra/terraform/main.tf` | Append `aws_s3_bucket.logs`, `aws_s3_bucket_public_access_block.logs`, `aws_s3_bucket_server_side_encryption_configuration.logs` resource blocks |
| 4 | Edit existing file | `infra/terraform/main.tf` | Append upload bucket group (5 resources) and training bucket group (5 resources) |
| 5 | Edit existing file | `infra/terraform/main.tf` | Append `aws_secretsmanager_secret.db_password`, `aws_secretsmanager_secret.jwt_secret`, `aws_secretsmanager_secret.powerbi_client_secret` resource blocks |
| 6 | Edit existing file | `infra/terraform/main.tf` | Append `aws_ecr_repository.backend` resource block |
| 7 | Create new file | `infra/terraform/outputs.tf` | 8 `output` blocks: `kms_key_arn`, `kms_alias_name`, `upload_bucket_name`, `training_bucket_name`, `log_bucket_name`, `ecr_repository_url`, `db_password_secret_arn`, `jwt_secret_arn` |

Files this guide does **not** touch:

```text
infra/terraform/backend.tf     — created in guide 04, do not modify
infra/terraform/.terraform.lock.hcl — created in guide 02, do not modify
```

Do not create backend or frontend application files in this guide. This guide only creates Terraform configuration files.

## Account And Identity Map

Read this before Step 1. This guide uses the same accounts and identities from guides 03 and 04. There are only **two AWS accounts** and **three identities**.

### The Two Accounts

```text
1. Management account
   - This is your main AWS account (the one you signed up with).
   - The root user lives here.
   - saiyu-admin (your daily admin IAM user) lives here.
   - You set up AWS Organizations and IAM Identity Center from here.
   - You do NOT run Terraform here.

2. skin-lesion-learning-dev
   - This is a separate member account created for disposable learning.
   - This is where Terraform runs.
   - You never use root in this account.
```

### The Three Identities

```text
root user
    In: Management account.
    Used: Never again after guide 03 setup. Not used in this guide.

saiyu-admin  (IAM user)
    In: Management account.
    Used: For updating the permission set in Step 1.
    Has AdministratorAccess.

saiyu  (IAM Identity Center / SSO user)
    In: Management account (Identity Center directory), accesses learning-dev via SSO.
    Used: Your daily human login for the SSO portal and CLI.
    This is the identity Terraform uses.
```

### How To Follow This Guide

Every step starts with one of these markers:

```text
ENTER: <account name> as <identity>
```

And ends with one of these when you leave that account:

```text
EXIT: <account name>
```

If a step does not have an ENTER marker, you stay in the same account from the previous step.

## Dev Parameters Used In This Guide

This guide uses five Terraform variables. Three were already set in guide 04. Two are new in this guide and are saved in Step 0.

These are **not** shell environment variables. They are Terraform variables stored in two files:

- `infra/terraform/variables.tf` — declares the variable name, type, and default (created in Step 0)
- `infra/terraform/env/dev.tfvars` — provides the concrete value for dev (updated in Step 0)

Terraform reads the `.tfvars` file automatically when you run `terraform plan -var-file="env/dev.tfvars"`. You never type these into the terminal.

### The Five Variables

| Terraform variable | Value for dev | First set in | Where it lives | What it does |
|----|----|----|----|----|
| `project_name` | `skin-lesion` | Guide 04 | `env/dev.tfvars` line 5, `variables.tf` Step 0 | Prefix for resource names to avoid collisions with other projects in the same AWS account. Referenced as `var.project_name` in HCL. |
| `environment` | `dev` | Guide 04 | `env/dev.tfvars` line 4, `variables.tf` Step 0 | Environment label in resource names and tags. Referenced as `var.environment` in HCL. |
| `aws_region` | `us-east-1` | Guide 04 | `env/dev.tfvars` line 6, `variables.tf` Step 0 | AWS region where all resources are created. Referenced as `var.aws_region` in HCL. |
| `s3_unique_suffix` | `version1a-0` | **This guide (Step 0)** | `env/dev.tfvars` Step 0, `variables.tf` Step 0 | Globally unique suffix for S3 bucket names. Derived from guide 04's `version1a.0` with the dot replaced by a hyphen. Referenced as `var.s3_unique_suffix` in HCL. |
| `aws_account_id` | `YOUR_ACCOUNT_ID` | **This guide (Step 0)** | `env/dev.tfvars` Step 0, `variables.tf` Step 0 | Your 12-digit AWS account number for `skin-lesion-learning-dev`. Used in IAM policy ARNs in Step 1. Replace `YOUR_ACCOUNT_ID` with your actual account ID. |

**How to find your `aws_account_id`:** run this command before Step 0:

```powershell
aws sts get-caller-identity --query "Account" --output text --profile skin-lesion-learning-dev
```

**What this does:** prints just the 12-digit account number, with no JSON wrapper. Write this number down. You will paste it into `env/dev.tfvars` in Step 0 and into the IAM policy JSON in Step 1.

### Where Each Value Is Saved

The five values above are not saved yet. Step 0 is where you write them into files. Here is the exact state before and after Step 0:

**Before Step 0 — `infra/terraform/env/dev.tfvars` (from guide 04):**

```hcl
environment  = "dev"
project_name = "skin-lesion"
aws_region   = "us-east-1"
```

**After Step 0 — `infra/terraform/env/dev.tfvars` (updated in this guide):**

```hcl
environment      = "dev"
project_name     = "skin-lesion"
aws_region       = "us-east-1"
s3_unique_suffix = "version1a-0"
aws_account_id   = "YOUR_ACCOUNT_ID"
```

**Before Step 0 — `infra/terraform/variables.tf`:** does not exist.

**After Step 0 — `infra/terraform/variables.tf` (created in this guide):** contains 5 `variable` blocks that tell Terraform how to receive the values from `dev.tfvars`. See Step 0 for the full content.

### Bucket Names Built From These Variables

Every S3 bucket name in this guide is built from three variables: `skin-lesion` (project name) + `dev` (environment) + `version1a-0` (suffix). The HCL uses string interpolation:

```hcl
bucket = "skin-lesion-logs-${var.environment}-${var.s3_unique_suffix}"
```

At plan time Terraform substitutes the values from `dev.tfvars` and the bucket name becomes:

```text
skin-lesion-logs-dev-version1a-0
```

All three buckets in this guide:

| Bucket | HCL interpolation | Resolved name at plan time |
|--------|-----------------|--------------------------|
| Log bucket | `skin-lesion-logs-${var.environment}-${var.s3_unique_suffix}` | `skin-lesion-logs-dev-version1a-0` |
| Upload bucket | `skin-lesion-upload-${var.environment}-${var.s3_unique_suffix}` | `skin-lesion-upload-dev-version1a-0` |
| Training bucket | `skin-lesion-training-${var.environment}-${var.s3_unique_suffix}` | `skin-lesion-training-dev-version1a-0` |

### Why The Suffix Uses A Hyphen Not A Dot

Guide 04 introduced the suffix `version1a.0` (lowercased from your original `version1A.0`). The state bucket name in guide 04 was `skin-lesion-tf-state-dev-version1a-0-526404916929` — the dot was already replaced with a hyphen there.

This guide uses `version1a-0` (hyphen) consistently because S3 bucket names with dots cause TLS certificate validation problems when the bucket is accessed via a virtual-hosted-style URL. Hyphens are the safest separator for S3 bucket names.

### KMS Alias Built From These Variables

The KMS alias uses `var.environment`:

```hcl
name = "alias/skin-lesion-${var.environment}"
```

At plan time this becomes:

```text
alias/skin-lesion-dev
```

### ECR Repository Name Built From These Variables

The ECR repository name uses `var.environment`:

```hcl
name = "skin-lesion-backend-${var.environment}"
```

At plan time this becomes:

```text
skin-lesion-backend-dev
```

## Step 0: Create variables.tf

Before adding any resources that use `var.environment` or `var.project_name`, Terraform needs `variable` blocks to receive those values. Guide 04 added `environment` and `project_name` to `env/dev.tfvars` but never created the `variable` blocks that declare them. This step fixes that.

```text
ENTER: Local terminal as saiyu (SSO user)
```

Open a PowerShell terminal. If you closed the terminal from guide 04, set the AWS profile first:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
$env:AWS_PROFILE = "skin-lesion-learning-dev"
$env:AWS_REGION = "us-east-1"
aws sts get-caller-identity
```

**What this does:** reuses the SSO profile from guides 03 and 04. The `get-caller-identity` command confirms the terminal is using the learning-dev SSO role, not a plain IAM user.

Expected result:

```text
Account, Arn, and UserId print for the skin-lesion-learning-dev account.
```

The `Arn` should look like an SSO role:

```text
arn:aws:sts::<account-id>:assumed-role/AWSReservedSSO_...
```

If the command says the SSO session expired, refresh it:

```powershell
aws sso login --profile skin-lesion-learning-dev
```

Then rerun `aws sts get-caller-identity`.

Create this file:

```text
infra/terraform/variables.tf
```

**What this file is:** the Terraform variable declarations. Each `variable` block tells Terraform "this configuration accepts an input with this name and this type." The actual values come from `env/dev.tfvars` at plan time.

**How to create this file in VS Code:**

1. Open VS Code.
2. If the workspace is not already open, click `File` > `Open Folder` and select:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
   ```
3. In the VS Code Explorer panel on the left, expand these folders in order:
   ```text
   Skin_Lesion_GRADCAM_Classification
     infra
       terraform
   ```
4. Click on the `terraform` folder to highlight it.
5. Right-click the `terraform` folder.
6. Click `New File...`.
7. Type exactly:
   ```text
   variables.tf
   ```
8. Press `Enter`. VS Code creates the file and opens it in the editor tab. The file is empty.
9. Copy the HCL block below and paste it into the `variables.tf` editor tab.
10. Press `Ctrl+S` to save the file.

**How to create this file in a plain text editor (Notepad):**

1. Open Notepad.
2. Copy the HCL block below and paste it into Notepad.
3. Click `File` > `Save As`.
4. Navigate to:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
   ```
5. In the `Save as type` dropdown, choose `All Files (*.*)` — if you leave it as `Text Documents (*.txt)`, Windows will append `.txt` and Terraform will not find the file.
6. In the `File name` field, type exactly:
   ```text
   variables.tf
   ```
7. Click `Save`.

**What to paste into the file:**

```hcl
variable "project_name" {
  description = "Project name used as a prefix for resource names"
  type        = string
  default     = "skin-lesion"
}

variable "environment" {
  description = "Environment label (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "s3_unique_suffix" {
  description = "Globally unique suffix for S3 bucket names (from guide 04)"
  type        = string
  default     = "version1a-0"
}

variable "aws_account_id" {
  description = "12-digit AWS account ID for learning-dev"
  type        = string
  default     = "YOUR_ACCOUNT_ID"
}
```

Press `Ctrl+S` to save `variables.tf`.

**What each variable block does:**

- `variable "project_name"` - declares a string input called `project_name`. Other resources reference it as `var.project_name`. The `default` means Terraform uses `skin-lesion` even if `.tfvars` does not provide it.
- `variable "environment"` - declares a string input called `environment`. Other resources reference it as `var.environment`. The `default` is `dev`.
- `variable "aws_region"` - declares a string input called `aws_region`. Used for region-specific resource naming. The `default` is `us-east-1`.
- `variable "s3_unique_suffix"` - declares a string input for the S3 bucket suffix. The value `version1a-0` comes from guide 04, with the dot replaced by a hyphen for S3 naming safety.
- `variable "aws_account_id"` - declares a string input for your 12-digit AWS account ID. Replace `YOUR_ACCOUNT_ID` with your actual account ID in `env/dev.tfvars` (Step 0.5 below).

Now update `env/dev.tfvars` to include the new variables.

Open this file:

```text
infra/terraform/env/dev.tfvars
```

**How to open this file in VS Code:**

1. In the VS Code Explorer panel on the left, expand the `terraform` folder if it is not already expanded.
2. Expand the `env` folder inside `terraform`.
3. Click on `dev.tfvars`. The file opens in the editor tab.
4. The file currently contains 9 lines from guide 04:
   ```hcl
   # Dev environment variables for Terraform learning.
   # Keep this low-cost and disposable.

   environment  = "dev"
   project_name = "skin-lesion"
   aws_region   = "us-east-1"

   # Add guide-specific variables here only when the matching handholding guide
   # introduces them. Do not paste secrets into this file.
   ```
5. Select all the text in the file by pressing `Ctrl+A`.
6. Delete the selected text by pressing `Delete`.
7. Copy the HCL block below and paste it into the `dev.tfvars` editor tab.
8. **Before saving**, find the line that says `aws_account_id = "YOUR_ACCOUNT_ID"`. Replace `YOUR_ACCOUNT_ID` with the 12-digit account ID you wrote down from the `aws sts get-caller-identity` command earlier.
9. Press `Ctrl+S` to save the file.

**How to open this file in a plain text editor (Notepad):**

1. Open Notepad.
2. Click `File` > `Open`.
3. Navigate to:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform\env
   ```
4. In the `File name` field, type `dev.tfvars` and press `Enter`.
5. Select all text with `Ctrl+A`, delete it, then paste the HCL block below.
6. Replace `YOUR_ACCOUNT_ID` with your 12-digit account ID.
7. Click `File` > `Save`.

Replace the entire contents with:

```hcl
# Dev environment variables for Terraform learning.
# Keep this low-cost and disposable.

environment      = "dev"
project_name     = "skin-lesion"
aws_region       = "us-east-1"
s3_unique_suffix = "version1a-0"
aws_account_id   = "YOUR_ACCOUNT_ID"

# Add guide-specific variables here only when the matching handholding guide
# introduces them. Do not paste secrets into this file.
```

**What this does:** provides concrete values for every variable declared in `variables.tf`. Terraform reads this file automatically when you run `terraform plan -var-file="env/dev.tfvars"` (or when the file is named `*.auto.tfvars`, but this guide uses explicit `-var-file` for clarity).

**Replace `YOUR_ACCOUNT_ID`** with the 12-digit account ID for `skin-lesion-learning-dev`. You can find it by running:

```powershell
aws sts get-caller-identity --query "Account" --output text --profile skin-lesion-learning-dev
```

**What this does:** prints just the 12-digit account number, with no JSON wrapper.

Check from `infra/terraform`:

```powershell
cd infra/terraform
terraform fmt
terraform validate
```

**What these commands do:**

- `cd infra/terraform` - moves to the Terraform directory.
- `terraform fmt` - formats all `.tf` files including the new `variables.tf`.
- `terraform validate` - confirms the variable declarations are syntactically valid and that `main.tf` can now resolve `var.project_name` and `var.environment` without errors.

Expected result:

```text
Success! The configuration is valid.
```

If you see this error:

```text
Error: Reference to undeclared input variable
```

**What this means:** a resource in `main.tf` references a variable that is not declared in `variables.tf`. Check that the variable name in the error message matches one of the `variable` blocks you just created.

```text
EXIT: Local terminal (temporarily — you will return for Step 2 onward)
```

## Step 1: Add KMS, S3, Secrets, And ECR Permissions To The Permission Set

```text
ENTER: Management account as saiyu-admin
```

The `SkinLesionVpcLearning` permission set from guide 03 only allows EC2 and STS actions. Guide 04 added S3 state-bucket and DynamoDB lock-table permissions (including `PutItem`, `GetItem`, and `DeleteItem` for state locking). This guide needs KMS, S3 (for app buckets), Secrets Manager, and ECR permissions. Without these, `terraform plan` and `terraform apply` will fail with `AccessDenied`.

1. Sign in to the AWS Console for the **Management account** as `saiyu-admin`.
2. In the search bar at the top, type:

```text
IAM Identity Center
```

3. Click `IAM Identity Center` in the results.
4. In the left sidebar, click `Permission sets`.
5. Find and click:

```text
SkinLesionVpcLearning
```

6. Click the `Inline policy` tab.
7. Click `Edit` on the policy JSON.
8. Keep all existing statements from guides 03 and 04 (STS, EC2, S3 state bucket, DynamoDB lock table).
9. Add these four new statements inside the top-level `Statement` array, after the existing statements:

```json
{
  "Sid": "AllowKmsLearning",
  "Effect": "Allow",
  "Action": [
    "kms:CreateKey",
    "kms:CreateAlias",
    "kms:DeleteAlias",
    "kms:DescribeKey",
    "kms:EnableKeyRotation",
    "kms:GetKeyPolicy",
    "kms:PutKeyPolicy",
    "kms:ScheduleKeyDeletion",
    "kms:ListAliases",
    "kms:ListResourceTags",
    "kms:TagResource",
    "kms:UntagResource"
  ],
  "Resource": "*"
},
{
  "Sid": "AllowS3AppBucketsLearning",
  "Effect": "Allow",
  "Action": [
    "s3:CreateBucket",
    "s3:DeleteBucket",
    "s3:GetBucketLocation",
    "s3:GetBucketVersioning",
    "s3:PutBucketVersioning",
    "s3:GetBucketPublicAccessBlock",
    "s3:PutBucketPublicAccessBlock",
    "s3:GetEncryptionConfiguration",
    "s3:PutEncryptionConfiguration",
    "s3:GetLifecycleConfiguration",
    "s3:PutLifecycleConfiguration",
    "s3:GetBucketTagging",
    "s3:PutBucketTagging",
    "s3:ListBucket",
    "s3:ListBucketVersions",
    "s3:DeleteObject",
    "s3:DeleteObjectVersion"
  ],
  "Resource": [
    "arn:aws:s3:::skin-lesion-upload-dev-*",
    "arn:aws:s3:::skin-lesion-training-dev-*",
    "arn:aws:s3:::skin-lesion-logs-dev-*",
    "arn:aws:s3:::skin-lesion-upload-dev-*/*",
    "arn:aws:s3:::skin-lesion-training-dev-*/*",
    "arn:aws:s3:::skin-lesion-logs-dev-*/*"
  ]
},
{
  "Sid": "AllowSecretsManagerLearning",
  "Effect": "Allow",
  "Action": [
    "secretsmanager:CreateSecret",
    "secretsmanager:DeleteSecret",
    "secretsmanager:DescribeSecret",
    "secretsmanager:GetSecretValue",
    "secretsmanager:PutSecretValue",
    "secretsmanager:ListSecrets",
    "secretsmanager:TagResource",
    "secretsmanager:UntagResource",
    "secretsmanager:RotateSecret",
    "secretsmanager:UpdateSecret"
  ],
  "Resource": "arn:aws:secretsmanager:us-east-1:526404916929:secret:skin-lesion/dev/*"
},
{
  "Sid": "AllowECRLearning",
  "Effect": "Allow",
  "Action": [
    "ecr:CreateRepository",
    "ecr:DeleteRepository",
    "ecr:DescribeRepositories",
    "ecr:DescribeImages",
    "ecr:GetRepositoryPolicy",
    "ecr:SetRepositoryPolicy",
    "ecr:PutImageScanningConfiguration",
    "ecr:PutImageTagMutability",
    "ecr:ListImages",
    "ecr:BatchGetImage",
    "ecr:BatchCheckLayerAvailability",
    "ecr:GetDownloadUrlForLayer",
    "ecr:GetAuthorizationToken",
    "ecr:InitiateLayerUpload",
    "ecr:UploadLayerPart",
    "ecr:CompleteLayerUpload",
    "ecr:PutImage"
  ],
  "Resource": "arn:aws:ecr:us-east-1:526404916929:repository/skin-lesion-backend-dev"
}
```

**What each statement does:**

- `AllowKmsLearning` - lets Terraform create and manage a KMS key and alias. `Resource: "*"` is required because KMS keys do not have ARNs until they are created.
- `AllowS3AppBucketsLearning` - lets Terraform create and manage the upload, training, and log buckets. The resource pattern `skin-lesion-*-dev-*` scopes access to only this project's dev buckets.
- `AllowSecretsManagerLearning` - lets Terraform create and manage secret placeholders under the `skin-lesion/dev/` path. The trailing `/*` matches any secret name under that prefix.
- `AllowECRLearning` - lets Terraform create and manage the ECR repository and lets you push images to it later. `ecr:GetAuthorizationToken` and the push actions are included so you can push images from the same SSO session in later guides.

10. Click `Save changes` (or `Save`).
11. If IAM Identity Center shows a prompt to `Provision permission set` or `Reprovision`, click it.
12. Wait for the provisioning to show `Succeeded`.
13. Confirm the permission set is still provisioned to the `skin-lesion-learning-dev` account:
    - In the left sidebar, click `AWS accounts`.
    - Find `skin-lesion-learning-dev`.
    - Click it to see its assignments.
    - Confirm `SkinLesionTerraformLearners` with `SkinLesionVpcLearning` is still listed.

Expected result:

```text
SkinLesionVpcLearning now includes the original STS, EC2, S3 state-bucket, DynamoDB, KMS, S3 app-bucket, Secrets Manager, and ECR permissions.
```

Why: Step 2 onward uses Terraform to create KMS, S3, Secrets Manager, and ECR resources. The learning identity must be allowed to create, describe, and eventually delete each of these resource types.

```text
EXIT: Management account
```

## Step 1.5: Refresh Your Local SSO Session

```text
ENTER: Local terminal as saiyu (SSO user)
```

The updated permission set needs a fresh SSO session to take effect in the CLI.

Open a PowerShell terminal and run:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
aws sso logout --profile skin-lesion-learning-dev
aws sso login --profile skin-lesion-learning-dev
$env:AWS_PROFILE = "skin-lesion-learning-dev"
$env:AWS_REGION = "us-east-1"
aws sts get-caller-identity
```

**What this does:**

- `aws sso logout` - clears the old cached SSO session so the new permissions are loaded.
- `aws sso login` - starts a new browser-based SSO login that picks up the updated permission set.
- `$env:AWS_PROFILE` - sets the profile for this terminal session.
- `aws sts get-caller-identity` - confirms the new session is active.

Expected result:

```text
Account, Arn, and UserId print for the skin-lesion-learning-dev account.
```

If KMS or Secrets Manager still returns `AccessDeniedException` after this refresh, go back to the Management account, open the `SkinLesionVpcLearning` permission set, and verify the new statements were saved and provisioned. IAM Identity Center permission updates can take up to one minute to propagate.

## Step 2: KMS Key

Change to the Terraform directory:

```powershell
cd infra/terraform
```

Open this file:

```text
infra/terraform/main.tf
```

**How to open this file in VS Code:**

1. In the VS Code Explorer panel on the left, expand the `terraform` folder.
2. Click on `main.tf`. The file opens in the editor tab.
3. The file currently has 55 lines: the provider block from guide 02 (lines 1-14) and the VPC plus 3 subnets from guide 03 (lines 16-55).
4. Scroll to the bottom of the file. The last lines should look like this:
   ```hcl
   resource "aws_subnet" "private_data_a" {
     vpc_id            = aws_vpc.main.id
     cidr_block        = "10.0.21.0/24"
     availability_zone = "us-east-1a"

     tags = {
       Name = "skin-lesion-learning-dev-private-data-a"
     }
   }
   ```
5. Click your cursor on the empty line after the last `}` (line 56, or wherever the file ends). This is where you will paste the new KMS resource blocks.
6. Press `Enter` once to create a blank line between the existing code and the new code.

**What this file is:** the main Terraform configuration. It already contains the provider block from guide 02 and the VPC plus three subnets from guide 03. You will append new resource blocks to the bottom of this file.

Scroll to the bottom of `main.tf`. After the last `}` that closes the `private_data_a` subnet block, paste the KMS resources:

```hcl
# --- Guide 05: KMS Key ---

resource "aws_kms_key" "main" {
  description = "KMS key for skin lesion ${var.environment}"

  enable_key_rotation = true

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_kms_alias" "main" {
  name          = "alias/skin-lesion-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}
```

Press `Ctrl+S` to save `main.tf`.

**What this HCL does:**

- `resource "aws_kms_key" "main"` - creates an AWS Key Management Service (KMS) symmetric encryption key. This key encrypts S3 objects, database storage, and secrets.
- `description = "KMS key for skin lesion ${var.environment}"` - a human-readable label shown in the AWS KMS console. `${var.environment}` inserts `dev` at plan time, so the description reads "KMS key for skin lesion dev".
- `enable_key_rotation = true` - enables automatic annual key rotation. AWS rotates the key material once per year without changing the key ID or ARN. This is a security best practice and costs nothing extra.
- `tags` - attaches `Project` and `Environment` tags so cost allocation reports can filter by project and environment.
- `resource "aws_kms_alias" "main"` - creates a friendly name for the key. Using an alias instead of the full key ARN in other resources means you can rotate the key later without updating every resource that references it.
- `name = "alias/skin-lesion-${var.environment}"` - the alias name. At plan time this becomes `alias/skin-lesion-dev`. The `alias/` prefix is required by AWS.
- `target_key_id = aws_kms_key.main.key_id` - links the alias to the key just created. Terraform resolves this reference automatically.

Why: add one encryption key before encrypted buckets and database resources need it. KMS is the root of the encryption hierarchy — buckets, secrets, and databases all reference this key.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

**What these commands do:**

- `terraform fmt` - formats the new KMS blocks.
- `terraform validate` - confirms the variable references resolve and the KMS resource syntax is correct.
- `terraform plan -var-file="env/dev.tfvars"` - previews what Terraform will create, using the dev parameter values.

Expected result:

```text
Terraform plans one KMS key and one KMS alias.

Plan: 6 to add, 0 to change, 0 to destroy.
```

**What the number 6 means:** the 4 resources from guide 03 (VPC + 3 subnets) plus the 2 new resources from this step (KMS key + KMS alias). If you already applied the VPC in a previous guide, the count may be 2 to add instead.

If you see this error:

```text
Error: AccessDeniedException: User is not authorized to perform: kms:CreateKey
```

**What this means:** the SSO session still has the old permissions. Go back to Step 1.5 and refresh the SSO session.

If you see this error:

```text
Error: Reference to undeclared input variable
```

**What this means:** `variables.tf` is missing the `variable "environment"` or `variable "project_name"` block. Go back to Step 0.

## Step 3: Log Bucket

You are still in `infra/terraform/main.tf` from Step 2. Do not close the file.

Scroll to the bottom of `main.tf`. You should see the last block you pasted in Step 2:

```hcl
resource "aws_kms_alias" "main" {
  name          = "alias/skin-lesion-${var.environment}"
  target_key_id = aws_kms_key.main.key_id
}
```

Click your cursor on the empty line after the last `}` of the KMS alias block. Press `Enter` to create a blank line. Paste the log bucket resources below:

```hcl
# --- Guide 05: Log Bucket ---

resource "aws_s3_bucket" "logs" {
  bucket = "skin-lesion-logs-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "logs"
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
```

Press `Ctrl+S` to save `main.tf`.

**What each resource does:**

- `aws_s3_bucket "logs"` - creates the log storage bucket. The name `skin-lesion-logs-dev-version1a-0` is built from `var.project_name`, `var.environment`, and `var.s3_unique_suffix`. All S3 access logs, CloudTrail events, and ALB logs go here.
- `aws_s3_bucket_public_access_block "logs"` - locks down the bucket so it can never become publicly accessible, even if a misconfigured bucket policy tries to allow it. All four block settings must be `true`:
  - `block_public_acls` - rejects any public ACL placed on the bucket or its objects.
  - `block_public_policy` - rejects any bucket policy that grants public access.
  - `ignore_public_acls` - ignores any public ACL that might have been set by another tool.
  - `restrict_public_buckets` - blocks public access to buckets that have public ACLs or policies from a different account.
- `aws_s3_bucket_server_side_encryption_configuration "logs"` - enables KMS encryption for every object written to the bucket. `kms_master_key_id = aws_kms_key.main.arn` uses the key created in Step 2. `sse_algorithm = "aws:kms"` tells S3 to use KMS for encryption, not the default S3-managed key.

Why: the log bucket is created before app buckets so it has a home before any traffic flows. Logs are encrypted with the same KMS key as the app data.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform plans the KMS key, KMS alias, log bucket, log public access block, and log encryption config.

Plan: 9 to add, 0 to change, 0 to destroy.
```

**What the number 9 means:** 4 (VPC + subnets) + 2 (KMS) + 3 (log bucket + access block + encryption config). Adjust if the VPC was already applied.

## Step 4: Upload And Training Buckets

You are still in `infra/terraform/main.tf` from Step 3. Do not close the file.

Scroll to the bottom of `main.tf`. You should see the last block you pasted in Step 3:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}
```

Click your cursor on the empty line after the last `}` of the log encryption config block. Press `Enter` to create a blank line. Paste the upload bucket resources below first, then the training bucket resources after that.

```hcl
# --- Guide 05: Upload Bucket ---

resource "aws_s3_bucket" "uploads" {
  bucket = "skin-lesion-upload-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "uploads"
  }
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

**What each resource does:**

- `aws_s3_bucket "uploads"` - creates the bucket where patients upload skin lesion images. The name is `skin-lesion-upload-dev-version1a-0`.
- `aws_s3_bucket_public_access_block "uploads"` - same four-block lockdown as the log bucket. No S3 bucket holding patient images should ever be public.
- `aws_s3_bucket_versioning "uploads"` - keeps every version of every uploaded object. If a patient replaces their image, the old version is retained. Required for data integrity in healthcare contexts.
- `aws_s3_bucket_server_side_encryption_configuration "uploads"` - encrypts all uploaded patient images at rest using the KMS key from Step 2.
- `aws_s3_bucket_lifecycle_configuration "uploads"` - cancels multipart uploads that were started but never completed after 7 days. Without this, partial uploads accumulate in S3 and incur storage charges for data that was never usable. The `filter {}` block with no arguments means "apply this rule to all objects in the bucket." The AWS provider requires either `filter` or `prefix` inside every rule block — without it, the provider issues a warning and will error in future versions.

Now scroll down past the upload bucket lifecycle block you just pasted. The last block should be:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

Click your cursor on the empty line after the last `}`. Press `Enter` to create a blank line. Paste the training bucket resources:

```hcl
# --- Guide 05: Training Bucket ---

resource "aws_s3_bucket" "training" {
  bucket = "skin-lesion-training-${var.environment}-${var.s3_unique_suffix}"

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "training"
  }
}

resource "aws_s3_bucket_public_access_block" "training" {
  bucket = aws_s3_bucket.training.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "training" {
  bucket = aws_s3_bucket.training.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.main.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

**What each resource does:**

- `aws_s3_bucket "training"` - creates the bucket for de-identified, approved training images. The name is `skin-lesion-training-dev-version1a-0`. This is different from the upload bucket because training data goes through the doctor and admin approval workflow first.
- `aws_s3_bucket_public_access_block "training"` - same lockdown as all other buckets.
- `aws_s3_bucket_versioning "training"` - keeps every version of every training image. If an approved image is accidentally overwritten, the previous version can be recovered. This is critical for reproducible ML training runs.
- `aws_s3_bucket_server_side_encryption_configuration "training"` - encrypts all training images at rest using the KMS key.
- `aws_s3_bucket_lifecycle_configuration "training"` - same incomplete-upload cleanup as the upload bucket.

Press `Ctrl+S` to save `main.tf`.

**Training bucket prefix structure:**

The training bucket uses prefixes (folder-like paths) to represent the approval workflow stages. You do not create these prefixes in Terraform — S3 creates them automatically when the first object is placed under each path. They are documented here so later guides know where to write:

```text
pending_review/    - images waiting for doctor review
pending_admin/     - images the doctor approved, waiting for admin approval
approved/          - images fully approved for training
rejected/          - images rejected by doctor or admin
```

**What these prefixes mean:** images start in `pending_review/` after doctor validation, move to `pending_admin/` after the doctor approves, then land in `approved/` after admin approval. Training code reads only from `approved/`.

Do not enable MFA delete in Terraform for the first learning version. MFA delete has account-root-user operational constraints and can block beginner workflows.

Why: two separate buckets separate patient uploads from approved training data. The upload bucket is the front door for raw images. The training bucket is the clean dataset for ML training. Mixing them risks training on unreviewed data.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform plans KMS, log bucket, upload bucket with versioning/encryption/lifecycle, and training bucket with versioning/encryption/lifecycle.

Plan: 19 to add, 0 to change, 0 to destroy.
```

**What the number 19 means:** 4 (VPC + subnets) + 2 (KMS) + 3 (log bucket group) + 5 (upload bucket group) + 5 (training bucket group). Adjust if the VPC was already applied.

## Step 5: Secrets Manager Placeholders

You are still in `infra/terraform/main.tf` from Step 4. Do not close the file.

Scroll to the bottom of `main.tf`. You should see the last block you pasted in Step 4:

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "training" {
  bucket = aws_s3_bucket.training.id

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
```

Click your cursor on the empty line after the last `}` of the training lifecycle block. Press `Enter` to create a blank line. Paste the Secrets Manager resources:

```hcl
# --- Guide 05: Secrets Manager Placeholders ---

resource "aws_secretsmanager_secret" "db_password" {
  name                    = "skin-lesion/${var.environment}/db-password"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "database-credentials"
  }
}

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "skin-lesion/${var.environment}/jwt-secret"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "jwt-signing"
  }
}

resource "aws_secretsmanager_secret" "powerbi_client_secret" {
  name                    = "skin-lesion/${var.environment}/powerbi-client-secret"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "powerbi-embed"
  }
}
```

**What each resource does:**

- `aws_secretsmanager_secret "db_password"` - creates the database password secret entry. The name `skin-lesion/dev/db-password` uses a path-style name so `aws secretsmanager list-secrets` can filter by prefix.
- `aws_secretsmanager_secret "jwt_secret"` - creates the JWT signing secret. Used by the backend to sign and verify authentication tokens.
- `aws_secretsmanager_secret "powerbi_client_secret"` - creates the Power BI embed client secret placeholder. Used later by the Power BI analytics guide.
- `recovery_window_in_days = 7` - if a secret is deleted, it can be restored within 7 days. After that, the deletion is permanent.
- `kms_key_id = aws_kms_key.main.arn` - encrypts the secret value using the KMS key from Step 2. This means the same key protects both the S3 objects and the secret values.
- `tags` - each secret has a `Purpose` tag so cost and security audits can identify what each secret is for.

Press `Ctrl+S` to save `main.tf`.

**What these placeholders are:** Secrets Manager entries that Terraform creates with no value. The secret name and metadata are managed by Terraform, but the actual secret value is set manually or by a rotation Lambda. This keeps credentials out of `.tfvars` files and Git history.

Do not put secret values in Terraform files. Terraform state would record any value you put in a `default` or `value` argument, and the state file is stored in S3 where anyone with state access could read it.

After `terraform apply` succeeds (in a later guide that explicitly says to apply), set the actual dev database password manually:

```powershell
aws secretsmanager put-secret-value `
  --secret-id skin-lesion/dev/db-password `
  --secret-string "REPLACE_WITH_DEV_PASSWORD" `
  --profile skin-lesion-learning-dev
```

**What this does:** writes the actual password value to the secret. This is done with the AWS CLI, not Terraform, so the password never touches a `.tf` file or the Terraform state file. Replace `REPLACE_WITH_DEV_PASSWORD` with a real dev password. Do not use this password in any other environment.

**When to run this command:** only after you have run `terraform apply` for this guide and the secret exists in AWS. Running it before `apply` will fail with `ResourceNotFoundException`.

Why: creating the secret entries now means later guides that deploy pods or run database migrations can reference the secret by name without Terraform needing to know the password value.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform plans KMS, buckets, and three Secrets Manager placeholders.

Plan: 22 to add, 0 to change, 0 to destroy.
```

**What the number 22 means:** 19 (previous steps) + 3 (secrets). Adjust if the VPC was already applied.

## Step 6: ECR Repository

You are still in `infra/terraform/main.tf` from Step 5. Do not close the file.

Scroll to the bottom of `main.tf`. You should see the last block you pasted in Step 5:

```hcl
resource "aws_secretsmanager_secret" "powerbi_client_secret" {
  name                    = "skin-lesion/${var.environment}/powerbi-client-secret"
  recovery_window_in_days = 7

  kms_key_id = aws_kms_key.main.arn

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "powerbi-embed"
  }
}
```

Click your cursor on the empty line after the last `}` of the PowerBI secret block. Press `Enter` to create a blank line. Paste the ECR repository resource:

```hcl
# --- Guide 05: ECR Repository ---

resource "aws_ecr_repository" "backend" {
  name                 = "skin-lesion-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "container-registry"
  }
}
```

**What each argument does:**

- `aws_ecr_repository "backend"` - creates a private container image registry repository. The name `skin-lesion-backend-dev` is built from `var.project_name` and `var.environment`.
- `name = "skin-lesion-backend-${var.environment}"` - the repository name. Docker image tags take the form `<account>.dkr.ecr.<region>.amazonaws.com/skin-lesion-backend-dev:tag`.
- `image_tag_mutability = "MUTABLE"` - allows the same tag (e.g., `latest`) to be overwritten with a new image. Use `IMMUTABLE` in production to prevent accidental overwrites. For dev learning, `MUTABLE` is more convenient.
- `scan_on_push = true` - runs an automated vulnerability scan on each image when it is pushed. Results appear in the ECR console under the repository's `Images` tab.
- `tags` - attaches project and environment tags for cost tracking.

Press `Ctrl+S` to save `main.tf`.

Why: ECR is the container registry where built Docker images are pushed. EKS pulls from here during deployment. Creating it now means the Kubernetes guides can push and pull images without a chicken-and-egg dependency.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

**What these commands do:** the final check before this guide's plan is complete. The plan should now include KMS, all three buckets, secret placeholders, and the ECR repository.

Expected result:

```text
Terraform plans KMS, buckets, secret placeholders, and ECR without runtime clusters.

Plan: 23 to add, 0 to change, 0 to destroy.
```

**What the number 23 means:** 22 (previous steps) + 1 (ECR repository). Adjust if the VPC was already applied.

## Step 7: Create outputs.tf

Create this file:

```text
infra/terraform/outputs.tf
```

**How to create this file in VS Code:**

1. In the VS Code Explorer panel on the left, expand the `terraform` folder if it is not already expanded.
2. Right-click the `terraform` folder.
3. Click `New File...`.
4. Type exactly:
   ```text
   outputs.tf
   ```
5. Press `Enter`. VS Code creates the file and opens it in the editor tab. The file is empty.
6. Copy the HCL block below and paste it into the `outputs.tf` editor tab.
7. Press `Ctrl+S` to save the file.

**How to create this file in a plain text editor (Notepad):**

1. Open Notepad.
2. Copy the HCL block below and paste it into Notepad.
3. Click `File` > `Save As`.
4. Navigate to:
   ```text
   C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
   ```
5. In the `Save as type` dropdown, choose `All Files (*.*)` — if you leave it as `Text Documents (*.txt)`, Windows will append `.txt` and Terraform will not find the file.
6. In the `File name` field, type exactly:
   ```text
   outputs.tf
   ```
7. Click `Save`.

**What this file is:** Terraform output declarations. Outputs are values that Terraform computes after `apply` and prints to the terminal. They are also stored in the state file so later guides can reference them. Outputs do not create cloud resources.

**What to paste into the file:**

```hcl
output "kms_key_arn" {
  description = "ARN of the main KMS key"
  value       = aws_kms_key.main.arn
}

output "kms_alias_name" {
  description = "Name of the KMS alias"
  value       = aws_kms_alias.main.name
}

output "upload_bucket_name" {
  description = "Name of the S3 upload bucket"
  value       = aws_s3_bucket.uploads.id
}

output "training_bucket_name" {
  description = "Name of the S3 training bucket"
  value       = aws_s3_bucket.training.id
}

output "log_bucket_name" {
  description = "Name of the S3 log bucket"
  value       = aws_s3_bucket.logs.id
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "db_password_secret_arn" {
  description = "ARN of the database password secret"
  value       = aws_secretsmanager_secret.db_password.arn
}

output "jwt_secret_arn" {
  description = "ARN of the JWT secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}
```

Press `Ctrl+S` to save `outputs.tf`.

**What each output does:**

- `kms_key_arn` - the ARN of the KMS key. Later guides that create encrypted databases or Lambda functions reference this ARN.
- `kms_alias_name` - the alias name `alias/skin-lesion-dev`. Useful for AWS CLI commands that accept `--key-id alias/skin-lesion-dev`.
- `upload_bucket_name` - the name of the upload bucket. The backend API references this bucket name to store patient images.
- `training_bucket_name` - the name of the training bucket. The training pipeline references this bucket to read approved images.
- `log_bucket_name` - the name of the log bucket. Later guides that enable CloudTrail or ALB access logging reference this bucket.
- `ecr_repository_url` - the full URI of the ECR repository. Docker push commands use this URI as the image tag target.
- `db_password_secret_arn` - the ARN of the database password secret. The backend application's IAM role references this ARN to read the password at startup.
- `jwt_secret_arn` - the ARN of the JWT secret. The backend application's IAM role references this ARN to read the JWT signing key.

Check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Expected result:

```text
Terraform validates and the plan output now shows the output values at the bottom.

Plan: 23 to add, 0 to change, 0 to destroy.
```

The plan output should end with a section like:

```text
Changes to Outputs:
  + db_password_secret_arn = (known after apply)
  + ecr_repository_url     = (known after apply)
  + jwt_secret_arn         = (known after apply)
  + kms_alias_name         = "alias/skin-lesion-dev"
  + kms_key_arn            = (known after apply)
  + log_bucket_name        = "skin-lesion-logs-dev-version1a-0"
  + training_bucket_name   = "skin-lesion-training-dev-version1a-0"
  + upload_bucket_name     = "skin-lesion-upload-dev-version1a-0"
```

**What "(known after apply)" means:** the value depends on a resource that does not exist yet. Terraform cannot know the KMS key ARN or the ECR repository URL until AWS creates them. Bucket names are known at plan time because they are specified directly in the configuration.

## Step 8: Final Plan Review

This guide is **plan-only**. Do not run `terraform apply` in this guide.

This follows the same convention as guides 02 and 03: add resources, check the plan, stop before apply. The apply happens in a later guide that explicitly says to apply, after the remote state backend is confirmed and the permission set has all needed permissions.

Run the final check from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan -var-file="env/dev.tfvars"
```

Read the plan output carefully. It should show:

```text
23 resources to add:
  1 aws_kms_key.main
  1 aws_kms_alias.main
  1 aws_s3_bucket.logs
  1 aws_s3_bucket_public_access_block.logs
  1 aws_s3_bucket_server_side_encryption_configuration.logs
  1 aws_s3_bucket.uploads
  1 aws_s3_bucket_public_access_block.uploads
  1 aws_s3_bucket_versioning.uploads
  1 aws_s3_bucket_server_side_encryption_configuration.uploads
  1 aws_s3_bucket_lifecycle_configuration.uploads
  1 aws_s3_bucket.training
  1 aws_s3_bucket_public_access_block.training
  1 aws_s3_bucket_versioning.training
  1 aws_s3_bucket_server_side_encryption_configuration.training
  1 aws_s3_bucket_lifecycle_configuration.training
  1 aws_secretsmanager_secret.db_password
  1 aws_secretsmanager_secret.jwt_secret
  1 aws_secretsmanager_secret.powerbi_client_secret
  1 aws_ecr_repository.backend
  4 from guide 03 (VPC + 3 subnets)
```

If the VPC from guide 03 was already applied in a previous session, the plan will show 19 to add instead of 23, because the 4 VPC resources already exist.

Expected result:

```text
Terraform plans KMS, buckets, secret placeholders, and ECR without runtime clusters.
No EKS, RDS, WAF, CloudTrail, or Lambda appears in this plan.
```

## Stop Point

Do not add RDS, EKS, WAF, CloudTrail, or Lambda until this foundation has a readable Terraform plan.

Do not run `terraform apply` in this guide. The next guide will tell you when to apply.

Next guide:

```text
docs/staging/06_KUBERNETES_AFTER_DOCKER.md
```

## Record What Was Created

After this guide's plan succeeds, these Terraform resources are defined and ready to be applied in a later guide:

```text
KMS key:           aws_kms_key.main
KMS alias:         alias/skin-lesion-dev
Log bucket:        skin-lesion-logs-dev-version1a-0
Upload bucket:     skin-lesion-upload-dev-version1a-0
Training bucket:   skin-lesion-training-dev-version1a-0
DB password secret:  skin-lesion/dev/db-password
JWT secret:          skin-lesion/dev/jwt-secret
PowerBI secret:      skin-lesion/dev/powerbi-client-secret
ECR repository:    skin-lesion-backend-dev
Outputs:           kms_key_arn, kms_alias_name, upload_bucket_name,
                   training_bucket_name, log_bucket_name,
                   ecr_repository_url, db_password_secret_arn, jwt_secret_arn
```

## Cost Pause / Resume

This guide is plan-only. No cloud resources were created. No cloud shutdown is needed.

If a later guide told you to run `terraform apply` for these resources, then the following shutdown instructions apply.

**Terraform-managed resources are not shut down by `make cloud-pause` or `make cloud-shutdown`.** Those Makefile targets manage Kubernetes pods and EKS clusters, not Terraform S3 buckets or KMS keys.

To remove Terraform-managed resources after apply, run from `infra/terraform`:

```powershell
terraform destroy -var-file="env/dev.tfvars"
```

**What this does:** destroys all resources managed by the Terraform configuration. S3 buckets must be emptied before they can be destroyed. If the destroy fails with `BucketNotEmpty`, delete all objects and versions first:

```powershell
aws s3 rm s3://skin-lesion-upload-dev-version1a-0 --recursive --profile skin-lesion-learning-dev
aws s3 rm s3://skin-lesion-training-dev-version1a-0 --recursive --profile skin-lesion-learning-dev
aws s3 rm s3://skin-lesion-logs-dev-version1a-0 --recursive --profile skin-lesion-learning-dev
```

Then rerun `terraform destroy`.

Expected shutdown result:

```text
Destroy complete! Resources: 23 destroyed.
```

**Bootstrap resources from guide 04 (S3 state bucket and DynamoDB lock table) are not destroyed by terraform destroy.** They are managed manually. See guide 04's Cost Pause / Resume section for their shutdown commands.

If this guide was plan-only and no apply was run, no cloud shutdown is needed.