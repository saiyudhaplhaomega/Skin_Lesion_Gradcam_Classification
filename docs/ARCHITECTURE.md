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
8. [Mobile App Architecture](#8-mobile-app-architecture)
9. [CI/CD Pipeline](#9-cicd-pipeline)
10. [GDPR Compliance](#10-gdpr-compliance)
11. [Development Phases](#11-development-phases)

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
│   │   │  Public Subnet (ECS Tasks - Load Balancer)                  │   │   │
│   │   │                                                              │   │   │
│   │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │   │   │
│   │   │  │  ECS Task  │  │  ECS Task  │  │  ECS Task  │          │   │   │
│   │   │  │  (Backend) │  │  (Backend) │  │  (Backend) │  ← 3 AZ  │   │   │
│   │   │  │  FastAPI   │  │  FastAPI   │  │  FastAPI   │          │   │   │
│   │   │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │   │   │
│   │   └─────────┼───────────────┼───────────────┼──────────────────┘   │   │
│   │             │               │               │                       │   │
│   │             └───────────────┼───────────────┘                       │   │
│   │                             │                                     │   │
│   │                    Application Load Balancer                       │   │
│   │                             │                                     │   │
│   │   ┌─────────────────────────────────────────────────────────┐    │   │
│   │   │  Private Subnet (Data Layer)                           │    │   │
│   │   │                                                          │    │   │
│   │   │  ┌──────────────┐    ┌──────────────┐    ┌───────────┐  │    │   │
│   │   │  │  RDS (Postgres)│    │  ElastiCache │    │ S3 VPC   │  │    │   │
│   │   │  │  Users/Auth    │    │   (Redis)    │    │ Endpoint│  │    │   │
│   │   │  │  predictions   │    │  predictions │    │ models  │  │    │   │
│   │   │  │  expert_opinions│    │  cache        │    │ training│  │    │   │
│   │   │  └──────────────┘    └──────────────┘    └───────────┘  │    │   │
│   │   └─────────────────────────────────────────────────────────┘    │   │
│   │                                                                      │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                     S3 (Two Buckets)                                  │   │
│   │   models-bucket: Pre-trained model weights (loaded at startup)       │   │
│   │   training-bucket: Curated training images (doctor+admin approved)   │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   ┌──────────────────────────────────────────────────────────────────────┐   │
│   │                        MLflow Tracking Server                        │   │
│   │              (Experiment tracking, model registry)                   │   │
│   └──────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

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

## 8. Mobile App Architecture

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

## 9. CI/CD Pipeline

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

## 10. GDPR Compliance

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

## 11. Development Phases

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