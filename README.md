# Skin Lesion Classification Platform

Workspace-level architecture, infrastructure, and build guidance for the Skin Lesion Classification platform.

The implementation is split across separate repositories so each repo has a clear job:

| Repository | Purpose |
| --- | --- |
| [`Skin_Lesion_Classification_backend`](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_backend) | FastAPI inference API, PyTorch model serving, Grad-CAM generation, and backend-owned model artifact loading |
| [`Skin_Lesion_Classification_frontend`](https://github.com/saiyudhaplhaomega/Skin_Lesion_Classification_frontend) | Next.js web app for image capture/upload, image-quality guidance, prediction display, heatmap comparison, AI explanations, consent, doctor review, and admin workflows |
| [`Skin_Lesion_XAI_research`](https://github.com/saiyudhaplhaomega/Skin_Lesion_XAI_research) | HAM10000 notebooks, RQ1-RQ6 experiments, research metrics, figures, and training helpers |
| `Skin_Lesion_GRADCAM_Classification` | This workspace: architecture docs, Terraform infrastructure, build roadmap, security docs, and cross-repo coordination |

## Current Build Reality

- Research notebooks and experiment outputs belong in `Skin_Lesion_XAI_research`.
- The frontend should not be the source of truth for notebooks, training scripts, or research outputs.
- The backend consumes model artifacts and exposes API endpoints; it should not document RQ notebooks as backend-owned work.
- The root docs describe the full system and build order.

## Build Order

1. Research: prepare data, run notebooks/training, produce candidate model artifacts and XAI evidence.
2. Frontend product shell: build upload/camera guidance, original/heatmap/overlay comparison, and explanation panel layout.
3. Backend: load model artifacts, add image-quality checks, expose `/health`, `/predict`, `/explain`, and guarded explanation APIs.
4. LLM/RAG: add rule-based fallback first, then online LLM, local desktop LLM, RAG policy, and safety validation.
5. CrewAI: add the optional expert-panel workflow only after the core LLM/RAG path is safe, logged, and testable.
6. Infrastructure: deploy AWS services, storage, networking, security controls, queues, and CI/CD when the app contract is stable.
7. Scale hardening: add multi-region and sharding support after single-region production is stable.

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
| [`docs/FINAL_ARCHITECTURE_DECISIONS.md`](docs/FINAL_ARCHITECTURE_DECISIONS.md) | Finalized decisions for local/dev/staging/prod, sharding, CrewAI, LLM/RAG, and scale strategy |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | System design, data flow, and engineering decision questions |
| [`docs/PRODUCT_LAUNCH_STRATEGY.md`](docs/PRODUCT_LAUNCH_STRATEGY.md) | Product UX, LLM/RAG, guardrails, online/offline modes, and launch roadmap |
| [`docs/BUILD_GUIDE_AUDIT.md`](docs/BUILD_GUIDE_AUDIT.md) | Current guide status, safe reading order, and known build hiccups |
| [`docs/BUILD_PHASE_1_INFRASTRUCTURE.md`](docs/BUILD_PHASE_1_INFRASTRUCTURE.md) | Terraform infrastructure setup |
| [`infra/terraform/README.md`](infra/terraform/README.md) | Terraform module map, safe commands, missing modules, and dev/staging/prod workflow |
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
