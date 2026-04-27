# Skin Lesion Classification Platform

Workspace-level architecture, infrastructure, and build guidance for the Skin Lesion Classification platform.

The implementation is split across separate repositories so each repo has a clear job:

| Repository | Purpose | GitHub |
| --- | --- | --- |
| [`Skin_Lesion_Classification_backend`](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_backend) | FastAPI inference API, PyTorch model serving, Grad-CAM generation, and backend-owned model artifact loading | https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_backend |
| [`Skin_Lesion_Classification_frontend`](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_frontend) | Next.js web app for patient uploads, prediction display, heatmap viewing, consent, doctor review, and admin workflows | https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_frontend |
| [`Skin_Lesion_XAI_research`](https://github.com/saiyudhaplhaomega/Skin_Lesion_XAI_research) | HAM10000 notebooks, RQ1-RQ6 experiments, research metrics, figures, and training helpers | https://github.com/saiyudhaplhaomega/Skin_Lesion_XAI_research |
| `Skin_Lesion_GRADCAM_Classification` | This workspace: architecture docs, Terraform infrastructure, build roadmap, security docs, and cross-repo coordination | local/root repo |

## Current Build Reality

- Research notebooks and experiment outputs belong in `Skin_Lesion_XAI_research`.
- The frontend should not be the source of truth for notebooks, training scripts, or research outputs.
- The backend consumes model artifacts and exposes API endpoints; it should not document RQ notebooks as backend-owned work.
- The root docs describe the full system and build order.

## Build Order

1. Research: prepare data, run notebooks/training, produce candidate model artifacts.
2. Backend: load model artifacts, expose `/health`, `/predict`, and `/explain`, then add consent/retraining flows.
3. Frontend: connect the upload, prediction, explanation, consent, doctor, and admin workflows to the backend API.
4. Infrastructure: deploy AWS services, storage, networking, security controls, and CI/CD when the app contract is stable.

Start with [`docs/HOW_TO_BUILD.md`](docs/HOW_TO_BUILD.md) for the complete phase-by-phase navigation guide.

## Local Development

```bash
# Research notebooks and training helpers
cd Skin_Lesion_XAI_research
make setup
make register-kernel
make run-notebook

# Backend API
cd ../Skin_Lesion_Classification_backend
make setup
make run

# Frontend app
cd ../Skin_Lesion_Classification_frontend
npm install
npm run dev
```

## Documentation Map

| Doc | Purpose |
| --- | --- |
| [`docs/HOW_TO_BUILD.md`](docs/HOW_TO_BUILD.md) | Build navigation guide and current repo boundaries |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, data flow, and engineering decision questions |
| [`docs/BUILD_PHASE_1_INFRASTRUCTURE.md`](docs/BUILD_PHASE_1_INFRASTRUCTURE.md) | Terraform infrastructure setup |
| [`docs/BUILD_PHASE_2_BACKEND.md`](docs/BUILD_PHASE_2_BACKEND.md) | Production backend sequence and backend engineering patterns |
| [`docs/BUILD_PHASE_3_FRONTEND.md`](docs/BUILD_PHASE_3_FRONTEND.md) | Next.js web app implementation plan |
| [`docs/BUILD_PHASE_4_MOBILE.md`](docs/BUILD_PHASE_4_MOBILE.md) | React Native / Expo mobile plan |
| [`docs/BUILD_PHASE_5_CICD.md`](docs/BUILD_PHASE_5_CICD.md) | CI/CD, MLflow, and deployment plan |
| [`docs/PRODUCTION_BUILD_REVIEW.md`](docs/PRODUCTION_BUILD_REVIEW.md) | Current implementation gaps and corrected build order |
| [`docs/SECURITY_CHECKLIST.md`](docs/SECURITY_CHECKLIST.md) | Pre-launch security checklist |
| [`docs/GDPR_COMPLIANCE.md`](docs/GDPR_COMPLIANCE.md) | Consent, retention, deletion, and privacy requirements |
| [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) | Error lookup and fixes |

## Security Notes

Do not commit datasets, patient images, `.env` files, local virtual environments, generated caches, or large model checkpoints unless a repo intentionally tracks them. Research outputs should be reviewed before publishing because figures and CSVs can reveal dataset or experiment details.
