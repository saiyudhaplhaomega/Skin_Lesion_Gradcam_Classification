# Terraform Learning Area

This folder is for Terraform learning.

The root `main.tf` has been removed on purpose so you can build from scratch.

For beginner learning, start with the guide:

```text
docs/04_TERRAFORM_FROM_EMPTY_MAIN.md
```

## Why You Should Not Start With A Full `main.tf`

A large `main.tf` that creates many services at once is hard to learn from. It also creates errors for resources you have not studied yet.

The learning path is:

```text
scratch folder -> provider block -> validate -> one resource -> plan -> understand -> maybe apply
```

## What To Do First

From the repo root, create or use:

```text
infra/terraform/
```

Then check Terraform:

```powershell
terraform version
```

If Terraform is installed, continue with the guide.

If Terraform is not installed, install it before writing any `.tf` files.

## Module Folders

Module folders may exist as reference material.

Do not wire or apply modules until a guide tells you:

1. what the module does
2. why you need it
3. what it will cost
4. what command checks it
5. what the expected Terraform plan should roughly show

## Safe Terraform Loop

Use this loop for every small change:

```powershell
terraform fmt
terraform validate
terraform plan
```

Do not run:

```powershell
terraform apply
```

until you understand the plan output.

## Build Order For Cloud Infrastructure

Build later in this order:

1. provider only
2. one S3 bucket for learning
3. VPC
4. ECR
5. local Docker image pushed to ECR
6. Kubernetes local
7. EKS dev
8. database
9. SQS/EventBridge
10. monitoring
11. CI/CD

This order keeps cloud errors small and understandable.
