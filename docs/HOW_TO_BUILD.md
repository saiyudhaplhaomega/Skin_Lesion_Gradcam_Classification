# How to Build This Platform - Navigation Guide

This is the one doc to keep open while building. It tells you what to read, what to build, what to check before moving on, and where to find the details.

---

## How the Docs Are Organized

Every doc has a job. Here is what to use each one for:

| Doc | When to Open It | What It Does |
|-----|----------------|--------------|
| **This file** | Always | Navigation map - tells you where to go |
| `ARCHITECTURE.md` | Before each phase, and when confused about design | Full system design + Section 15 has 28 critical questions organized by engineer type |
| `SYSTEM_DESIGN_LEARNING_GUIDE.md` | When learning architecture decisions | Q&A for why each major choice was made and what alternatives were rejected |
| `BUILD_PHASE_1_INFRASTRUCTURE.md` | Phase 1 only | Terraform setup, module-by-module guide |
| `BUILD_PHASE_2_BACKEND.md` | Phase 2 only | FastAPI implementation, all steps + AI/Data engineer patterns |
| `BUILD_PHASE_3_FRONTEND.md` | Phase 3 only | Next.js implementation, role-specific UI specs |
| `BUILD_PHASE_4_MOBILE.md` | Phase 4 only | React Native / Expo setup |
| `BUILD_PHASE_5_CICD.md` | Phase 5 only | GitHub Actions, ECS deploy, MLflow |
| `DEVELOPMENT_CHECKLIST.md` | Every day | Your live task tracker - check boxes as you go |
| `SECURITY_CHECKLIST.md` | Before launch | Security sign-off, do this before going live |
| `TROUBLESHOOTING.md` | When something breaks | Error lookup table |
| `ROLLBACK_PROCEDURES.md` | When you need to undo a deployment | Step-by-step rollback for each component |
| `GDPR_COMPLIANCE.md` | Phase 2 consent endpoint, and pre-launch | Data handling rules you must follow |
| `PRODUCTION_BUILD_REVIEW.md` | Before planning each sprint | Current implementation gaps, corrected build order, and snippet quality notes |

---

## Current Repo Reality

Before building, separate what exists from what is still planned:

| Area | Current state | Next learning target |
|------|---------------|----------------------|
| Backend | ML utilities exist, but the FastAPI app is not implemented | Build a minimal `GET /health` and `POST /predict` first |
| Frontend | Next.js scaffold exists | Build the patient upload and prediction flow before dashboards |
| Research | RQ notebooks and outputs live in `Skin_Lesion_XAI_research` | Keep research notebooks out of the frontend app |
| Infrastructure | Foundation Terraform modules exist | Add missing runtime modules before production deploy |
| Mobile | No Expo app yet | Build mobile after the web API contract is stable |
| CI/CD | Docs exist, workflows do not | Add CI checks before deployment workflows |

Open `docs/PRODUCTION_BUILD_REVIEW.md` before starting a phase. It lists what is implemented, what is missing, and which guide snippets need extra care.

---

## The Build Order

Build in this exact sequence. Each phase has hard dependencies on the previous one.

```
Phase 0: Answer the pre-build questions  ← START HERE
    ↓
Phase 1: Infrastructure (Terraform)      ← AWS resources, 2-3 days
    ↓
Phase 2: Backend (FastAPI)               ← API, ML serving, 5-7 days
    ↓
Phase 3: Frontend (Next.js)              ← Web UI per role, 5-7 days
    ↓
Phase 4: Mobile (React Native/Expo)      ← Mobile app, 5-7 days
    ↓
Phase 5: CI/CD + MLflow                  ← Automated deploy, 3-5 days
    ↓
Phase 6: Testing + Launch prep           ← Load test, security audit, 3-5 days
```

---

## Phase 0: Answer These Before Writing Any Code

These are decisions that are very expensive to change after the fact. Do not skip this.

Open `ARCHITECTURE.md` Section 15 and work through the three checklists. The ones you must answer before Phase 1 are:

**Infrastructure decisions (answer before `make apply`):**
- [ ] Which AWS region? Lock this in - changing it later means destroying everything.
- [ ] Do you want a dev environment (cheap, single-AZ, t3.micro RDS) separate from prod? You should.
- [ ] How will the MLflow server run? It needs its own ECS service and RDS. Plan the Terraform module now.
- [ ] Where do admin users come from? They should not be Cognito self-register. Plan IAM Identity Center or a manual DB seed.

**Backend decisions (answer before writing Python):**
- [ ] Shared Redis is provisioned (ElastiCache). Without this, multiple ECS tasks break `/explain`.
- [ ] What is the defined schema for `patient_demographics` JSONB? Write it down once now.
- [ ] Have you planned the SQS queues for the training pipeline? (consent-events → doctor-validation → admin-approval → s3-write)

**ML/AI decisions (answer before wiring up MLflow):**
- [ ] Do you have a frozen HAM10000 test split that will never be used for training? This is your regression guard.
- [ ] What is the minimum samples-per-class threshold before triggering retraining? Default: 300.
- [ ] Will you run two CAM methods for disagreement scoring at inference time? (Recommended: yes. GradCAM + EigenCAM)

---

## Phase 1: Infrastructure

**Start here:** `docs/BUILD_PHASE_1_INFRASTRUCTURE.md` - read the "Before You Apply" section at the top first.

**What you're building:**
- VPC with 3 subnets (Public for ALB, App for ECS, Data for RDS/Redis)
- RDS PostgreSQL (Multi-AZ in prod, single in dev)
- ElastiCache Redis (shared predictions store - this is not optional)
- S3 buckets (models, training, MLflow artifacts)
- Cognito user pools (patient + doctor)
- ECR repository for Docker images
- GuardDuty, CloudTrail, WAF, KMS
- SQS queues for training pipeline (new - not in current Terraform)

**Before you move to Phase 2, verify all of these:**

```bash
# 1. VPC exists with correct subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id)"
# Expect: subnets tagged public, app, data

# 2. RDS is available
aws rds describe-db-instances --db-instance-identifier skin-lesion-dev \
  --query 'DBInstances[0].DBInstanceStatus'
# Expect: "available"

# 3. ElastiCache is available
aws elasticache describe-replication-groups \
  --query 'ReplicationGroups[0].Status'
# Expect: "available"

# 4. S3 buckets exist
aws s3 ls | grep skin-lesion
# Expect: models bucket, training bucket, mlflow-artifacts bucket

# 5. Cognito pools exist
aws cognito-idp list-user-pools --max-results 10 \
  --query 'UserPools[?contains(Name, `skin-lesion`)].Name'
# Expect: patient pool and doctor pool

# 6. SQS queues exist
aws sqs list-queues --queue-name-prefix skin-lesion
# Expect: consent-events-queue, validation-queue, approval-queue + DLQs
```

**Do NOT proceed to Phase 2 if any of these fail.**

---

## Phase 2: Backend

**Start here:** `docs/BUILD_PHASE_2_BACKEND.md` - read the "Before You Build" checklist at the top.

**Build in this order inside the backend:**

```
Step 1:  Project structure (mkdir -p app/...)
Step 2:  requirements.txt + install
Step 3:  config.py (Settings with pydantic-settings)
Step 4:  Database models (User, Prediction, ExpertOpinion, TrainingCase, DeletionRequest)
Step 5:  Pydantic schemas
Step 6:  Database session (async SQLAlchemy)
Step 7:  Redis predictions store (Step 16A in the doc - use shared Redis, NOT in-memory)
Step 8:  JWT auth middleware (validate Cognito tokens)
Step 9:  /health endpoint (only returns 200 after model loads - see Step 16F)
Step 10: Model loader (loads from MLflow "Production" tag, fallback to S3)
Step 11: /predict endpoint (with circuit breaker - Step 16B)
Step 12: /explain endpoint (with Redis cache, timeout - Step 16B, 16C)
Step 13: /consent endpoint (idempotent - Step 17A)
Step 14: Expert opinions endpoint
Step 15: Admin endpoints (doctor approval, training pool)
Step 16: GDPR deletion endpoint (Step 17B)
Step 17: Docker + docker-compose local setup
Step 18: Tests
```

**Key things from the doc to not skip:**
- Step 16A: Redis store - multi-instance ECS safe
- Step 16B: Circuit breaker on both inference and CAM
- Step 16C: Temperature scaling (calibration) - must run after training
- Step 16D: CAM disagreement score - run GradCAM + EigenCAM, include in prediction response
- Step 17A: Idempotent consent - image goes to S3 at consent time, not at doctor validation
- Step 17C: Class distribution gate before retraining

**Before you move to Phase 3, verify all of these:**

```bash
# Run locally with docker-compose
docker-compose up --build

# Health check (model must be loaded)
curl http://localhost:8080/health
# Expect: {"status": "healthy", "model_version": "...", "device": "cpu"}

# Predict (use a test image)
curl -X POST http://localhost:8080/api/v1/predict \
  -F "image=@tests/fixtures/test_lesion.jpg"
# Expect: {"prediction_id": "...", "diagnosis": "...", "confidence": ..., "disagreement_score": ...}

# Explain (use the prediction_id from above)
curl -X POST http://localhost:8080/api/v1/explain \
  -H "Content-Type: application/json" \
  -d '{"prediction_id": "...", "method": "gradcam"}'
# Expect: {"heatmaps": {"original": "...", "overlay": "..."}, ...}

# Test Redis is shared (hit predict, then explain from a separate process)
# Both should work - if explain returns 404, Redis is not configured correctly

# Run tests
pytest tests/ -v --cov=app --cov-report=term-missing
# Expect: >70% coverage, all tests pass
```

---

## Phase 3: Frontend

**Start here:** `docs/BUILD_PHASE_3_FRONTEND.md` - read the "Before You Build" section at the top.

**Build in this order inside the frontend:**

```
Step 1:  Create Next.js project + install deps
Step 2:  Project structure (app/(auth), app/(dashboard)/patient, doctor, admin)
Step 3:  Type definitions (types/index.ts)
Step 4:  API client (lib/api.ts) - with getAuthHeaders() using Amplify fetchAuthSession()
Step 5:  AuthContext + token refresh (lib/auth.ts - see role-specific UI specs section)
Step 6:  Login page
Step 7:  Register page (patient and doctor flows, separate forms)
Step 8:  Route protection middleware (middleware.ts)
Step 9:  Patient dashboard:
           - ImageUploader component
           - PredictionResultCard (with confidence labels, NOT raw floats)
           - HeatmapViewer (with loading skeleton)
           - ConsentCheckbox (opt-in only, with demographics fields)
           - PredictionHistory
Step 10: Doctor dashboard:
           - CaseReviewQueue (paginated, 20/page)
           - CaseReviewModal (with keyboard shortcuts)
           - ExpertOpinionForm
Step 11: Admin dashboard:
           - SystemStatusCards
           - DoctorApprovalPanel
           - TrainingPoolManager (with class distribution chart)
           - ModelPromotionPanel
Step 12: Error boundaries + loading skeletons
Step 13: Type check + lint pass
```

**Key things from the doc to not skip:**
- `lib/auth.ts` getAuthHeaders(): must use Amplify `fetchAuthSession()` - do not manage tokens manually
- Confidence display: map floats to "High/Moderate/Low" labels - never show raw `0.874`
- Disagreement score display: map to human text - never show raw `0.62`
- ConsentCheckbox: unchecked by default, always
- Doctor dashboard: keyboard shortcuts for efficiency (1-7 for diagnosis, Enter to submit)
- Token refresh: implement before any dashboard - doctors have long sessions

**Before you move to Phase 4, verify all of these:**

```bash
# Start both backend and frontend
docker-compose up --build   # backend
cd Skin_Lesion_Classification_frontend && npm run dev  # frontend

# Manual test: patient flow
# 1. Register as patient → verify email → login
# 2. Upload a test image → see prediction result
# 3. Click "View AI Explanation" → see heatmap (loading skeleton should show first)
# 4. Check confidence label is "High/Moderate/Low", not a decimal
# 5. Check consent checkbox is unchecked by default
# 6. Consent → fill optional demographics → submit
# 7. Logout → try accessing /patient → should redirect to /login

# Manual test: doctor flow (use admin to approve a doctor first)
# 1. Register as doctor → admin approves → login
# 2. See pending cases queue
# 3. Click Review on a case → see image, heatmap, AI prediction
# 4. Submit expert opinion
# 5. Check case disappears from pending queue

# Manual test: admin flow
# 1. Login as admin
# 2. See pending doctor approval → approve a doctor
# 3. See training pool stats
# 4. See "Trigger Retraining" button is disabled if < 5000 cases

# Type check (must pass clean)
npm run type-check

# Lint (must pass clean)
npm run lint
```

---

## Phase 4: Mobile

**Start here:** `docs/BUILD_PHASE_4_MOBILE.md`

**What to build:** Patient, doctor, and admin screens in React Native / Expo.

The mobile app is feature-identical to the web app (same API, same auth, same role routing) but optimized for camera-based uploads on mobile. The main structural difference is:
- Tab navigation instead of sidebar
- Camera permissions for direct photo capture
- Secure token storage (`expo-secure-store`, not localStorage)

**Before moving to Phase 5:**
- Test on both iOS simulator and Android emulator
- Test camera permission flow
- Test token persistence across app restart
- EAS build succeeds for both platforms

---

## Phase 5: CI/CD + MLflow

**Start here:** `docs/BUILD_PHASE_5_CICD.md`

**Build in this order:**

```
Step 1:  GitHub Actions CI workflow (lint, test, type-check on every PR)
Step 2:  Docker build + ECR push workflow (on merge to main)
Step 3:  ECS deploy workflow (rolling deployment, waits for healthy)
Step 4:  Vercel deploy workflow (automatic via Vercel GitHub integration)
Step 5:  MLflow server deployment (ECS service in data subnet, RDS backend)
Step 6:  Model promotion workflow (train script → evaluate → notify admin)
Step 7:  Quarterly retrain cron (GitHub Actions scheduled workflow)
Step 8:  CloudWatch alarms (error rate, latency P99, ECS CPU/memory)
```

**Key questions to answer before this phase (from ARCHITECTURE.md Section 15):**
- What is your ECS health check grace period? Must be 120s minimum (model load time).
- What is the MLflow server URL and how do ECS tasks reach it? (private DNS, VPC internal)
- Is the rollback script atomic? (updates both S3 model path AND MLflow version tag together)

**Before launch, verify:**

```bash
# CI passes on a test PR
# (open a branch, make a trivial change, open PR, watch Actions tab)

# ECS deployment rolls out cleanly
aws ecs describe-services --cluster skin-lesion-prod \
  --services skin-lesion-backend \
  --query 'services[0].deployments'
# Expect: one deployment with status "PRIMARY" and desired == running count

# MLflow UI accessible (via bastion or VPN)
curl http://mlflow.internal:5001/health
# Expect: 200

# Model loaded in production
curl https://your-alb-dns/health
# Expect: {"status": "healthy", "model_version": "v1.0", ...}

# CloudWatch alarms exist
aws cloudwatch describe-alarms --query 'MetricAlarms[*].AlarmName'
# Expect: alarms for ECS CPU, memory, ALB 5xx rate, RDS connections
```

---

## Phase 6: Before Launch

**Open `docs/SECURITY_CHECKLIST.md` and go through it line by line.**

Also do these:
- Load test with k6 or Locust (simulate 100 concurrent predictions)
- Test rollback procedure end-to-end (deploy a bad version, roll it back, verify)
- Test GDPR export endpoint
- Test GDPR deletion endpoint (verify image is removed from S3)
- Verify consent withdrawal works and actually deletes data within the SLA window
- Have a doctor review 5 real cases and give you feedback on the review UI

---

## When You're Stuck - Where to Look

| Problem | Where to look |
|---------|--------------|
| "What does this design decision mean?" | `ARCHITECTURE.md` - the relevant numbered section |
| "A senior architect would ask what about X?" | `ARCHITECTURE.md` Section 15A |
| "A data engineer would ask what about X?" | `ARCHITECTURE.md` Section 15B |
| "An AI engineer would ask what about X?" | `ARCHITECTURE.md` Section 15C |
| "I want to add a chatbot" | `ARCHITECTURE.md` Section 15D + `BUILD_PHASE_3_FRONTEND.md` (On Chatbots section) |
| "My deploy broke" | `ROLLBACK_PROCEDURES.md` |
| "Something is erroring" | `TROUBLESHOOTING.md` |
| "GDPR question" | `GDPR_COMPLIANCE.md` |
| "Security question" | `SECURITY_CHECKLIST.md` |
| "What's my next task?" | `DEVELOPMENT_CHECKLIST.md` |

---

## The 6 Things That Will Break in Production If You Don't Do Them

These are from `ARCHITECTURE.md` Section 15. They are not nice-to-haves.

1. **Provision ElastiCache before writing any backend code.** Without shared Redis, `/explain` randomly returns 404 when routed to a different ECS task than `/predict`.

2. **ECS tasks in App subnet, not public subnet.** Check the `aws_ecs_service` Terraform resource: `assign_public_ip = "DISABLED"`. Tasks with public IPs bypass the ALB and WAF entirely.

3. **SQS queues for the training pipeline.** Without queues, a failed S3 write during admin approval silently loses a training case with no retry. Add queues before building the consent/validation/approval endpoints.

4. **Persist image to S3 at consent time.** Redis TTL is 1 hour. Doctor validation can take hours or days. If you wait until doctor validation to write the image to S3, the Redis entry will be gone. The consent endpoint must write to S3 immediately.

5. **Idempotency on the consent endpoint.** A double-tap creates two training pipeline entries for the same image. Add `UNIQUE(prediction_id)` to `training_cases` and return 200 (not 201) on a duplicate.

6. **Health check grace period on ECS.** Model loads from S3 take 60-120 seconds. Without `health_check_grace_period_seconds = 120`, ECS will kill every task before it's ready and loop forever.

---

## Quick Reference: Which File Contains What

```
docs/
├── HOW_TO_BUILD.md          ← YOU ARE HERE - navigation guide
├── ARCHITECTURE.md          ← System design + 28 critical questions (Section 15)
├── BUILD_PHASE_1_INFRASTRUCTURE.md  ← Terraform, "Before You Apply" checklist
├── BUILD_PHASE_2_BACKEND.md ← FastAPI, Steps 16-17 have AI/Data engineer patterns
├── BUILD_PHASE_3_FRONTEND.md← Next.js, role UI specs + chatbot starter code
├── BUILD_PHASE_4_MOBILE.md  ← React Native / Expo
├── BUILD_PHASE_5_CICD.md    ← GitHub Actions, MLflow, CloudWatch
├── DEVELOPMENT_CHECKLIST.md ← Live task tracker, check boxes as you go
├── SECURITY_CHECKLIST.md    ← Do this before launch
├── GDPR_COMPLIANCE.md       ← Data handling rules
├── ROLLBACK_PROCEDURES.md   ← How to undo deployments
├── TROUBLESHOOTING.md       ← Error lookup
└── ENVIRONMENT_SETUP.md     ← Local dev setup
```
