# Skin Lesion Classification Platform

Medical imaging AI platform that classifies dermoscopy images as benign or malignant and generates explainable heatmaps using Grad-CAM variants.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Monorepo (this repo)                        │
│  ├── infra/terraform/          ← AWS infrastructure as code    │
│  ├── ARCHITECTURE.md           ← System design + data flow     │
│  └── BUILD_PHASE_*.md          ← Implementation phases 1-5     │
└─────────────────────────────────────────────────────────────────┘
         │                                    │
         ▼                                    ▼
┌──────────────────────────┐       ┌──────────────────────────────┐
│  skin-lesion-backend     │       │  skin-lesion-frontend        │
│  (FastAPI + PyTorch)     │       │  (Next.js 14)               │
│  Deploys to AWS ECS       │       │  Deploys to Vercel          │
└──────────────────────────┘       └──────────────────────────────┘
```

## Repositories

| Repository | Purpose | Deploy |
|------------|---------|--------|
| [skin-lesion-backend](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_backend) | FastAPI inference API + PyTorch ML | AWS ECS Fargate |
| [skin-lesion-frontend](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_frontend) | Next.js web app | Vercel |
| skin-lesion-xai-research | RQ1-RQ6 notebooks, metrics, figures, and research training scripts | Local/Jupyter |

## Infrastructure

All AWS infrastructure is defined as Terraform in `infra/terraform/`:

| Module | Purpose |
|--------|---------|
| `modules/vpc/` | 3-tier VPC (public/app/data subnets) + S3 VPC endpoint |
| `modules/cognito/` | User pools for patients and doctors with MFA |
| `modules/s3-training/` | Training data bucket with MFA delete + VPC-only access |
| `modules/ecs-task-role/` | Least-privilege IAM for ECS tasks |
| `modules/rds/` | PostgreSQL with KMS encryption + Multi-AZ |
| `modules/guardduty/` | Threat detection with SNS alerts |
| `modules/cloudtrail/` | Multi-region audit logging |
| `modules/waf/` | Rate limiting + OWASP protection |
| `modules/alb/` | Application Load Balancer |
| `modules/ecs/` | ECS Cluster with Container Insights |

See `BUILD_PHASE_1_INFRASTRUCTURE.md` for full details.

## Development

```bash
# Infrastructure
cd infra/terraform
make init      # Initialize Terraform
make plan      # Preview changes
make apply     # Deploy to AWS

# Frontend
cd Skin_Lesion_Classification_frontend
npm install
npm run dev

# Research notebooks
cd Skin_Lesion_XAI_research
make setup
make run-notebook

# Backend
cd Skin_Lesion_Classification_backend
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## Security

Defensive controls implemented across three tiers:

- **Tier 1 (Critical)**: VPC, Cognito MFA, S3 VPC endpoint restriction + MFA delete, GuardDuty
- **Tier 2 (High)**: ECS least-privilege IAM, RDS encryption, CloudTrail multi-region, VPC Flow Logs
- **Tier 3 (Medium)**: WAF rate limiting, Secrets Manager rotation, KMS encryption

See `GDPR_COMPLIANCE.md` for data handling requirements.

## Documentation

**Start here when building:** [`docs/HOW_TO_BUILD.md`](docs/HOW_TO_BUILD.md) - navigation map for the entire build, phase by phase.

| Doc | Purpose |
|-----|---------|
| [`docs/HOW_TO_BUILD.md`](docs/HOW_TO_BUILD.md) | Build navigation guide - where to go at each stage |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, data flow, and 28 critical engineering questions |
| [`docs/BUILD_PHASE_1_INFRASTRUCTURE.md`](docs/BUILD_PHASE_1_INFRASTRUCTURE.md) | Terraform infrastructure setup |
| [`docs/BUILD_PHASE_2_BACKEND.md`](docs/BUILD_PHASE_2_BACKEND.md) | FastAPI implementation + AI/Data engineer patterns |
| [`docs/BUILD_PHASE_3_FRONTEND.md`](docs/BUILD_PHASE_3_FRONTEND.md) | Next.js per-role UI implementation |
| [`docs/BUILD_PHASE_4_MOBILE.md`](docs/BUILD_PHASE_4_MOBILE.md) | React Native / Expo mobile app |
| [`docs/BUILD_PHASE_5_CICD.md`](docs/BUILD_PHASE_5_CICD.md) | CI/CD, MLflow, and deployment |
| [`docs/DEVELOPMENT_CHECKLIST.md`](docs/DEVELOPMENT_CHECKLIST.md) | Live task tracker - check boxes as you build |
| [`docs/SECURITY_CHECKLIST.md`](docs/SECURITY_CHECKLIST.md) | Security sign-off before launch |
| [`docs/GDPR_COMPLIANCE.md`](docs/GDPR_COMPLIANCE.md) | Consent management and data retention |
| [`docs/ROLLBACK_PROCEDURES.md`](docs/ROLLBACK_PROCEDURES.md) | How to undo deployments |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Error lookup and fixes |
