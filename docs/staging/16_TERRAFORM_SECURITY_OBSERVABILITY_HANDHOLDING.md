# Terraform Security And Observability Handholding Guide

Use this after the app can run in a staging-like environment.

This guide integrates the ideas from the old `cloudwatch-alarms`, `vpc-flow-logs`, `cloudtrail`, `guardduty`, `waf`, and `cognito` modules.

## Current Project Implementation

Guide 16 now has a Terraform baseline, with costly controls gated by variables.

Files created or edited:

```text
infra/terraform/security_observability.tf
infra/terraform/variables.tf
infra/terraform/env/staging.tfvars
infra/terraform/outputs.tf
```

Implemented now:

```text
CloudWatch alarms for training queue depth and DLQ depth
Optional VPC Flow Logs resources behind enable_security_observability
Optional alert email SNS subscription behind enable_security_observability
Optional GuardDuty detector and high-severity SNS rule behind enable_guardduty
```

Still intentionally gated:

```text
CloudTrail full trail and bucket policy
WAF attached to the internet-facing ALB
Cognito user pools
```

Why: those controls need either live AWS identity, an ALB ARN, or a real alert recipient. I will ask before enabling them because they can create ongoing charges or require console/SSO confirmation.

## Command Location

Run commands from the main workspace first:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the workspace root. AWS CLI checks for CloudTrail and GuardDuty run from here.

Then run Terraform commands from:

```text
infra/terraform
```

**What this means:** `cd infra/terraform` before any `terraform` command. Security resources (WAF, GuardDuty, CloudTrail) are created as Terraform resources in this directory.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Create or edit CloudWatch, VPC Flow Logs, CloudTrail, GuardDuty, WAF, and Cognito Terraform resources under `infra/terraform/`.
- Do not create backend or frontend application files in this guide unless a later step explicitly gives an app path.

## Goal

Add security and observability in layers:

```text
logs -> alarms -> audit trail -> threat detection -> WAF -> auth provider
```

**What this order means:** each layer builds on the one before it. Logs come first so you have data to alarm on. Alarms come before audit trails because you need to know when something is wrong before investigating what happened. Threat detection (GuardDuty) reads VPC flow logs and CloudTrail, so both must exist first. WAF is added only after there is an internet-facing load balancer to protect. Auth provider (Cognito) is last because the backend role rules must be working before adding an external identity layer.

Do not add every control before the app exists. Each control should have a check and an owner.

## Parameters You Must Set First

```text
ENVIRONMENT=staging
ALERT_EMAIL=you@example.com
LOG_RETENTION_DAYS=30
WAF_RATE_LIMIT=1000
PATIENT_USER_POOL=skin-lesion-patients-staging
DOCTOR_USER_POOL=skin-lesion-doctors-staging
ENABLE_SECURITY_OBSERVABILITY=false until you intentionally enable paid/staging controls
ENABLE_GUARDDUTY=false until you intentionally enable GuardDuty
```

**What these parameters mean:**

- `ALERT_EMAIL` - the email address that receives SNS alarm notifications. CloudWatch alarm state changes and GuardDuty high-severity findings are sent here.
- `LOG_RETENTION_DAYS=30` - CloudWatch log groups delete logs older than 30 days automatically. Reduces storage costs compared to keeping logs indefinitely.
- `WAF_RATE_LIMIT=1000` - the maximum number of requests per 5-minute window from a single IP before WAF blocks it. 1000 is a reasonable starting point for staging - adjust based on observed legitimate traffic patterns.
- `PATIENT_USER_POOL` / `DOCTOR_USER_POOL` - separate Cognito user pools for patients and clinical staff. Separate pools because the self-registration flow, password policy, and MFA requirements differ between the two groups.

**Where these parameters are saved:** this guide is for the staging environment, so the values go into the staging Terraform variable file `infra/terraform/env/staging.tfvars` (not `dev.tfvars`). The corresponding `variable` blocks (the declarations that receive these values) must be added to `infra/terraform/variables.tf` first — same pattern as guide 05 Step 0 created 5 dev variables. The security and observability values are *staging-only* and do not exist in the current `variables.tf` (which has only dev variables). Do not put staging values in `dev.tfvars`. The `ALERT_EMAIL` value is a real address — keep it in `staging.tfvars` only and do not commit a real personal email if the repo is public.

**Before editing `variables.tf` and `staging.tfvars`:** verify guide 05 Step 0 created `infra/terraform/variables.tf` and `infra/terraform/env/dev.tfvars` already. If those files do not exist, go back and complete guide 05 first.

## Step 1: VPC Flow Logs

Add:

```text
CloudWatch log group
VPC flow log for the app VPC
30-day retention for staging
```

**What these resources do:** the CloudWatch log group is the destination for VPC flow log records. VPC flow logs record metadata about every accepted and rejected network connection in the VPC (source IP, destination IP, port, protocol, bytes, action). This is essential for debugging connectivity issues and investigating security events. 30-day retention balances cost with enough history to investigate an incident.

Check:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
terraform plan -var-file="env/staging.tfvars"
```

**What this does:** previews the CloudWatch log group and VPC flow log resource. The plan should show exactly two new resources at this step.

Expected result:

```text
Terraform plans one log group and one VPC flow log.
```

**What this means:** both resources appear in the plan. No extra resources were accidentally added.

Why: flow logs help debug networking before production.

## Step 2: CloudWatch Alarms

Start with alarms that do not trigger auto-remediation:

```text
API 5xx count
high latency
database CPU
database connections
queue depth
failed worker messages
```

**What these alarms watch:** `API 5xx count` detects backend errors (application crashes, unhandled exceptions). `high latency` detects slow responses that indicate database slowness or CPU saturation. `database CPU` and `database connections` detect database overload before queries start failing. `queue depth` detects SQS message backlog - rising count means the worker is not keeping up. `failed worker messages` alerts when messages go to the DLQ.

Use SNS for notifications.

Do not attach auto-heal or auto-rollback Lambda actions yet.

Current repo alarms:

```text
aws_cloudwatch_metric_alarm.training_queue_depth
aws_cloudwatch_metric_alarm.training_dlq_depth
```

Why: the training workflow now has a queue and DLQ in Terraform, so queue backlog is the first concrete reliability signal to alarm on.

## Step 3: CloudTrail

Add:

```text
multi-region trail
log file validation
encrypted S3 log bucket
critical event rule
SNS alert target
```

**What these CloudTrail settings do:** `multi-region trail` records API calls across all regions, not just the primary one - important because attackers often use less-monitored regions. `log file validation` uses hash digests to detect if a log file was tampered with after delivery. `encrypted S3 log bucket` protects the audit log contents at rest. `critical event rule` is an EventBridge rule that triggers an SNS alert when a high-risk API call is made.

Critical events:

```text
PutBucketPolicy
DeleteBucket
AttachUserPolicy
CreateUser
PutRolePolicy
ConsoleLogin
```

**What these events mean:** each one represents a control-plane change that could open a security hole. `PutBucketPolicy` and `DeleteBucket` can expose or destroy data. `AttachUserPolicy`, `CreateUser`, and `PutRolePolicy` can escalate privileges. `ConsoleLogin` tracks human access to the AWS console - useful for detecting unauthorized logins.

Why: production-style environments need an audit trail for control-plane changes.

## Step 4: GuardDuty

Add:

```text
GuardDuty detector
S3 protection where available
EventBridge rule for high-severity findings
SNS notification target
```

**What these GuardDuty resources do:** the GuardDuty detector analyzes VPC flow logs, CloudTrail events, and DNS logs for threat patterns (crypto-mining, port scanning, unusual API calls, credential misuse). S3 protection adds analysis of S3 data access events. The EventBridge rule triggers when a finding is severity 7 or higher (high severity), and the SNS target sends the alert to the notification topic.

Cost note:

```text
GuardDuty can create ongoing charges. Enable it intentionally and include it in the shutdown checklist for learning accounts.
```

**What this means:** GuardDuty charges based on the volume of CloudTrail events and VPC flow logs it analyzes. For a dev learning account with low traffic this is small (a few dollars per month), but it accumulates. Add `aws guardduty disable-detector` to the daily shutdown checklist if cost is a concern.

Current repo setting:

```text
enable_guardduty = false
```

Change it only in `infra/terraform/env/staging.tfvars` after reviewing the plan and confirming cost.

## Step 5: WAF

Add WAF only after an internet-facing ALB/API exists.

Start with:

```text
rate limit
SQL injection match
XSS match
sampled request visibility
CloudWatch metrics
```

**What these WAF rules do:** `rate limit` blocks IPs that send more than `WAF_RATE_LIMIT` requests per 5 minutes - protects against brute force and basic DDoS. `SQL injection match` detects common SQL injection patterns in request bodies, query strings, and headers. `XSS match` detects cross-site scripting payloads. `sampled request visibility` logs a sample of matched requests for investigation without storing all traffic. `CloudWatch metrics` lets you create alarms on WAF block counts.

Do not tune medical/product behavior in WAF. WAF is perimeter protection, not app authorization.

## Step 6: Cognito

Add Cognito after native role rules exist in the backend.

Model:

```text
patient pool: self-service user account path
doctor/admin pool or groups: stricter access, MFA, approval workflow
identity pool: later, only if browser/mobile needs AWS credentials
```

**What these Cognito pools mean:** the patient pool allows self-registration - patients sign up with their email and set their own password. The doctor/admin pool uses stricter controls: MFA is required, accounts are created by admins (not self-service), and access requires an approval step. The identity pool is for federated access to AWS services directly from the browser or mobile app - only needed if the mobile app uploads files directly to S3 using temporary AWS credentials, not needed if uploads go through the backend API.

For this app, keep backend authorization as the source of truth. Cognito authenticates; backend permissions enforce access.

## Checks

Run:

```powershell
terraform fmt
terraform validate
terraform plan
```

**What these commands do:** `terraform fmt` normalizes formatting. `terraform validate` checks all resource references. `terraform plan` shows the full set of security and observability resources to be created - review this carefully before applying because some resources (GuardDuty, WAF) have ongoing costs.

Expected result:

```text
security and observability resources are added one category at a time, with no auto-remediation yet.
```

**What this means:** each resource category was added in a separate step with a plan check. No Lambda auto-remediation or EventBridge auto-rollback rules are in the plan - those come after the monitoring baseline is proven to work correctly.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:** `make cloud-status ENV=dev` reports running dev resources. `make cloud-pause ENV=dev` scales pods to zero. `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys all dev cloud resources - GuardDuty, WAF, and CloudTrail charges stop once their resources are destroyed.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:** `make cloud-start ENV=dev` recreates or resumes the dev environment. `make cloud-status ENV=dev` confirms it is healthy before continuing.

If this guide was local-only, no cloud shutdown is needed.
