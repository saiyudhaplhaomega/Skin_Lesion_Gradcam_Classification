# Rollback Procedures

**Step-by-step procedures for recovering from failures in the Skin Lesion Analysis Platform**

---

## Overview

This document covers all rollback scenarios from minor issues to full disaster recovery. Each section includes decision criteria, step-by-step instructions, and verification steps.

---

## Quick Reference Decision Tree

```
Did a deployment just happen?
├── YES → Check deployment section
│   ├── ECS tasks failing → Rollback ECS image
│   ├── Model not loading → Rollback model version
│   └── Config change issue → Revert environment vars
└── NO → Check other sections
    ├── Database issue → Database rollback
    ├── Infrastructure issue → Infrastructure rollback
    └── Security incident → Incident response (separate runbook)
```

---

## 1. ECS Deployment Rollback

### When to Use

- ECS tasks failing health checks after deployment
- Application errors increasing after deployment
- Need to revert to previous Docker image

### Pre-Rollback Checklist

- [ ] Confirm current deployment timestamp
- [ ] Note any user-impacting issues
- [ ] Identify previous working image tag
- [ ] Notify stakeholders of rollback

### Step-by-Step

**Option A: Rollback to Previous Image (GitHub Actions)**

```bash
# 1. Find previous image tag
aws ecr list-images --repository-name skin-lesion-backend | grep staging-latest

# 2. Tag previous image as new production
aws ecr put-image --repository-name skin-lesion-backend \
  --image-tag prod-$(date +%Y%m%d%H%M) \
  --image-manifest "$(aws ecr describe-images --repository-name skin-lesion-backend --image-tag staging-latest --query 'imageManifest' --output text)"

# 3. Force new deployment (uses latest prod tag)
aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --force-new-deployment
```

**Option B: Rollback via Task Definition**

```bash
# 1. List task definition revisions
aws ecs list-task-definitions --family-prefix skin-lesion-backend --sort DESC

# 2. Get previous revision number
aws ecs describe-task-definition --task-definition skin-lesion-backend:15

# 3. Register new revision using old image
aws ecs register-task-definition \
  --family skin-lesion-backend \
  --container-definitions "[{
    \"name\": \"backend\",
    \"image\": \"123456789.dkr.ecr.us-east-1.amazonaws.com/skin-lesion-backend:prev-stable-tag\",
    \"essential\": true,
    \"portMappings\": [{\"containerPort\": 8080}],
    \"logConfiguration\": {
      \"logDriver\": \"awslogs\",
      \"options\": {
        \"awslogs-group\": \"/ecs/skin-lesion-prod\",
        \"awslogs-region\": \"us-east-1\"
      }
    }
  }]"

# 4. Update service to use new revision
aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --task-definition skin-lesion-backend:NEW_REVISION
```

### Verification

```bash
# 1. Wait for tasks to stabilize
aws ecs wait services-stable \
  --cluster skin-lesion-prod \
  --services skin-lesion-backend

# 2. Check task status
aws ecs describe-services \
  --cluster skin-lesion-prod \
  --services skin-lesion-backend

# 3. Run health check
curl -f https://api.skinlesion.com/api/v1/health

# 4. Check error rate in CloudWatch
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name HTTPCode_Target_5XX_Count \
  --period 300 \
  --statistics Sum \
  --start-time $(date -u -d '1 hour ago') \
  --end-time $(date -u)
```

### Post-Rollback Actions

- [ ] Verify error rates back to baseline
- [ ] Notify stakeholders rollback complete
- [ ] Document what went wrong
- [ ] Schedule post-mortem if major incident

---

## 2. Model Rollback

### When to Use

- New model causing incorrect predictions
- Model performance metrics below threshold
- Model fails to load in production

### Pre-Rollback Checklist

- [ ] Confirm which version is currently production
- [ ] Verify previous version exists in MLflow
- [ ] Note affected users (if any prediction errors)
- [ ] Check model performance difference

### Step-by-Step

**Step 1: Identify Current and Previous Versions**

```python
# Using MLflow CLI
mlflow models list-versions --name skin-lesion

# Output shows all versions with stages
# Name: skin-lesion
# Version | Stage     | Status   | Description
# 12      | Production| READY    | Current production
# 11      | Staging   | READY    | Previous version
# 10      | Archived  | READY    | Older version
```

**Step 2: Demote Current and Promote Previous**

```python
import mlflow
from mlflow.tracking import MlflowClient

client = MlflowClient()

# Get current production version
current_prod = client.get_latest_version("skin-lesion", stage="Production")

# Demote to Staging
client.transition_model_version_stage(
    name="skin-lesion",
    version=current_prod.version,
    stage="Staging"
)

# Get previous version (assuming version 11)
previous = client.get_model_version("skin-lesion", version=11)

# Promote to Production
client.transition_model_version_stage(
    name="skin-lesion",
    version=11,
    stage="Production"
)

print(f"Rolled back from v{current_prod.version} to v{previous.version}")
```

**Step 3: Update ECS to Load Previous Model**

```bash
# Set environment variable to load previous version
# Edit ECS task definition to set MODEL_VERSION=v11

aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --force-new-deployment
```

### Alternative: S3 Direct Rollback

```bash
# If MLflow is unavailable, roll back S3 directly

# 1. List archived models
aws s3 ls s3://skin-lesion-models-PROD/archived/

# 2. Copy archived model to production
aws s3 cp s3://skin-lesion-models-PROD/archived/resnet50_v1.x.pth \
          s3://skin-lesion-models-PROD/production/resnet50_v1.x.pth

# 3. Restart ECS to pick up new model
aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --force-new-deployment
```

### Verification

```bash
# 1. Check model version in logs
aws logs tail /ecs/skin-lesion-prod --filter-pattern "Model loaded"

# 2. Run test prediction
curl -X POST https://api.skinlesion.com/api/v1/predict \
  -H "Authorization: Bearer $TOKEN" \
  -F "image=@test_image.jpg"

# 3. Compare prediction confidence to baseline
# If significantly different, may indicate wrong model loaded
```

---

## 3. Database Rollback (Point-in-Time Recovery)

### When to Use

- Data corruption from application bug
- Accidental data deletion
- Schema migration failure

### Warning

**Point-in-time recovery affects ALL data since the restore point.** Only use when data loss is acceptable or when other rollback methods won't fix the issue.

### Pre-Rollback Checklist

- [ ] Identify exact time to restore to
- [ ] Verify RDS backup window covers that time
- [ ] Notify users of potential data loss
- [ ] Create final backup of current state (snapshot)
- [ ] Document reason for restore

### Step-by-Step

```bash
# 1. Create snapshot of current state (safety)
aws rds create-db-snapshot \
  --db-instance-identifier skin-lesion-prod \
  --snapshot-identifier pre-rollback-$(date +%Y%m%d%H%M)

# 2. Initiate point-in-time restore
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier skin-lesion-prod \
  --target-db-instance-identifier skin-lesion-prod-restored \
  --restore-time 2024-01-15T10:30:00Z \
  --db-instance-class db.t3.medium

# 3. Wait for restore to complete (15-30 minutes)
aws rds wait db-instance-available \
  --db-instance-identifier skin-lesion-prod-restored

# 4. Update application to point to restored instance
# Modify DATABASE_URL in Secrets Manager

# 5. Verify data integrity
aws rds describe-db-instances \
  --db-instance-identifier skin-lesion-prod-restored \
  --query 'DBInstances[0].Endpoint'
```

### Post-Restore (Production Cutover)

```bash
# 1. Test on restored instance
psql -h skin-lesion-prod-restored.xxxxxxxxx.us-east-1.rds.amazonaws.com \
  -U skinlesionadmin -d skinlesion

# 2. If satisfied, promote restored to production
# Rename instances (requires maintenance window)

# Or: Export/Import specific tables if full restore not needed
pg_dump -h skin-lesion-prod-restored -U skinlesionadmin -d skinlesion > backup.sql
psql -h skin-lesion-prod -U skinlesionadmin -d skinlesion < backup.sql
```

### Verification

```sql
-- Check key tables have expected data
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM predictions WHERE created_at > '2024-01-15';
SELECT MAX(created_at) FROM training_cases;
```

---

## 4. Infrastructure Rollback

### When to Use

- Terraform changes broke networking
- Security group changes locked out access
- New VPC configuration causes connectivity issues

### Rollback via Terraform

```bash
# 1. Check current state
cd infra/terraform

# 2. List Terraform states
aws s3 ls terraform-state-skinlesion/

# 3. Get previous state version
aws s3 cp s3://terraform-state-skinlesion/terraform.tfstate ./terraform.tfstate.backup

# 4. Rollback state file
aws s3 cp s3://terraform-state-skinlesion/terraform.tfstate.2024-01-15 \
           s3://terraform-state-skinlesion/terraform.tfstate

# 5. Plan and review changes
terraform plan

# 6. Apply (reverts infrastructure)
terraform apply
```

### Critical Infrastructure: What NOT to Rollback

| Component | Risk | Action |
|-----------|------|--------|
| RDS | Data loss | Do not destroy, only modify |
| VPC | Breaks everything | Be extremely careful |
| IAM Roles | Lockout risk | Do not delete, only rename |

---

## 5. Frontend Rollback

### When to Use

- Vercel deployment causing issues
- JavaScript errors in production
- Breaking changes not caught in staging

### Step-by-Step (Vercel)

```bash
# 1. List deployments
vercel list

# 2. Get previous deployment URL
vercel rollback [deployment-url]

# Or via Dashboard:
# 1. Go to Vercel Dashboard > Your Project > Deployments
# 2. Find last working deployment
# 3. Click "..." > "Promote to Production"
```

### Disable Auto-Deployment

```bash
# Temporarily disable auto-deploy
vercel project settting --disable-automatic-views

# After fix, re-enable
vercel project settting --enable-automatic-views
```

---

## 6. S3 Data Rollback

### When to Use

- Training data accidentally deleted
- Approved images removed
- Need to recover previous training pool

### Step-by-Step

```bash
# 1. Check S3 versioning is enabled (restore from previous version)
aws s3api get-bucket-versioning --bucket skin-lesion-training-PROD

# 2. List object versions
aws s3api list-object-versions \
  --bucket skin-lesion-training-PROD \
  --prefix "approved/2024/01/"

# 3. Restore specific object
aws s3api copy-object \
  --bucket skin-lesion-training-PROD \
  --copy-source "skin-lesion-training-PROD/approved/2024/01/15/case123.jpg?versionId=abc123" \
  --key "approved/2024/01/15/case123.jpg"

# 4. Or restore entire prefix from previous version
# Use S3 inventory + cross-account copy for disaster recovery
```

---

## 7. Rollback Communication Template

Use this template for stakeholder communication:

```
SUBJECT: [INCIDENT] Service Rollback Initiated - [TIME]

Hi Team,

We have identified an issue with the [new deployment/model/config] that is
impacting [users/predictions/system]. 

We are rolling back to the previous known-good state while we investigate.

IMPACT:
- Duration: ~15-30 minutes
- Users may need to re-authenticate
- In-progress predictions may need to be resubmitted

CURRENT STATUS:
- Root cause: [if known]
- Affected users: [number or estimate]
- Rollback ETA: [time]

We will update when the rollback is complete and provide a full
post-mortem within 48 hours.

Thank you for your patience.

- [On-Call Name]
```

---

## 8. Post-Rollback Actions

| Action | Owner | Due |
|--------|-------|-----|
| Document root cause | Tech Lead | 24h |
| Update runbook if procedure needs fixing | DevOps | 48h |
| Schedule post-mortem | PM | 48h |
| Notify users of resolution | Support | Before close |
| Update monitoring alerts | DevOps | 48h |
| Close incident ticket | On-Call | 24h |

---

## Escalation Matrix

| Severity | Response Time | Escalation |
|----------|---------------|------------|
| Minor (no user impact) | 1 hour | On-call only |
| Moderate (limited user impact) | 30 min | On-call → Tech Lead |
| Major (service degraded) | 15 min | On-call → Tech Lead → CTO |
| Critical (service down) | 5 min | On-call → Tech Lead → CTO → CEO |

---

## Emergency Contacts

| Role | Name | Phone | Email |
|------|------|-------|-------|
| On-Call Primary | | | |
| On-Call Secondary | | | |
| AWS Support | Enterprise Support | 1-800-000-0000 | support@aws.amazon.com |
| DevOps Lead | | | |
| CTO | | | |