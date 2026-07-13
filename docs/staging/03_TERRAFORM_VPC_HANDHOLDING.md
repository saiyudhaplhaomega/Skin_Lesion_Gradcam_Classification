# Terraform VPC Handholding Guide

Use this after `docs/staging/02_TERRAFORM_FROM_EMPTY_MAIN.md`.

## Goal

Learn VPC networking one small piece at a time. This guide is plan-only. Do not run `terraform apply` in this guide.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root before changing into `infra/terraform`.

Terraform file paths in this guide are relative to:

```text
infra/terraform
```

**What this means:** when the guide shows a file path like `main.tf`, the full path is `infra/terraform/main.tf`. Always `cd infra/terraform` before running Terraform commands.

After `cd infra/terraform`, run every Terraform command from `infra/terraform`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Create or edit Terraform files such as `main.tf`, `variables.tf`, `outputs.tf`, and `env/*.tfvars` under `infra/terraform/`.
- Run Terraform commands from `infra/terraform/` after changing into that directory.

## Account And Identity Map

Read this before Step 1. There are only **two AWS accounts** and **three identities** in this guide. Every step below tells you exactly which account to enter and which identity to sign in as.

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
    Used: Only for initial setup (Steps 1.2 - 1.4a).
    Never used for Terraform. Never gets access keys.
    After Step 1.4a you sign out of root and never use it again.

saiyu-admin  (IAM user)
    In: Management account.
    Used: For account-level admin work after root is locked down.
    Created in Step 1.4a. Has AdministratorAccess.
    Used to enable IAM Identity Center, create SSO users, assign permission sets.
    Not used for Terraform itself.

saiyu  (IAM Identity Center / SSO user)
    In: Management account (Identity Center directory), accesses learning-dev via SSO.
    Used: Your daily human login for the SSO portal and CLI.
    Created in Step 1.6. Gets temporary CLI credentials via `aws sso login`.
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

## Step 1: AWS Account, User, Group, Permissions, And CLI Setup

Do this before any Terraform guide that talks to AWS.

This section is intentionally slow and explicit. AWS permissions are not a place to guess.

**Main rule:** do not use your AWS root account for daily work, Terraform, CLI commands, or access keys.

The AWS root user owns the whole account. Use it only for account-level setup and recovery tasks. Protect it with MFA. Do not create root access keys.

### Step 1.1: Choose The Account Layout

No AWS Console action yet. Read the **Account And Identity Map** above first.

Use separate AWS accounts instead of doing all learning in one account.

Recommended beginner layout:

```text
Management account: billing, AWS Organizations, account administration only
skin-lesion-learning-dev account: disposable Terraform learning resources
skin-lesion-staging account: production-like testing later
skin-lesion-prod account: real production only later
```

**What this means:** the management account is not where you experiment. The `skin-lesion-learning-dev` account is where this Terraform guide belongs.

Why: separate accounts create a blast-radius boundary. A mistake in the learning account should not affect billing administration, staging, or production.

### Step 1.2: Secure The Root User First

```text
ENTER: Management account as root user
```

In the AWS Console, sign in as the root user only long enough to do this setup.

1. Open the AWS Console.
2. Sign in as `Root user`.
3. Open the account menu in the top-right corner.
4. Choose `Security credentials`.
5. Find `Multi-factor authentication (MFA)`.
6. Choose `Assign MFA device`.
7. Use a passkey, security key, or authenticator app.
8. Confirm MFA works.
9. Check `Access keys`.
10. If root access keys exist, delete them unless you have a documented emergency reason.

**What this does:** protects the most powerful identity in the account and removes long-lived root programmatic credentials.

Expected result:

```text
Root MFA is enabled.
Root has no access keys.
```

### Step 1.3: Create A Separate Learning Account

Still in the Management account as root user.

Do this from the management account.

1. Open `AWS Organizations`.
2. Choose `AWS accounts`.
3. Choose `Add an AWS account`.
4. Choose `Create an AWS account`.
5. Account name:

```text
skin-lesion-learning-dev
```

6. Email address: use a real email address you control.
7. IAM role name: leave the default if AWS suggests one:

```text
OrganizationAccountAccessRole
```

8. Choose `Create AWS account`.

**What this does:** creates a separate AWS member account for disposable learning infrastructure.

Expected result:

```text
AWS Organizations shows a member account named skin-lesion-learning-dev.
```

Why: this account is where the VPC plan belongs. Do not run this Terraform lesson in the management account or production account.

**How this connects to SSO later:** the learning-dev account is a member of your AWS Organization. In Steps 1.5-1.9 you will enable IAM Identity Center in the Management account and create an SSO user there. Because Identity Center is org-level, that same Management-account SSO user can be assigned to access the learning-dev member account — you do not need to create a separate user inside learning-dev. That is why Step 1.9 assigns the group to the learning-dev account from the Management account's Identity Center, not from inside learning-dev.

### Step 1.4a: If You Are Starting From Only A Root Account

Still in the Management account as root user. After this section you will sign out of root for good.

Use this section when you have just created an AWS account and the only login you currently have is the root email/password.

The goal is:

```text
root account -> secure root -> create a daily admin identity (saiyu-admin) -> stop using root -> enable IAM Identity Center -> create SSO user (saiyu) -> use SSO for Terraform
```

Do not create access keys directly on root. Do not create access keys for Terraform at all — this guide uses SSO only.

#### Open The AWS Console As Root

1. Open https://console.aws.amazon.com/
2. Choose `Root user`.
3. Enter the root email address for the AWS account.
4. Choose `Next`.
5. Enter the root password.
6. Complete MFA if AWS asks.

Expected result:

```text
You are in the AWS Console as root.
```

#### Secure Root Before Creating Users

1. Look at the top-right corner of the AWS Console.
2. Click the account name or account number.
3. Choose `Security credentials`.
4. Find `Multi-factor authentication (MFA)`.
5. Click `Assign MFA device`.
6. Type a device name:

```text
root-mfa
```

7. Choose an MFA type. For beginners, use one of these:

```text
Authenticator app
Security key
Passkey
```

8. Follow the screen prompts to pair the device.
9. Finish the MFA setup.
10. Stay on `Security credentials`.
11. Find `Access keys`.
12. If you see any root access keys, delete them unless you have a documented emergency reason.

Expected result:

```text
Root MFA is active.
Root has no access keys.
```

Why: root is too powerful. Root should not be the identity your laptop uses for Terraform.

#### Create A Daily Admin IAM Group

This creates a temporary beginner admin path so you can stop signing in as root. This group is for account setup only, not for routine Terraform learning forever.

1. In the AWS Console search bar at the top, type:

```text
IAM
```

2. Click `IAM`.
3. In the left sidebar, click `User groups`.
4. Click `Create group`.
5. In `User group name`, type:

```text
SkinLesionAdministrators
```

6. Scroll to `Attach permissions policies`.
7. In the policy search box, type:

```text
AdministratorAccess
```

8. Check the box next to `AdministratorAccess`.
9. Click `Create group`.

Expected result:

```text
IAM shows a user group named SkinLesionAdministrators.
```

Why: this lets you make one non-root administrator identity. Later, do everyday work with smaller groups such as `SkinLesionTerraformLearners`.

#### Create Your Daily Admin IAM User

1. In IAM, click `Users` in the left sidebar.
2. Click `Create user`.
3. In `User name`, type your daily admin user name:

```text
saiyu-admin
```

4. Check:

```text
Provide user access to the AWS Management Console
```

5. If AWS asks `Are you providing console access to a person?`, choose:

```text
I want to create an IAM user
```

6. Choose one of these password options:

```text
Autogenerated password
```

or:

```text
Custom password
```

7. Keep this checked if AWS shows it:

```text
Users must create a new password at next sign-in
```

8. Click `Next`.
9. On `Set permissions`, choose:

```text
Add user to group
```

10. Check the box next to:

```text
SkinLesionAdministrators
```

11. Click `Next`.
12. Review the user.
13. Click `Create user`.
14. Copy the console sign-in URL if AWS shows one.
15. Save the temporary password in your password manager only long enough to complete first sign-in.

Expected result:

```text
IAM shows a user named saiyu-admin in the SkinLesionAdministrators group.
```

#### Sign Out Of Root And Sign In As The Admin User

```text
EXIT: Management account as root user
ENTER: Management account as saiyu-admin
```

1. Click the top-right account menu.
2. Click `Sign out`.
3. Open the IAM console sign-in URL AWS gave you.
4. Sign in as:

```text
saiyu-admin
```

5. Enter the temporary password.
6. Set a new password if prompted.
7. After sign-in, open the top-right account menu.
8. Confirm you are no longer signed in as root.

Expected result:

```text
You are signed in as saiyu-admin, not root.
```

#### Add MFA To The Admin User

1. In the AWS Console search bar, type:

```text
IAM
```

2. Open `IAM`.
3. In the left sidebar, click `Users`.
4. Click:

```text
saiyu-admin
```

5. Click the `Security credentials` tab.
6. Find `Multi-factor authentication (MFA)`.
7. Click `Assign MFA device`.
8. Device name:

```text
saiyu-admin-mfa
```

9. Choose an authenticator app, security key, or passkey.
10. Follow the screen prompts.
11. Finish MFA setup.

Expected result:

```text
saiyu-admin has MFA enabled.
```

From this point onward, do not use root for normal setup work. Use `saiyu-admin` or IAM Identity Center admin access.

### Step 1.5: Enable IAM Identity Center

Still in the Management account, now signed in as **saiyu-admin**.

1. Sign in to the management account as `saiyu-admin` or another administrator.
2. Click the AWS Console search bar at the top.
3. Type:

```text
IAM Identity Center
```

4. Click `IAM Identity Center`.
5. If AWS shows a landing page, click `Enable`.
6. If AWS asks where to enable IAM Identity Center, choose the organization option if available.
7. Choose the identity source AWS suggests for a beginner:

```text
Identity Center directory
```

8. Click through the confirmation screens until IAM Identity Center is enabled.

**What this does:** turns on IAM Identity Center at the organization level. This means users you create here in the Management account can be assigned to any member account in your AWS Organization — including the `skin-lesion-learning-dev` account you created in Step 1.3.

Expected result:

```text
IAM Identity Center opens a dashboard with Users, Groups, Permission sets, and AWS accounts.
```

### Step 1.6: Create Your Human User

In `IAM Identity Center`:

1. In the left sidebar, click `Users`.
2. Click `Add user`.
3. In `Username`, type:

```text
saiyu
```

4. In `Email address`, type your email address.
5. In `Confirm email address`, type the same email again.
6. In `First name`, type your first name.
7. In `Last name`, type your last name.
8. In `Display name`, type:

```text
Saiyudh Mannan
```

9. Click `Next`.
10. On the group assignment screen, leave group assignment empty for now if no group exists yet.
11. Click `Next` or `Add user`, depending on the console screen.
12. Review the user details.
13. Click `Add user`.
14. Check your email inbox.
15. Open the AWS invitation email.
16. Follow the invitation link.
17. Set your password.
18. Set MFA if AWS asks.

**What this does:** creates your human sign-in identity. This user replaces daily root-account sign-in.

Expected result:

```text
IAM Identity Center shows a user named saiyu.
```

### Step 1.7: Create A Beginner Learning Group

In `IAM Identity Center`:

1. In the left sidebar, click `Groups`.
2. Click `Create group`.
3. In `Group name`, type:

```text
SkinLesionTerraformLearners
```

4. In `Description`, type:

```text
People allowed to run Terraform learning guides in the skin-lesion-learning-dev account.
```

5. Click `Create group`.
6. Open the new group:

```text
SkinLesionTerraformLearners
```

7. Click `Add users`.
8. Search for:

```text
saiyu
```

9. Check the box next to your user.
10. Click `Add users`.

**What this does:** puts your human user into a group. You assign permissions to the group, not directly to the user.

Why: group-based access is easier to audit and remove later.

Expected result:

```text
SkinLesionTerraformLearners contains the saiyu user.
```

### Step 1.8: Create A Permission Set For This VPC Lesson

In `IAM Identity Center`:

1. In the left sidebar, click `Permission sets`.
2. Click `Create permission set`.
3. Choose:

```text
Custom permission set
```

4. Click `Next`.
5. In `Permission set name`, type:

```text
SkinLesionVpcLearning
```

6. In `Description`, type:

```text
Allows Terraform VPC learning in the skin-lesion-learning-dev account.
```

7. Set `Session duration` to:

```text
4 hours
```

8. Click `Next`.
9. On the permissions screen, choose:

```text
Inline policy
```

10. Delete any placeholder JSON.
11. Paste this JSON:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowIdentityCheck",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowVpcLearningPlanCreateAndCleanup",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*"
    }
  ]
}
```

12. Click `Next`.
13. Review the permission set.
14. Confirm the name is:

```text
SkinLesionVpcLearning
```

15. Confirm the policy includes only STS and EC2 actions.
16. Click `Create`.

**What this allows:** Terraform can authenticate, inspect EC2/VPC state, plan this guide, and later create or delete only the VPC/subnet resources taught here.

**What this does not allow:** IAM admin, billing changes, EKS, RDS, DSQL, S3, ECR, SQS, WAF, CloudTrail, or production operations.

Expected result:

```text
IAM Identity Center shows a permission set named SkinLesionVpcLearning.
```

### Step 1.9: Assign The Group To The Learning Account

**Why you are doing this from the Management account, not from inside learning-dev:** the `saiyu` SSO user was created in the Management account's Identity Center (Step 1.6). Identity Center is org-level, so you assign SSO users to member accounts from the Management account — you do not sign into learning-dev to do this. The `skin-lesion-learning-dev` account appears in the Identity Center's AWS accounts list because it is a member of your AWS Organization (created in Step 1.3). This assignment is what bridges the Management-account SSO user to the learning-dev account.

In `IAM Identity Center`:

1. In the left sidebar, click `AWS accounts`.
2. Find the account named:

```text
skin-lesion-learning-dev
```

3. Check the box next to `skin-lesion-learning-dev`.
4. Click `Assign users or groups`.
5. Choose the `Groups` tab.
6. Search for:

```text
SkinLesionTerraformLearners
```

7. Check the box next to `SkinLesionTerraformLearners`.
8. Click `Next`.
9. Check the box next to this permission set:

```text
SkinLesionVpcLearning
```

10. Click `Next`.
11. Review:

```text
Account: skin-lesion-learning-dev
Group: SkinLesionTerraformLearners
Permission set: SkinLesionVpcLearning
```

12. Click `Submit`.
13. Wait for AWS to finish provisioning the assignment.

**What this does:** lets everyone in the group use the `SkinLesionVpcLearning` role in only the `skin-lesion-learning-dev` account.

Expected result:

```text
The skin-lesion-learning-dev account shows SkinLesionTerraformLearners assigned with SkinLesionVpcLearning.
```

### Step 1.10: Configure AWS CLI For IAM Identity Center

```text
EXIT: Management account AWS Console (you are done with the console for now)
ENTER: Local terminal as saiyu (SSO user)
```

You have finished all console work in the Management account. Now switch to your local terminal to configure the AWS CLI. The CLI will log in as the **saiyu** SSO user (created in Step 1.6) to access the **skin-lesion-learning-dev** account.

Run from PowerShell:

```powershell
aws configure sso
```

**What this does:** starts the AWS CLI v2 IAM Identity Center profile setup.

When prompted, use values from your IAM Identity Center setup:

```text
SSO session name: skin-lesion-learning
SSO start URL: your IAM Identity Center access portal URL
SSO region: the region where IAM Identity Center is enabled
CLI default client Region: us-east-1
CLI default output format: json
CLI profile name: skin-lesion-learning-dev
```

Then log in:

```powershell
aws sso login --profile skin-lesion-learning-dev
```

**What this does:** opens a browser login and stores temporary CLI credentials for this profile.

Check:

```powershell
aws sts get-caller-identity --profile skin-lesion-learning-dev
```

Expected result:

```text
Account, Arn, and UserId print for the skin-lesion-learning-dev account.
```

Set the profile for the current terminal:

```powershell
$env:AWS_PROFILE = "skin-lesion-learning-dev"
aws sts get-caller-identity
```

**What this does:** tells Terraform to use the `skin-lesion-learning-dev` profile in this terminal.

### Step 1.11: Permission Check For This Guide

Still in your local terminal, authenticated to **skin-lesion-learning-dev** via SSO.

Run from `infra/terraform` after the profile works:

```powershell
terraform plan
```

Expected result for this guide:

```text
Plan: 4 to add, 0 to change, 0 to destroy.
```

**What this means:** Terraform can authenticate and can plan the one VPC plus three subnets in this guide.

Do not run:

```powershell
terraform apply
```

Why: this guide is plan-only. The next guide prepares Terraform state before shared infrastructure is applied.

### Step 1.12: What Not To Do

Do not do these:

```text
Do not use the root account for Terraform.
Do not create root access keys.
Do not commit access keys or secrets.
Do not attach AdministratorAccess in production.
Do not run this guide in a production account.
Do not run terraform apply in this guide.
Do not skip budgets and alerts before creating paid resources.
```

Official AWS references for this section:

- AWS IAM security best practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- IAM Identity Center permission sets: https://docs.aws.amazon.com/singlesignon/latest/userguide/permissionsetsconcept.html
- IAM Identity Center account assignments: https://docs.aws.amazon.com/singlesignon/latest/userguide/useraccess.html
- AWS CLI IAM Identity Center setup: https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-sso.html
- IAM groups: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_groups_create.html
- IAM users: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html

## Step 2: Provider Only

Still in your local terminal, authenticated to **skin-lesion-learning-dev**. All Terraform commands in Steps 2-6 run from here.

First create only the provider block in `infra/terraform/main.tf`.

Run from the repo root:

```powershell
cd infra/terraform
terraform init
terraform fmt
terraform validate
terraform plan
```

**What these commands do:**

- `cd infra/terraform` - moves into the Terraform directory.
- `terraform init` - downloads provider plugins and initialises the backend.
- `terraform fmt` - formats the `.tf` files.
- `terraform validate` - checks syntax and structure.
- `terraform plan` - shows what Terraform would create. With only a provider block and no resources, this should report zero changes.

Expected result:

```text
Terraform initializes and reports no resources to create.
```

**What this means:** the configuration is valid and contains no resource blocks, so the plan shows nothing to add, change, or destroy.

## Step 3: Add VPC Only

Add this code to `infra/terraform/main.tf`:

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "skin-lesion-learning-dev-vpc"
  }
}
```

**What this resource does:**

- `resource "aws_vpc" "main"` - declares an AWS VPC resource with the local name `main`. Other resources reference it as `aws_vpc.main`.
- `cidr_block = "10.0.0.0/16"` - allocates the IP address range `10.0.0.0` to `10.0.255.255` (65,536 addresses) to this VPC.
- `enable_dns_hostnames = true` - lets EC2 instances and EKS nodes get DNS hostnames inside the VPC.
- `enable_dns_support = true` - enables the AWS DNS resolver inside the VPC. Required for hostname resolution to work.

Run from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What this does:** after adding the VPC resource, run fmt and validate to check syntax, then plan to preview the creation.

Expected result:

```text
Terraform plans one VPC to create.
```

**What this means:** the plan output shows `+ aws_vpc.main` with the configured CIDR block. No other resources are planned.

If `terraform plan` fails with this message, AWS credentials are not configured for the shell running Terraform:

```text
Error: No valid credential sources found
```

**What this means:** the Terraform syntax is valid, but the AWS provider cannot authenticate. Even a plan-only guide needs AWS credentials because Terraform asks the AWS provider to prepare the plan.

Check from any terminal:

```powershell
aws sts get-caller-identity
```

**What this does:** asks AWS who the current credentials belong to. It does not create resources.

Expected result:

```text
Account, Arn, and UserId print.
```

If this fails, go back to Step 1 and configure AWS credentials before continuing.

Do not run `terraform apply` in this guide after credentials work. This guide remains plan-only.

## Step 4: Add One Public Subnet

```hcl
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "skin-lesion-learning-dev-public-a"
  }
}
```

**What this resource does:**

- `vpc_id = aws_vpc.main.id` - references the VPC created in Step 2. Terraform resolves this to the VPC's ID after creation.
- `cidr_block = "10.0.1.0/24"` - allocates 256 addresses (10.0.1.0 to 10.0.1.255) to this subnet.
- `availability_zone = "us-east-1a"` - places the subnet in the `us-east-1a` data center.
- `map_public_ip_on_launch = true` - assigns a public IP to every instance launched in this subnet. Required for internet-facing load balancers.

Why: public subnets are for internet-facing load balancers, not databases.

Run from `infra/terraform`:

```powershell
terraform plan
```

**What this does:** previews the addition of the public subnet alongside the VPC.

Expected result:

```text
Terraform plans one VPC and one public subnet.
```

## Step 5: Add Private App Subnet

Add this resource to:

```text
infra/terraform/main.tf
```

**What this file is:** the same `main.tf` from earlier. Append the new resource block to the bottom.

```hcl
resource "aws_subnet" "private_app_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.11.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "skin-lesion-learning-dev-private-app-a"
  }
}
```

**What this resource does:** creates a subnet in the same AZ as the public subnet but with no public IP assignment and a different CIDR range (10.0.11.x). Backend pods and workers run here, isolated from the internet.

Why: backend pods and workers belong in private subnets.

Run from `infra/terraform`:

```powershell
terraform plan
```

**What this does:** previews the three planned resources: VPC, public subnet, and private app subnet.

Expected result:

```text
Terraform plans one VPC, one public subnet, and one private app subnet.
```

## Step 6: Add Private Data Subnet

Add this resource to:

```text
infra/terraform/main.tf
```

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

**What this resource does:** creates a third subnet in the 10.0.21.x range, reserved for databases and other data-tier resources. No public IP, no internet gateway route.

Why: databases should not be directly reachable from the internet.

Run from `infra/terraform`:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** format, validate, and preview all four planned resources (VPC + 3 subnets).

Expected result:

```text
Terraform plans one VPC, one public subnet, one private app subnet, and one private data subnet. The plan does not include NAT Gateway, EKS, databases, or load balancers.
```

**What this means:** the plan shows exactly four resources to create. Nothing else. NAT Gateway, EKS, and databases are added in later guides after the bootstrap is complete.

## Cost Warning

Do not add NAT Gateway until you understand the monthly cost. NAT Gateway can cost money even when your app is idle.

## Stop Point

Before applying anything, explain the plan in plain English:

```text
Terraform will create one VPC and three subnets. It will not create EKS, NAT, databases, or load balancers yet.
```

**What this stop-point exercise means:** articulating the plan in plain terms before applying it confirms you understand what Terraform will do. If you cannot explain the plan clearly, do not apply it.

Next guide:

```text
docs/staging/04_TERRAFORM_PARAMETERS_AND_BOOTSTRAP_HANDHOLDING.md
```

**What this guide covers:** sets up the S3 remote state bucket and DynamoDB lock table so Terraform state is stored safely before the VPC and other resources are applied.

That guide creates remote state before you apply shared infrastructure.

## Check

Run from `infra/terraform/`:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** the final pre-apply check. Confirms all four resources are in the plan with no errors.

Expected result: VPC plan succeeds showing 1 VPC and 3 subnets, no other resources.

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

