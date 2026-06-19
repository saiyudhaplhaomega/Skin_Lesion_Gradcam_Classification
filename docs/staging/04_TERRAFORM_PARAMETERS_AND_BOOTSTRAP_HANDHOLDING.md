# Terraform Parameters And Bootstrap Handholding Guide

Use this after the VPC plan-only lesson and before applying shared Terraform infrastructure.

This guide replaces prebuilt Terraform assumptions with the fixed dev bootstrap parameters below.

## Goal

Prepare Terraform to manage infrastructure safely:

```text
set fixed dev parameters -> create remote-state prerequisites -> configure Terraform backend -> run checks
```

**What this workflow means:** before applying any real infrastructure, the Terraform backend must be configured. The backend stores the state file (which tracks what Terraform created) in an S3 bucket and uses a DynamoDB table to prevent two people from running `apply` at the same time. Without this, state lives only on your laptop and gets out of sync if you switch machines or work with a team.

Terraform should manage the app infrastructure later. The remote state bucket and lock table are bootstrap prerequisites.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. Bootstrap shell commands (AWS CLI) run from here. Terraform commands run from `infra/terraform`.

Terraform commands run from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before running `terraform init`, `validate`, or `plan`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Create or edit backend configuration files, backend state files, and `env/*.tfvars` under `infra/terraform/`.
- Run bootstrap shell commands from the main workspace only when the step says so; run Terraform commands from `infra/terraform/`.

## Step 1: Use The Fixed Dev Parameters

Use these values for the dev learning path. Replace only `YOUR_ACCOUNT_ID` with your AWS account ID.

Your requested suffix was:

```text
version1A.0
```

Use this AWS-valid S3 bucket suffix in commands and code:

```text
version1a.0
```

**Why this changed:** S3 bucket names must be lowercase. The uppercase `A` in `version1A.0` would make `aws s3api create-bucket` fail with an invalid bucket name error, so the actual bucket name uses the lowercase equivalent.

```text
PROJECT_NAME=skin-lesion
ENVIRONMENT=dev
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID
REQUESTED_UNIQUE_SUFFIX=version1A.0
S3_SAFE_UNIQUE_SUFFIX=version1a.0
TF_STATE_BUCKET=skin-lesion-tf-state-dev-version1a-0-526404916929
TF_LOCK_TABLE=skin-lesion-tf-lock-dev
VPC_CIDR=10.0.0.0/16
PUBLIC_SUBNET_A_CIDR=10.0.1.0/24
PRIVATE_APP_SUBNET_A_CIDR=10.0.11.0/24
PRIVATE_DATA_SUBNET_A_CIDR=10.0.21.0/24
```

**What these parameters mean:**

- `PROJECT_NAME=skin-lesion` - used as a prefix for resource names to avoid collisions with other projects in the same AWS account.
- `ENVIRONMENT=dev` - the environment label. Appears in resource names and tags to distinguish dev from staging and prod.
- `AWS_REGION=us-east-1` - the AWS region where all resources for this learning path are created.
- `AWS_ACCOUNT_ID=YOUR_ACCOUNT_ID` - your 12-digit AWS account number. Used in IAM policies and resource ARNs.
- `REQUESTED_UNIQUE_SUFFIX=version1A.0` - the suffix you chose for this lesson.
- `S3_SAFE_UNIQUE_SUFFIX=version1a.0` - the same suffix lowercased so AWS accepts it for S3 bucket names.
- `TF_STATE_BUCKET=skin-lesion-tf-state-dev-version1a-0-526404916929` - the S3 bucket that stores the Terraform state file. S3 bucket names are globally unique across all AWS accounts, so this name includes the learning-dev account ID to avoid collisions.
- `TF_LOCK_TABLE=skin-lesion-tf-lock-dev` - the DynamoDB table that Terraform uses to lock the state file while `apply` is running. Prevents concurrent applies from corrupting state.
- `VPC_CIDR=10.0.0.0/16` - the IP address range for the VPC, matching the block from the VPC guide.
- The three subnet CIDRs define the address ranges for public (10.0.1.x), private-app (10.0.11.x), and private-data (10.0.21.x) subnets.

Why: S3 bucket names are globally unique. The suffix is fixed once for your AWS account so the Terraform backend path does not change between lessons.

## Step 1.5: Add Bootstrap Permissions To The SSO Permission Set

The VPC guide created a permission set named:

```text
SkinLesionVpcLearning
```

That permission set can plan and later clean up the VPC lesson, but it does not yet allow the S3 and DynamoDB bootstrap commands in this guide. Add the permissions below before running Step 2.

In the AWS Console:

1. Sign in to the Management account as `saiyu-admin`.
2. Open `IAM Identity Center`.
3. Open `Permission sets`.
4. Open:

```text
SkinLesionVpcLearning
```

5. Choose `Inline policy`.
6. Edit the policy JSON.
7. Keep the existing STS and EC2 statements from the VPC guide.
8. Add these two new statements inside the top-level `Statement` array.
9. Replace `YOUR_ACCOUNT_ID` with the 12-digit account ID for `skin-lesion-learning-dev`.
10. Save the inline policy.
11. If IAM Identity Center shows a prompt to provision or reprovision the permission set, choose it.
12. Confirm the permission set is provisioned to the `skin-lesion-learning-dev` account.

```json
{
  "Sid": "AllowTerraformStateBucketBootstrap",
  "Effect": "Allow",
  "Action": [
    "s3:CreateBucket",
    "s3:DeleteBucket",
    "s3:GetBucketVersioning",
    "s3:PutBucketVersioning",
    "s3:GetBucketPublicAccessBlock",
    "s3:PutBucketPublicAccessBlock",
    "s3:ListBucket",
    "s3:ListBucketVersions",
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:DeleteObjectVersion"
  ],
  "Resource": [
    "arn:aws:s3:::skin-lesion-tf-state-dev-version1a-0-526404916929",
    "arn:aws:s3:::skin-lesion-tf-state-dev-version1a-0-526404916929/*"
  ]
},
{
  "Sid": "AllowTerraformLockTableBootstrap",
  "Effect": "Allow",
  "Action": [
    "dynamodb:CreateTable",
    "dynamodb:DeleteTable",
    "dynamodb:DescribeTable",
    "dynamodb:PutItem",
    "dynamodb:GetItem",
    "dynamodb:DeleteItem"
  ],
  "Resource": "arn:aws:dynamodb:us-east-1:526404916929:table/skin-lesion-tf-lock-dev"
}
```

**What this does:** extends the learning permission set just enough to create, verify, and delete the manually bootstrapped remote-state resources.

Expected result:

```text
SkinLesionVpcLearning still has the original STS and EC2 permissions, plus the S3 and DynamoDB bootstrap permissions above.
```

Why: Step 2 and Step 3 create cloud resources outside Terraform. The same learning identity must also be able to delete those resources when you shut the lesson down.

After changing the permission set, refresh your local SSO session:

```powershell
aws sso logout
aws sso login --profile skin-lesion-learning-dev
aws sts get-caller-identity --profile skin-lesion-learning-dev
```

**What this does:** clears the old cached SSO role session and starts a new one that can include the updated permission set.

Expected result:

```text
The ARN still shows AWSReservedSSO_SkinLesionVpcLearning, but the role now has the new S3 and DynamoDB bootstrap permissions.
```

If DynamoDB still returns `AccessDeniedException`, the permission-set update did not provision to the learning-dev account yet. Go back to IAM Identity Center, open the `SkinLesionVpcLearning` permission set, and check that the DynamoDB statement is saved and provisioned for `skin-lesion-learning-dev`.

If the permission set was just saved and provisioned, wait one minute and retry the DynamoDB command once. IAM Identity Center permission updates can take a short moment to become effective for the role session.

If you accidentally created the state bucket with the wrong AWS profile, delete it from that wrong profile first. S3 bucket names are global, so AWS may return `OperationAborted` for a while if you recreate the same bucket name immediately after deletion. If that happens, use the fresh account-specific bucket name in this guide instead: `skin-lesion-tf-state-dev-version1a-0-526404916929`. Do not run versioning or public-access-block commands until `create-bucket` succeeds.

## Step 1.6: Use The AWS Profile From Guide 03

Guide 03 already configured the AWS CLI profile. Do not create a second profile for this guide.

Run from the repo root:

```powershell
aws configure list-profiles
```

Expected result includes:

```text
skin-lesion-learning-dev
```

Set that profile in the current PowerShell terminal:

```powershell
$env:AWS_PROFILE = "skin-lesion-learning-dev"
$env:AWS_REGION = "us-east-1"
aws sts get-caller-identity
```

**What this does:** reuses the SSO or AWS CLI profile created in Guide 03 and makes it the active profile for this terminal only.

Expected result:

```text
Account, Arn, and UserId print for the skin-lesion-learning-dev account.
```

The `Arn` should look like an SSO role, not a plain IAM user:

```text
arn:aws:sts::<account-id>:assumed-role/AWSReservedSSO_...
```

Stop if it looks like this:

```text
arn:aws:iam::<account-id>:user/aiengineer
```

**What this means:** the terminal is still using the default IAM user instead of the Guide 03 SSO profile. Run the profile export commands above again, or add `--profile skin-lesion-learning-dev` to every AWS command in this guide.

If the command says the SSO session expired, refresh the existing profile:

```powershell
aws sso login --profile skin-lesion-learning-dev
```

Then rerun:

```powershell
aws sts get-caller-identity
```

Why: 04 needs the same learning-dev identity from 03. This step verifies the active terminal is using that identity before creating the backend bucket and lock table.

## Step 2: Create Remote State Bucket Manually

Run from the repo root after Step 1.6 prints the expected AWS identity:

```powershell
aws s3api create-bucket `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --region us-east-1 `
  --profile skin-lesion-learning-dev
```

**What this does:** creates the S3 bucket that will store Terraform's state file. The backtick (`` ` ``) is the PowerShell line continuation character.

Enable versioning:

```powershell
aws s3api put-bucket-versioning `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --versioning-configuration Status=Enabled `
  --profile skin-lesion-learning-dev
```

**What this does:** enables versioning on the state bucket. S3 versioning keeps every previous version of the state file, so if Terraform corrupts the state you can restore a known-good version.

Block public access:

```powershell
aws s3api put-public-access-block `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true `
  --profile skin-lesion-learning-dev
```

**What this does:** enables all four public access block settings on the bucket. The Terraform state file contains resource IDs and configuration details that should never be publicly accessible.

Check:

```powershell
aws s3api get-bucket-versioning --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 --profile skin-lesion-learning-dev
```

**What this does:** reads the versioning configuration from the bucket to confirm it was set correctly.

Expected result:

```json
{"Status": "Enabled"}
```

**What this result means:** versioning is active. If you see `{}` or `{"Status": "Suspended"}`, the `put-bucket-versioning` command did not work and should be re-run.

## Step 3: Create Lock Table Manually

Run:

```powershell
aws dynamodb create-table `
  --table-name skin-lesion-tf-lock-dev `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region us-east-1 `
  --profile skin-lesion-learning-dev
```

**What this does:** creates the DynamoDB table that Terraform uses for state locking. `LockID` is the primary key that Terraform writes when it acquires the lock. `PAY_PER_REQUEST` billing means you pay only for the occasional lock writes and reads, not for reserved capacity.

Check:

```powershell
aws dynamodb describe-table --table-name skin-lesion-tf-lock-dev --region us-east-1 --profile skin-lesion-learning-dev
```

**What this does:** queries the DynamoDB API for the table's current status. Returns the full table description including status, creation time, and key schema.

Expected result:

```text
TableStatus is ACTIVE
```

**What this means:** the table is ready to accept lock writes. If the status is `CREATING`, wait a few seconds and check again.

## Step 4: Configure Terraform Backend

Create:

```text
infra/terraform/backend.tf
```

**What this file is:** the backend configuration that tells Terraform where to store its state file. Separating it from `main.tf` makes it easier to find and modify.

Paste:

```hcl
terraform {
  backend "s3" {
    bucket       = "skin-lesion-tf-state-dev-version1a-0-526404916929"
    key          = "dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

**What this HCL does:**

- `backend "s3"` - tells Terraform to store state in an S3 bucket instead of locally.
- `bucket` - the name of the bucket you created in Step 2.
- `key = "dev/terraform.tfstate"` - the path within the bucket where the state file is written. The `dev/` prefix keeps dev state separate from staging and prod state in the same bucket.
- `use_lockfile = true` - tells Terraform to store the state lock as an S3 object (`dev/terraform.tfstate.tflock`) inside the state bucket, instead of using a separate DynamoDB lock table. This is the modern replacement for the deprecated `dynamodb_table` parameter. Terraform 1.10 and later support this. You still need the DynamoDB table from Step 3 for backward compatibility, but Terraform will use the S3 lockfile instead.
- `encrypt = true` - enables server-side encryption for the state file at rest in S3.

Check:

```powershell
cd infra/terraform
terraform init
terraform validate
```

**What these commands do:**

- `cd infra/terraform` - moves to the Terraform directory.
- `terraform init` - re-runs initialisation now that the backend is configured. Terraform migrates any existing local state to the S3 bucket and confirms the connection.
- `terraform validate` - confirms the configuration is valid after backend setup.

Expected result:

```text
Terraform initializes the S3 backend and validates successfully.
```

**What this means:** Terraform connected to the S3 bucket, found or created the state file, and reported no configuration errors.

## Step 5: Record What Was Created

If Steps 2-4 succeed, this guide created or used these AWS resources:

```text
S3 bucket: skin-lesion-tf-state-dev-version1a-0-526404916929
DynamoDB table: skin-lesion-tf-lock-dev
S3 object: dev/terraform.tfstate, created after terraform init or later Terraform use
```

Check from the repo root:

```powershell
aws s3api get-bucket-versioning --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 --profile skin-lesion-learning-dev
aws dynamodb describe-table --table-name skin-lesion-tf-lock-dev --region us-east-1 --profile skin-lesion-learning-dev
```

**What this does:** confirms the manually bootstrapped cloud resources exist before you continue to later Terraform guides.

Expected result:

```text
The bucket versioning status is Enabled.
The DynamoDB table status is ACTIVE.
```

Why: these resources are intentionally created before Terraform can manage shared infrastructure. Because they are bootstrap prerequisites, you must also know how to remove them manually.

## Stop Point

Do not add VPC, NAT Gateway, database, WAF, or Lambda yet. Remote state must work first.

## Cost Pause / Resume

This guide creates two cloud resources manually: an S3 state bucket and a DynamoDB lock table. They are usually very low cost, but they are still AWS resources. If you are done with the lesson and do not need the backend anymore, shut them down manually with the commands below.

Run from the repo root only after you are sure no later Terraform state must be preserved:

```powershell
aws dynamodb delete-table `
  --table-name skin-lesion-tf-lock-dev `
  --region us-east-1 `
  --profile skin-lesion-learning-dev

aws s3api list-object-versions `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --output json `
  --profile skin-lesion-learning-dev
```

**What this command block does:**

- `aws dynamodb delete-table` deletes the Terraform lock table.
- `aws s3api list-object-versions` shows every current and versioned object in the state bucket. Versioned buckets must be emptied before they can be deleted.

If the list output shows no `Versions` or `DeleteMarkers`, delete the empty bucket:

```powershell
aws s3api delete-bucket `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --region us-east-1 `
  --profile skin-lesion-learning-dev
```

If the list output shows object versions, delete each version first. Use the exact `Key` and `VersionId` values printed by the previous command:

```powershell
aws s3api delete-object `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --key dev/terraform.tfstate `
  --version-id VERSION_ID_FROM_LIST_OUTPUT `
  --profile skin-lesion-learning-dev
```

Then rerun:

```powershell
aws s3api list-object-versions `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --output json `
  --profile skin-lesion-learning-dev

aws s3api delete-bucket `
  --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 `
  --region us-east-1 `
  --profile skin-lesion-learning-dev
```

**What this does:** removes all versions of the Terraform state object, then deletes the now-empty bucket.

Expected shutdown result:

```text
The DynamoDB table no longer exists.
The S3 bucket no longer exists.
```

Check shutdown:

```powershell
aws dynamodb describe-table --table-name skin-lesion-tf-lock-dev --region us-east-1 --profile skin-lesion-learning-dev
aws s3api head-bucket --bucket skin-lesion-tf-state-dev-version1a-0-526404916929 --profile skin-lesion-learning-dev
```

Expected result:

```text
ResourceNotFoundException for the DynamoDB table.
404 or Not Found for the S3 bucket.
```

Why: these bootstrap resources are not created by the normal `make cloud-shutdown` path. They exist specifically so Terraform can later create and destroy the rest of the infrastructure safely.

Before starting the next guide after a full bootstrap shutdown, recreate the bucket and table by rerunning Steps 2-4.
