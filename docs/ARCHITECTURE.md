# Complete Production Architecture: XAI Skin Lesion Analysis Platform

**Shippable, scalable, globally distributed medical AI application with human-in-the-loop learning**

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Architecture Diagram](#2-architecture-diagram)
3. [AWS Infrastructure](#3-aws-infrastructure)
4. [Authentication System](#4-authentication-system)
5. [User Roles & Permissions](#5-user-roles--permissions)
6. [Training Data Curation Pipeline](#6-training-data-curation-pipeline)
7. [API Architecture](#7-api-architecture)
8. [Error Handling](#8-error-handling)
9. [Rate Limiting](#9-rate-limiting)
10. [Rollback Procedures](#10-rollback-procedures)
11. [Mobile App Architecture](#11-mobile-app-architecture)
12. [CI/CD Pipeline](#12-cicd-pipeline)
13. [GDPR Compliance](#13-gdpr-compliance)
14. [Development Phases](#14-development-phases)

---

## 1. System Overview

### Core Application
A medical AI platform for skin lesion analysis that:
1. Allows patients to upload images and get AI predictions
2. Allows doctors to review cases and provide expert opinions
3. Uses Grad-CAM for explainable AI predictions
4. Uses human-in-the-loop curation for continuous model improvement
5. Pre-trained model on HAM10000 (10,015 images) deployed to production

### Training Data Curation Pipeline

**Key insight:** Real medical AI improves through curated, doctor-validated training data - not raw user submissions.

**Flow:**
```
Patient Upload → AI Prediction → User Consents → Doctor Validates → Admin Approves → Training Pool
                                                                           ↓
                                                              Batch Retrain (quarterly)
                                                                           ↓
                                                              Admin Promotes New Model
```

**Why this works:**
- Doctor validation = reliable ground truth labels
- Admin approval = quality gate for training data
- Batch retraining = efficient use of compute, meaningful model updates
- Storage costs bounded = 5,000-10,000 approved images max

### Target Users
| Role | Description | Access Level |
|------|-------------|--------------|
| Patient | Upload images, view predictions, consent to training | Public registration, own data only |
| Doctor | Review AI predictions, provide expert diagnoses | Verified, admin-approved |
| Admin | Approve doctors, manage training pool, promote models | Full system access |

### Technology Stack
```
Frontend (Web):     Next.js 14 → Vercel (Global CDN)
Mobile App:         React Native → Expo → iOS App Store / Google Play
Backend API:        FastAPI (Python 3.10) → AWS ECS Fargate
ML Pipeline:        PyTorch → MLflow → S3 (training pool only)
Authentication:     AWS Cognito (Patient/Doctor) + Custom Admin
Database:           PostgreSQL (RDS) - users, predictions, expert opinions
Storage:            S3 (model weights + curated training pool)
Infrastructure:     Terraform → VPC (private subnets) → ECS Fargate
CI/CD:              GitHub Actions → ECR → ECS
Monitoring:         CloudWatch → Sentry
```

---

## 2. Architecture Diagram

> **ARCHITECTURE NOTE (System Architect):** ECS tasks must run in the **App (private) subnet**, NOT the public subnet. Only the ALB lives in the public subnet. ECS tasks with public IPs are a direct attack surface. The original diagram had this wrong - the corrected version is below.

```
                                    ┌─────────────────────────────────────────┐
                                    │              Vercel CDN                 │
                                    │         (Next.js Frontend)              │
                                    │              :3000                       │
                                    └─────────────────┬───────────────────────┘
                                                      │ HTTPS
                                                      ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           AWS Global Network                                  │
│                                                                              │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                           VPC (10.0.0.0/16)                          │   │
│   │                                                                       │   │
│   │   ┌─────────────────────────────────────────────────────────────┐   │   │
│   │   │  Public Subnet - ALB ONLY (no ECS tasks here)              │   │   │
│   │   │  ┌──────────────────────────────────────────────────────┐  │   │   │
│   │   │  │         Application Load Balancer + WAF              │  │   │   │
│   │   │  └─────────────────────┬────────────────────────────────┘  │   │   │
│   │   └────────────────────────┼───────────────────────────────────┘   │   │
│   │                            │ HTTPS (private)                        │   │
│   │   ┌─────────────────────────────────────────────────────────────┐   │   │
│   │   │  App Subnet - ECS Tasks (PRIVATE, egress via NAT)          │   │   │
│   │   │                                                              │   │   │
│   │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│   │   │  │  ECS Task  │  │  ECS Task  │  │  ECS Task  │          │   │   │
│   │   │  │  (Backend) │  │  (Backend) │  │  (Backend) │  ← 3 AZ  │   │   │
│   │   │  │  FastAPI   │  │  FastAPI   │  │  FastAPI   │          │   │   │
│   │   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │   │   │
│   │   └─────────┼───────────────┼───────────────┼──────────────────┘   │   │
│   │             └───────────────┼───────────────┘                       │   │
│   │                             │                                       │   │
│   │   ┌─────────────────────────────────────────────────────────┐    │   │
│   │   │  Data Subnet - PRIVATE (no internet access)            │    │   │
│   │   │                                                          │    │   │
│   │   │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐   │    │   │
│   │   │  │ RDS Postgres │  │ ElastiCache  │  │  MLflow ECS │   │    │   │
│   │   │  │ Multi-AZ     │  │  Redis       │  │  (internal) │   │    │   │
│   │   │  │ KMS encrypted│  │  predictions │  │  + RDS store│   │    │   │
│   │   │  └──────────────┘  └──────────────┘  └─────────────┘   │    │   │
│   │   └─────────────────────────────────────────────────────────┘    │   │
│   │                                                                      │   │
│   │   ┌─────────────────────────────────────────────────────────────┐   │   │
│   │   │  SQS Queues (Training Pipeline - Async)                    │   │   │
│   │   │  consent-events-queue   → doctor validation worker         │   │   │
│   │   │  validation-queue       → admin approval worker            │   │   │
│   │   │  approval-queue         → S3 training pool writer          │   │   │
│   │   │  Each queue has a DLQ (dead letter queue) for retries      │   │   │
│   │   └─────────────────────────────────────────────────────────────┘   │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                     S3 Buckets (VPC endpoint - no public internet)   │   │
│   │   models-bucket:   Production model weights (loaded at ECS startup)  │   │
│   │   training-bucket: Curated training images (doctor+admin approved)   │   │
│   │   artifacts-bucket: MLflow artifacts (models, metrics, plots)        │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Missing Components (Not Yet Provisioned)

These are required for a production system and are not in the current Terraform modules:

| Component | Purpose | Where to Add | Priority |
|-----------|---------|--------------|----------|
| SQS queues + DLQs | Async training pipeline with retry | New Terraform module | Critical |
| ElastiCache (Redis) | Shared predictions store across ECS tasks | New Terraform module | Critical |
| MLflow ECS service | Model registry and experiment tracking UI | New Terraform module | High |
| SES + SNS notifications | Email doctors on new cases, notify admin on training readiness | New Terraform module | High |
| S3 image data lifecycle | Auto-delete raw images after training, reduce storage cost | S3 module update | Medium |
| CloudWatch alarms | Alert on inference latency, error rate, model drift | Monitoring module | High |
| AWS AppConfig or SSM | Feature flags for safe model rollouts | Config layer | Medium |

---

## 3. AWS Infrastructure

### S3 Bucket Structure

```
skin-lesion-models-{account}/
├── production/                      # Current production model
│   └── resnet50_v1.x.pth
└── archived/                       # Previous model versions
    └── resnet50_v1.{n}.pth

skin-lesion-training-{account}/
├── pending_review/                  # Doctor-validated, awaiting admin
│   └── YYYY/MM/DD/
│       ├── {case_id}.jpg
│       └── {case_id}.json
├── approved/                       # Admin-approved for training
│   ├── metadata.csv               # All approved cases
│   └── images/
│       ├── {case_id}.jpg
│       └── ...
└── exports/                       # GDPR exports (temporary)
    └── {user_id}/
```

**Storage Estimate:**
- 10,000 approved training images × 2MB avg = 20GB
- Cost: ~$0.46/month (vs $460/month for 1M images at $0.023/GB)

---

## 4. Authentication System

### AWS Cognito Setup

**User Pools:**
```
skin-lesion-users-prod
├── Patient Pool
│   ├── Auto-verify email
│   ├── Password policy: 8 chars, 1 uppercase, 1 number
│   └── Custom: role=patient, approved=true (auto-approved for patients)

└── Doctor Pool
    ├── Admin verification required
    ├── Custom: role=doctor, approved=false
    └── Manual approval by admin before access granted
```

### Login Flow

```
1. User signs up (patient or doctor)
2. Cognito sends verification email
3. User verifies email → account created
4. For doctors: admin must approve before login works
5. User logs in → gets JWT tokens
6. Frontend includes JWT in API requests
7. Backend validates JWT and extracts role
```

### Admin Doctor Approval Flow

```
Doctor Registration:
1. Doctor signs up → receives confirmation email
2. Doctor verifies email → account created but "pending_approval"
3. Doctor tries to login → backend checks "approved" claim
4. If not approved → login rejected with message
5. Admin receives notification
6. Admin reviews medical license
7. Admin clicks "Approve"
8. Doctor can now login
```

---

## 5. User Roles & Permissions

### Role Definitions

| Role | Register | Approval Required | Upload | View All | Review Cases | Approve Training | Promote Models |
|------|----------|-------------------|--------|----------|--------------|-----------------|---------------|
| Patient | Self | No | Yes | No | No | No | No |
| Doctor | Self | Yes (admin) | Yes | Yes | Yes | No | No |
| Admin | Manual | N/A | Yes | Yes | No | Yes | Yes |

### API Permissions

```
Patient:
  POST   /api/v1/predict              ✓ (own images)
  POST   /api/v1/explain              ✓ (own predictions)
  POST   /api/v1/consent              ✓ (opt-in for training contribution)
  GET    /api/v1/users/me             ✓
  GET    /api/v1/users/me/predictions  ✓ (own history)

Doctor:
  POST   /api/v1/predict              ✓
  POST   /api/v1/explain              ✓
  POST   /api/v1/consent              ✓
  GET    /api/v1/predictions          ✓ (all, for review)
  POST   /api/v1/expert-opinions      ✓ (add expert diagnosis)
  GET    /api/v1/training-pool/pending  ✓ (review cases awaiting validation)

Admin:
  GET    /api/v1/admin/doctors        ✓ (pending approvals)
  POST   /api/v1/admin/doctors/approve  ✓
  POST   /api/v1/admin/doctors/reject    ✓
  GET    /api/v1/admin/training-pool    ✓ (approved cases)
  POST   /api/v1/admin/training-pool/approve  ✓ (approve for training)
  POST   /api/v1/admin/training-pool/reject  ✓ (reject from training)
  POST   /api/v1/admin/models/promote  ✓ (promote new model)
  GET    /api/v1/admin/stats          ✓ (system metrics)
```

---

## 6. Training Data Curation Pipeline

### Complete Flow Diagram

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                           PATIENT FLOW                                        │
│                                                                              │
│  Patient uploads image                                                       │
│         ↓                                                                    │
│  AI makes prediction (diagnosis + confidence + Grad-CAM)                   │
│         ↓                                                                    │
│  Prediction stored in PostgreSQL (metadata, image in Redis for 1h)          │
│         ↓                                                                    │
│  Patient sees result + heatmap                                              │
│         ↓                                                                    │
│  Patient optionally consents to share for training                            │
│         ↓                                                                    │
│  If consent=true → Image moves to "pending_validation" queue               │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                           DOCTOR FLOW                                        │
│                                                                              │
│  Doctor logs in → sees list of cases needing validation                    │
│         ↓                                                                    │
│  Doctor reviews each case:                                                  │
│    - View original image                                                     │
│    - View AI prediction                                                      │
│    - View Grad-CAM heatmap                                                   │
│    - Provide expert opinion (confirm/correct diagnosis)                      │
│         ↓                                                                    │
│  Doctor submits expert opinion → case moves to "pending_admin_approval"     │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────────────┐
│                           ADMIN FLOW                                         │
│                                                                              │
│  Admin sees list of doctor-validated cases                                  │
│         ↓                                                                    │
│  Admin reviews:                                                              │
│    - Original image                                                          │
│    - AI prediction                                                           │
│    - Doctor's expert opinion                                                  │
│         ↓                                                                    │
│  Admin approves → image + metadata → "approved_training" folder in S3     │
│         ↓                                                                    │
│  When approved count ≥ 5,000:                                               │
│    - Trigger batch retraining (quarterly or when threshold reached)         │
│    - Train new model version                                                  │
│    - Evaluate against current production model                                │
│    - If improved: admin promotes to production                                │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

### Training Data Quality Gates

| Stage | Gate | Purpose |
|-------|------|---------|
| Patient consent | Opt-in required | Legal basis for processing |
| Doctor validation | Expert confirms/corrects diagnosis | Reliable ground truth |
| Admin approval | Admin reviews validated cases | Final quality gate |

### Batch Retraining Policy

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Minimum cases before retraining | 5,000 | Statistical significance |
| Retraining frequency | Quarterly | Accumulate meaningful data |
| Fine-tuning epochs | 5 | Prevent catastrophic forgetting |
| Promotion threshold | AUC improvement > 0.5% | Meaningful improvement |
| Human approval required | Yes | Never auto-promote |

> **AI ENGINEER NOTE:** The 5,000 case minimum must also include a class distribution check. If 4,800 of the 5,000 are one diagnosis class, the fine-tuned head will be biased. Before triggering retraining, query:
> ```sql
> SELECT diagnosis, COUNT(*) as count
> FROM training_cases
> WHERE used_in_training = FALSE
> GROUP BY diagnosis;
> ```
> Proceed only if no class is below 300 samples and no class exceeds 60% of the total.

### Training Data Manifest (Replace metadata.csv)

> **DATA ENGINEER NOTE:** Do NOT use a CSV file in S3 as the training manifest. Concurrent admin approvals will cause write conflicts. Use the database instead.

```sql
-- Query to generate training manifest at retrain time (not a CSV)
SELECT
    tc.id,
    tc.image_s3_path,
    tc.diagnosis,
    tc.patient_demographics,
    eo.doctor_id,
    eo.agrees_with_ai,
    u.medical_license IS NOT NULL AS doctor_verified
FROM training_cases tc
JOIN expert_opinions eo ON tc.expert_opinion_id = eo.id
JOIN users u ON eo.doctor_id = u.id
WHERE tc.used_in_training = FALSE
ORDER BY tc.approved_at ASC;
```

After retraining, mark used cases in a single transaction:
```sql
UPDATE training_cases
SET used_in_training = TRUE, model_version_used = 'v2.3'
WHERE id IN (:used_case_ids);
```

---

## 7. API Architecture

### FastAPI Structure

```
app/
├── main.py                    # FastAPI app, CORS, startup
├── config.py                  # Environment variables
├── deps.py                    # Dependencies (auth, db)
│
├── api/v1/
│   ├── router.py              # Main v1 router
│   └── endpoints/
│       ├── predict.py         # POST /predict
│       ├── explain.py         # POST /explain
│       ├── consent.py         # POST /consent
│       ├── expert_opinions.py # POST /expert-opinions
│       ├── training_pool.py   # GET training pool status
│       ├── users.py           # User management
│       └── admin.py           # Admin operations
│
├── core/
│   ├── security.py            # JWT validation
│   └── permissions.py         # Role-based access
│
├── db/
│   ├── models/                # SQLAlchemy models
│   │   ├── user.py
│   │   ├── prediction.py
│   │   ├── expert_opinion.py
│   │   └── training_case.py
│   └── schemas/              # Pydantic schemas
│
└── ml/
    ├── model_loader.py       # Load model at startup
    ├── cam_generator.py      # Grad-CAM
    └── training_pool.py      # Training data management
```

### Database Schema

```sql
-- Users
CREATE TABLE users (
    id UUID PRIMARY KEY,
    cognito_sub VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('patient', 'doctor', 'admin')),
    approved BOOLEAN DEFAULT FALSE,
    full_name VARCHAR(255),
    medical_license VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Predictions
CREATE TABLE predictions (
    id UUID PRIMARY KEY,
    prediction_id VARCHAR(255) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id),
    diagnosis VARCHAR(20) NOT NULL,
    confidence DECIMAL(5,4) NOT NULL,
    model_version VARCHAR(50) NOT NULL,
    consent_for_training BOOLEAN DEFAULT FALSE,
    consent_timestamp TIMESTAMP,
    status VARCHAR(30) DEFAULT 'completed',  -- completed, pending_review, approved, rejected
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Expert Opinions (Doctor Validations)
CREATE TABLE expert_opinions (
    id UUID PRIMARY KEY,
    prediction_id UUID REFERENCES predictions(id),
    doctor_id UUID REFERENCES users(id),
    diagnosis VARCHAR(20) NOT NULL,
    agrees_with_ai BOOLEAN NOT NULL,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Training Cases (Doctor+Admin Approved)
CREATE TABLE training_cases (
    id UUID PRIMARY KEY,
    prediction_id UUID REFERENCES predictions(id),
    expert_opinion_id UUID REFERENCES expert_opinions(id),
    approved_by UUID REFERENCES users(id),
    image_s3_path VARCHAR(500) NOT NULL,
    diagnosis VARCHAR(20) NOT NULL,  -- Final approved diagnosis
    patient_demographics JSONB,       -- Age, sex, location (anonymized)
    approved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    used_in_training BOOLEAN DEFAULT FALSE,
    model_version_used VARCHAR(50)
);

-- Indexes
CREATE INDEX idx_predictions_user ON predictions(user_id);
CREATE INDEX idx_predictions_status ON predictions(status);
CREATE INDEX idx_training_cases_used ON training_cases(used_in_training);
```

### Key API Endpoints

```
# Patient
POST   /api/v1/predict                        # Upload image, get prediction
POST   /api/v1/explain                        # Get Grad-CAM heatmap
POST   /api/v1/consent                        # Opt-in to training contribution

# Doctor
GET    /api/v1/predictions?status=pending_review  # Get cases to validate
POST   /api/v1/expert-opinions                # Submit expert opinion
GET    /api/v1/predictions/{id}                # View case detail

# Admin
GET    /api/v1/admin/training-pool            # View approved training cases
GET    /api/v1/admin/training-pool/stats       # Pool size, model versions
POST   /api/v1/admin/training-pool/approve/{id} # Approve case for training
POST   /api/v1/admin/training-pool/reject/{id}  # Reject case
GET    /api/v1/admin/training-pool/pending     # Cases awaiting approval
POST   /api/v1/admin/models/train              # Trigger batch training
POST   /api/v1/admin/models/promote/{version} # Promote model version
GET    /api/v1/admin/models/versions           # List model versions
```

---

## 8. Error Handling

### Error Response Format

All API errors follow a consistent JSON structure:

```json
{
  "detail": "Human-readable error message",
  "error_code": "MODEL_NOT_LOADED",
  "request_id": "req_abc123",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Error Categories

| Category | HTTP Status | Error Code | Description |
|----------|-------------|------------|-------------|
| Validation | 400 | VALIDATION_ERROR | Invalid request data |
| Authentication | 401 | AUTH_REQUIRED | Missing or invalid JWT |
| Authorization | 403 | ACCESS_DENIED | Insufficient permissions |
| Not Found | 404 | NOT_FOUND | Resource doesn't exist |
| Rate Limit | 429 | RATE_LIMITED | Too many requests |
| Server Error | 500 | INTERNAL_ERROR | Unexpected server error |
| Service Unavailable | 503 | SERVICE_UNAVAILABLE | Dependency down |

### Backend Error Handling

```python
# Global exception handler in app/main.py
from fastapi import Request, status
from fastapi.responses import JSONResponse

@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "detail": exc.detail,
            "error_code": get_error_code(exc.status_code),
            "request_id": request.state.request_id,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "detail": "An unexpected error occurred",
            "error_code": "INTERNAL_ERROR",
            "request_id": request.state.request_id,
            "timestamp": datetime.utcnow().isoformat(),
        }
    )
```

### Model Error Handling

| Error Scenario | Response | Recovery |
|----------------|----------|----------|
| Model not loaded | 503 "Model not loaded" | Auto-retry after 30s, alert ops |
| Model inference fails | 500 with error details | Log to CloudWatch, alert ML team |
| Invalid image format | 400 with format requirements | Client validation |
| Image too large | 413 with size limit | Client compression |

### Database Error Handling

| Error Scenario | Response | Recovery |
|----------------|----------|----------|
| Connection timeout | 503 "Database unavailable" | Retry with exponential backoff |
| Query timeout | 504 "Query timeout" | Simplify query, paginate |
| Connection pool exhausted | 503 "Service busy" | Queue requests, scale ECS |
| Deadlock | 500 "Retry transaction" | Automatic retry |

### Redis Error Handling

| Error Scenario | Response | Recovery |
|----------------|----------|----------|
| Connection refused | Prediction continues without cache | Log warning, degrade gracefully |
| Memory exceeded | Evict oldest predictions | Auto-cleanup |
| Operation timeout | 504 "Cache operation timeout" | Retry from database |

---

## 9. Rate Limiting

### Rate Limit Tiers

| Tier | User Type | Requests/minute | Burst |
|------|-----------|-----------------|-------|
| Free | Patient | 5 | 10 |
| Standard | Authenticated Patient | 20 | 40 |
| Premium | Doctor | 60 | 100 |
| Internal | Admin/System | Unlimited | - |

### Rate Limit Headers

All API responses include rate limit headers:

```
X-RateLimit-Limit: 20
X-RateLimit-Remaining: 15
X-RateLimit-Reset: 1705312800
X-RateLimit-Policy: 20/minute
```

### Endpoint-Specific Limits

| Endpoint | Limit | Window | Purpose |
|----------|-------|--------|---------|
| POST /predict | 10/min | Sliding | Prevent abuse, manage compute |
| POST /explain | 30/min | Sliding | CAM generation is expensive |
| POST /feedback | 50/min | Sliding | Reasonable for consent flow |
| GET /admin/* | 100/min | Sliding | Admin operations |
| GET /health | No limit | - | Health checks |

### Implementation (FastAPI)

```python
from fastapi import Request, HTTPException
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)

@router.post("/predict")
@limiter.limit("10/minute")
async def predict(request: Request, image: UploadFile = File(...)):
    # Check if user is authenticated and apply tier limits
    if request.state.user:
        tier = get_user_tier(request.state.user)
        limit = TIER_LIMITS[tier]
        # Apply tier-specific limit
    # ...
```

### Rate Limit Exceeded Response

When rate limited (HTTP 429):

```json
{
  "detail": "Rate limit exceeded. Try again in 30 seconds.",
  "error_code": "RATE_LIMITED",
  "retry_after": 30,
  "limit": 20,
  "window": "minute"
}
```

---

## 10. Rollback Procedures

### Quick Reference

| Scenario | Detection | Rollback Time | Team |
|----------|----------|---------------|------|
| ECS deployment failure | Health check failing | 5-10 min | DevOps |
| Model prediction degraded | Error rate spike | 3-5 min | ML Team |
| Database issue | Connection errors | 15-30 min | DBA |
| Frontend deployment | Console errors | 2-5 min | Frontend |

### ECS Deployment Rollback

**When to use:**
- ECS tasks failing health checks after deployment
- Application errors increasing after deployment
- Need to revert to previous Docker image

**Procedure:**

```bash
# 1. Find previous working image tag
aws ecr list-images --repository-name skin-lesion-backend | grep prod-latest

# 2. Get the image digest of previous version
aws ecr describe-images \
  --repository-name skin-lesion-backend \
  --image-tags prod-latest \
  --query 'images[0].imageDetails'

# 3. Tag previous image as new production
aws ecr put-image \
  --repository-name skin-lesion-backend \
  --image-tag prod-$(date +%Y%m%d%H%M) \
  --image-manifest "$(aws ecr describe-images --repository-name skin-lesion-backend --image-tag prod-latest --query 'imageManifest' --output text)"

# 4. Force new deployment (uses latest prod tag)
aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --force-new-deployment

# 5. Verify rollback
aws ecs wait services-stable \
  --cluster skin-lesion-prod \
  --services skin-lesion-backend

curl -f https://api.skinlesion.com/health
```

### Model Rollback

**When to use:**
- New model causing incorrect predictions
- Model performance metrics below threshold
- Model fails to load in production

**Procedure:**

```bash
# 1. List available model versions
aws s3 ls s3://skin-lesion-models-PROD/archived/

# 2. Copy archived model to production
aws s3 cp s3://skin-lesion-models-PROD/archived/resnet50_v1.x.pth \
          s3://skin-lesion-models-PROD/production/resnet50_v1.x.pth

# 3. Set model version environment variable
aws ecs update-service \
  --cluster skin-lesion-prod \
  --service skin-lesion-backend \
  --force-new-deployment

# 4. Verify model loaded
aws logs tail /ecs/skin-lesion-prod --filter-pattern "Model loaded"
```

### Database Rollback (Point-in-Time Recovery)

**Warning:** Affects ALL data since restore point. Only use when data loss is acceptable.

```bash
# 1. Create snapshot of current state (safety)
aws rds create-db-snapshot \
  --db-instance-identifier skin-lesion-prod \
  --snapshot-identifier pre-rollback-$(date +%Y%m%d%H%M)

# 2. Initiate point-in-time restore
aws rds restore-db-instance-to-point-in-time \
  --source-db-instance-identifier skin-lesion-prod \
  --target-db-instance-identifier skin-lesion-prod-restored \
  --restore-time 2024-01-15T10:30:00Z

# 3. Wait for restore (15-30 minutes)
aws rds wait db-instance-available \
  --db-instance-identifier skin-lesion-prod-restored

# 4. Verify data integrity before cutover
# Test on restored instance, then promote to production
```

### Frontend Rollback (Vercel)

```bash
# 1. List deployments
vercel list

# 2. Rollback to previous deployment
vercel rollback [deployment-url]

# Or via Dashboard:
# Vercel > Project > Deployments > Last working > "..." > "Promote to Production"
```

### S3 Data Rollback

```bash
# 1. Check S3 versioning is enabled
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
```

### Escalation Matrix

| Severity | Response Time | Escalation Path |
|----------|---------------|-----------------|
| Minor | 1 hour | On-call only |
| Moderate | 30 min | On-call → Tech Lead |
| Major | 15 min | On-call → Tech Lead → CTO |
| Critical | 5 min | On-call → Tech Lead → CTO → CEO |

---

## 11. Mobile App Architecture

### App Structure

```
skin-lesion-mobile/
├── app/
│   ├── (auth)/                # Login, register
│   ├── (app)/                 # Protected app routes
│   │   ├── (tabs)/            # Bottom tab navigation
│   │   │   ├── home/         # Patient: upload, predict
│   │   │   ├── history/      # Patient: prediction history
│   │   │   ├── review/       # Doctor: pending validations
│   │   │   ├── patients/     # Doctor: all cases
│   │   │   ├── training/    # Admin: training pool
│   │   │   └── profile/
│   │   └── _layout.tsx
│   └── _layout.tsx
```

---

## 12. CI/CD Pipeline

### GitHub Actions Workflows

```
.github/workflows/
├── ci.yml                  # PR checks: lint, test, type-check
├── deploy-backend.yml       # Deploy to ECS
├── deploy-frontend.yml     # Deploy to Vercel
├── deploy-mobile.yml       # EAS builds
└── model-retrain.yml       # Manual trigger for batch retraining
```

### Model Retraining Workflow

```
Trigger: Manual (admin clicks "Train New Model")

1. Check approved training cases count
   ├── If < 5,000 → reject with message
   └── If ≥ 5,000 → proceed

2. Download training data from S3 approved/ folder
   └── ~20GB max (10,000 images)

3. Load current production model from S3

4. Fine-tune:
   ├── Backbone: frozen
   ├── Classifier head: 5 epochs
   ├── Validation: held-out 20%
   └── Log to MLflow

5. Evaluate:
   ├── AUC on test set
   ├── Compare with production model
   └── If AUC_delta > 0.005 → register as "PROMOTE"
   └── Otherwise → register as "DISCARD"

6. Notify admin via Slack/email

7. Admin reviews in MLflow UI

8. If approved:
   ├── Tag model version as "Production" in MLflow
   └── ECS rolling deploy picks up new model
```

---

## 13. GDPR Compliance

### Data Classification

| Data Type | Storage | Retention | Legal Basis |
|-----------|---------|-----------|-------------|
| Account info | PostgreSQL | Until deletion | Contract |
| Predictions (metadata) | PostgreSQL | 2 years | Legitimate interest |
| Images | Redis (1h), then deleted | N/A | N/A |
| Consented images | S3 (if approved) | Until model retrain | Explicit consent |
| Expert opinions | PostgreSQL | 2 years | Legitimate interest |
| Training cases | S3 | Until retrain cycle | Explicit consent |

### Consent Flow

```
1. Patient uploads image
2. Patient sees prediction immediately (no consent required for prediction)
3. Patient optionally consents to share for training
   └── Separate, explicit checkbox
   └── Unchecked by default
4. If consented:
   ├── Doctor validates → expert opinion recorded
   ├── Admin approves → image moved to training bucket
   └── Patient can withdraw consent at any time
5. Withdrawal:
   ├── If not yet used in training → delete immediately
   └── If already used → model can't be un-trained, but no new images
```

---

## 14. Development Phases

### Phase 1: Foundation (Weeks 1-2)
- [ ] AWS account, VPC, IAM roles
- [ ] Cognito User Pools (patient, doctor)
- [ ] RDS PostgreSQL
- [ ] S3 buckets (models, training)
- [ ] ECR repositories

### Phase 2: Backend Core (Weeks 3-4)
- [ ] FastAPI with auth middleware
- [ ] /predict, /explain endpoints
- [ ] /consent endpoint
- [ ] Expert opinions endpoint
- [ ] Redis for temporary image storage

### Phase 3: Curation Pipeline (Week 5)
- [ ] Doctor review dashboard endpoint
- [ ] Admin approval workflow
- [ ] S3 training pool management
- [ ] Training case model and endpoints

### Phase 4: Frontend Web (Weeks 6-7)
- [ ] Patient upload + prediction flow
- [ ] Doctor review dashboard
- [ ] Admin approval dashboard
- [ ] Privacy policy

### Phase 5: Mobile App (Weeks 8-9)
- [ ] Patient app
- [ ] Doctor app (review feature)
- [ ] Admin app (approval feature)

### Phase 6: CI/CD + MLflow (Week 10)
- [ ] GitHub Actions workflows
- [ ] MLflow experiment tracking
- [ ] Model registry setup

### Phase 7: Testing & Launch (Weeks 11-12)
- [ ] Security testing
- [ ] Load testing
- [ ] GDPR audit prep
- [ ] App store submissions

### Phase 8: Post-Launch (Ongoing)
- [ ] Accumulate training cases
- [ ] Quarterly batch retraining
- [ ] Monitor model performance

---

## 15. Critical Engineering Questions

These are the questions a senior system architect, data engineer, and AI engineer would ask before signing off on this design. Work through all of them before production launch. Each unanswered question is a latent bug or compliance gap.

---

### 15A. System Architect Questions

**Distributed Systems**

1. **Where is the message queue for the training pipeline?**
   The pipeline (consent → doctor validation → admin approval → S3 write) is described as a series of API calls. What happens when a step fails midway? Without SQS queues and dead letter queues, failed events are silently lost with no retry. Every state transition in the training pipeline must go through a queue, not a direct API call.

2. **What is your consistency model when a patient's Redis prediction expires mid-pipeline?**
   Images live in Redis for 1 hour. The consent-to-doctor-validation window can exceed 1 hour easily. If consent is given at minute 58 and the doctor validates at minute 62, Redis has evicted the image. Where does the physical image come from for the S3 training bucket write? This is an unresolved race condition - you need to persist the image to S3 at consent time, not at doctor validation time.

3. **What is your circuit breaker strategy for ML inference?**
   If the `/explain` endpoint (Grad-CAM) hangs for 30+ seconds due to GPU contention or memory pressure, it will exhaust FastAPI's async thread pool. Every incoming request queues behind it. You need a timeout (e.g., 10s for `/explain`) with a 503 fallback, and a circuit breaker that opens after 5 consecutive timeouts. Libraries: `circuitbreaker` or `tenacity` for Python.

4. **ECS task subnet placement - are tasks in private subnets?**
   ECS application tasks must run in private (App) subnets, with only the ALB in the public subnet. If ECS tasks have public IPs, they are directly reachable from the internet, bypassing the ALB, WAF, and all security controls. Verify your Terraform `aws_ecs_service` resource has `assign_public_ip = DISABLED` and uses `app_subnet_ids`.

5. **MLflow server - where does it run and who secures it?**
   MLflow is referenced throughout but has no Terraform module. It needs: an ECS task or EC2 instance, an RDS backend store, an S3 artifact store, authentication (at minimum HTTP basic auth or Cognito), and network access from ECS application tasks. Without this, there is no production model registry and no way to promote models. Define this before writing any ML pipeline code.

6. **What is your health check grace period for ECS rolling deployments?**
   Model weights load from S3 at container startup - this can take 60-120 seconds for ResNet50. If the ECS health check fires before the model is loaded, the task fails and rolls back before it ever serves traffic. Set `health_check_grace_period_seconds = 120` on your ECS service, and verify the `/health` endpoint returns 200 only after the model is loaded.

7. **How do you prevent split-brain between MLflow model version and S3 model weights during rollback?**
   The rollback procedure copies an old `.pth` file to the S3 production path. But if MLflow still shows the new version as "Production", the system is in an inconsistent state: weights and registry version disagree. Rollback must atomically update both: copy the S3 file AND transition the MLflow version tag. Write a single rollback script that does both, not two manual commands.

**Security Boundaries**

8. **Is JWT token refresh handled in the frontend for long doctor review sessions?**
   Cognito access tokens expire after 1 hour by default. A doctor reviewing cases for 90 minutes will have their token expire mid-session. When the next API call fails with 401, their half-submitted expert opinion is lost. The frontend must implement silent token refresh using the Cognito refresh token before expiry, or maintain session continuity across token rotation.

9. **What is your medical license verification process?**
   The users table has a `medical_license VARCHAR(255)` column. Currently admin manually reviews this string. What prevents a bad actor from typing a fake license number? For a medical platform, you need: (a) a document upload field for the license image, (b) a stored S3 path for the upload, (c) an audit log of who reviewed and approved. The current design is a typed string with no verification.

10. **Are CORS origins locked down for both the API and the admin dashboard?**
    The config has `ALLOWED_ORIGINS` including `localhost:3000`. In production, this must only include the Vercel domain and the production API domain. A misconfigured CORS allows any website to make authenticated API calls on behalf of a logged-in user.

**Failure Modes**

11. **What is your RTO and RPO for this medical platform?**
    The rollback procedures doc exists but defines no recovery time objectives. For a medical platform, you need: documented RTO (e.g., 4 hours for full recovery), RPO (e.g., 1 hour data loss acceptable), and tested runbooks. These may be regulatory requirements depending on your jurisdiction and whether this is used in clinical settings.

12. **What happens when the S3 VPC endpoint is unavailable?**
    ECS tasks access S3 exclusively through the VPC endpoint. If the endpoint has a service disruption, all S3 operations fail - including model loading at startup, training image writes, and GDPR exports. Do you have a fallback path (internet route via NAT) or a graceful degradation mode (serve predictions from cached model, queue S3 writes)?

---

### 15B. Data Engineer Questions

**Schema Design**

13. **What is the defined schema for `patient_demographics` JSONB?**
    The `training_cases` table stores demographics as `JSONB` with no schema. Different collection periods will produce inconsistent shapes, making demographic stratification in retraining impossible. Define the schema explicitly:
    ```sql
    -- Expected structure
    {
      "age": 45,               -- integer, required
      "sex": "male",           -- "male" | "female" | "unknown"
      "localization": "back",  -- anatomical site string
      "skin_tone": null        -- optional, for RQ6 demographic tracking
    }
    ```
    Add a JSON schema validation constraint or a dedicated columns migration.

14. **How do you prevent duplicate consent submissions?**
    `POST /consent` has no idempotency key or unique constraint on `(prediction_id, user_id)`. A patient who double-taps the consent button submits the same prediction twice into the pipeline. Add: `UNIQUE INDEX idx_training_cases_prediction ON training_cases(prediction_id)` and return 200 (not 201) on duplicate consent, handling it as an idempotent operation.

15. **How do you track training data lineage - which cases went into which model version?**
    The `training_cases.model_version_used` column records which model used each case. But the reverse query - "what cases went into model v2.3?" - requires a full table scan with `WHERE model_version_used = 'v2.3'`. For audit and GDPR purposes, create a junction table:
    ```sql
    CREATE TABLE training_run_cases (
        training_run_id UUID REFERENCES training_runs(id),
        training_case_id UUID REFERENCES training_cases(id),
        PRIMARY KEY (training_run_id, training_case_id)
    );
    ```

16. **What is your image format normalization strategy?**
    Patients upload JPG, PNG, and WEBP files. The model requires 224x224 normalized tensors. This preprocessing happens at inference time (correct). But when an image is saved to the S3 training pool, should it be stored as: (a) the raw upload, or (b) the preprocessed tensor? If raw, retraining must re-run all preprocessing on 10,000 files. If preprocessed, you lose image quality. Recommended: store raw + a `preprocessed/` prefix with the normalized version. Run preprocessing as a Lambda triggered by S3 upload events.

17. **What is your GDPR deletion SLA and how is it tracked?**
    The architecture says "if not yet used in training → delete immediately." "Immediately" is undefined. GDPR Article 17 requires "undue delay" (interpreted as 30 days maximum). You need:
    ```sql
    CREATE TABLE deletion_requests (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id UUID REFERENCES users(id),
        prediction_id UUID REFERENCES predictions(id),
        requested_at TIMESTAMP DEFAULT NOW(),
        completed_at TIMESTAMP,
        status VARCHAR(20) DEFAULT 'pending'  -- pending, completed, failed
    );
    ```
    A scheduled Lambda or ECS task processes pending deletions daily and records `completed_at`.

18. **How do you monitor S3 training bucket cost and prevent runaway growth?**
    10,000 images at 2MB average = 20GB. That's cheap. But without a lifecycle policy, rejected images, GDPR exports, and old preprocessed copies accumulate. Add explicit S3 lifecycle rules: delete `rejected/` objects after 30 days, delete `exports/` objects after 7 days, delete `pending_review/` objects that were never approved after 90 days.

**Data Pipeline**

19. **Where does the "class distribution check" happen before retraining?**
    There is no automated check that the training pool has sufficient class balance. If you trigger retraining with 4,800 melanoma cases and 200 of everything else, the model will become melanoma-biased. This check must be a hard gate in the retraining workflow, not a manual review:
    ```python
    class_counts = db.query("SELECT diagnosis, COUNT(*) FROM training_cases WHERE used_in_training=FALSE GROUP BY diagnosis")
    if any(count < 300 for _, count in class_counts):
        raise ValueError("Insufficient samples for minority class, aborting retrain")
    ```

20. **How do you validate image quality before it enters the training pool?**
    Low-quality images (blurry, cropped incorrectly, non-dermatoscopic) degrade model performance. Add a Lambda function triggered on S3 uploads to `pending_review/` that runs basic checks: minimum resolution (>200x200), valid EXIF/format, not all-black/all-white, and a basic blur detection score. Reject images that fail. Log rejections to CloudWatch.

---

### 15C. AI Engineer Questions

**Model Serving**

21. **Is your ResNet50 confidence score calibrated?**
    Deep neural networks are systematically overconfident. A raw softmax output of 0.94 does not mean 94% probability of malignancy - it means "the model is very certain in its incorrect output space, not in the real world." For a medical application, you must calibrate the model using Platt scaling or temperature scaling on a held-out calibration set, and display calibrated probabilities to users, not raw softmax scores.

22. **Is Grad-CAM on the critical request path, or pre-computed?**
    If `/predict` and `/explain` are separate endpoints (current design), Grad-CAM runs when the user explicitly requests it. This is acceptable. But if you pre-compute Grad-CAM at prediction time to show it immediately, you add 200-800ms to every single prediction, even for users who never look at the heatmap. Keep them separate. Cache the Grad-CAM result in Redis with the same TTL as the prediction (1 hour).

23. **What is the model cold start time, and how does it affect ECS health checks?**
    - Docker image pull from ECR: ~60s (PyTorch image is large, ~2GB)
    - Python import time: ~10s
    - MLflow model load from S3: ~20-40s for ResNet50 weights
    - Total cold start: potentially 90-120 seconds
    
    Set `health_check_grace_period_seconds = 120` on the ECS service and ensure the `/health` endpoint only returns 200 after the model is fully loaded. Otherwise ECS will kill the task before it's ready and loop indefinitely.

24. **Do you have a shadow deployment capability for new model versions?**
    The current promotion flow is: train → MLflow review → admin promotes → all traffic goes to new model. This is binary - if the new model has a subtle regression (better AUC overall but worse on a demographic subset), you won't catch it until patients are affected. Add a shadow mode: route 5-10% of `/predict` requests to both the current and candidate model, compare predictions, log discrepancies. Only promote when discrepancy rate is within tolerance.

**Retraining**

25. **How does retraining preserve performance on the original HAM10000 test set?**
    Fine-tuning only the classifier head (backbone frozen) is a conservative strategy. But 5 epochs on 5,000 diverse new cases can still shift the decision boundary for edge cases that appeared in HAM10000. You need a frozen reference test set drawn from HAM10000 that is NEVER used in any training run, and a mandatory evaluation on it before any model is promoted. Add this as a required metric in the MLflow promotion checklist.

26. **When does the backbone need to be unfrozen for demographic robustness?**
    RQ6 in your notebooks studies performance on geographically/demographically diverse populations. If new training data represents populations significantly different from HAM10000 (e.g., darker skin tones, different camera types), the frozen backbone's feature representations may not generalize. For that scenario, you need a two-phase strategy: (1) fine-tune the full network on demographically diverse data with a low learning rate (1e-5), then (2) fine-tune only the head at a higher rate. Document in code when each strategy applies.

27. **How does inter-method CAM disagreement map to production monitoring?**
    RQ4 shows that inter-method disagreement (Grad-CAM vs EigenCAM) predicts misclassification. This insight should be operationalized in production: at inference time, run two CAM methods, compute a disagreement score (Jaccard distance between activation masks), and flag predictions with high disagreement as "low confidence - recommend in-person review." This is a cheap runtime check that directly improves clinical safety.

28. **Are you tracking model drift in production?**
    The model was trained on HAM10000 (European-heavy dataset). Production traffic will have a different image distribution - different cameras, lighting conditions, patient demographics. Without drift detection, model performance will silently degrade. Use: (a) a rolling window of prediction confidence distributions compared to the training set distribution, (b) CloudWatch metrics for mean confidence per diagnostic class, and (c) alert when distribution shift exceeds a threshold (KL divergence > 0.1 from baseline).

---

### 15D. Chatbot Architecture (Does Not Currently Exist)

No chatbot functionality is implemented or designed. The platform is a predict-validate-approve workflow with no conversational interface. If you want to add one, here is what separate chatbot setups would look like per role:

**Patient-facing chatbot:**
- Purpose: Answer "what does this result mean?", "should I see a doctor?", "what is melanoma?"
- Implementation: Claude API (`claude-sonnet-4-6`) with a system prompt scoped to skin health education. Hard rules: never give a specific diagnosis via chat, always recommend professional consultation.
- Frontend: A React chat widget component in the patient dashboard, separate from the prediction flow.
- Backend: A new `POST /api/v1/chat` endpoint that proxies to the Anthropic API with conversation history.

**Doctor-facing assistant:**
- Purpose: "Show me all unreviewed cases with confidence < 0.7", "What is the typical presentation of lentigo maligna?", literature lookup.
- Implementation: Claude API with tool use - give it read-only database query tools for case lookup, and a medical literature search tool.
- Access control: Requires `role=doctor` JWT claim. Separate conversation history per doctor stored in PostgreSQL.

**Admin assistant:**
- Purpose: "How many cases were approved this week?", "Is the training pool ready for retrain?", "Generate a batch approval report."
- Implementation: Claude API with tool use - database query tools, S3 inventory tools, MLflow API tools.
- Access control: Requires `role=admin` JWT claim.

These three chatbots share the same backend endpoint architecture but have different system prompts, tool permissions, and access controls. All three would be new work - none exists currently.