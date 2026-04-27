# Production Build Review and Learning Roadmap

Use this document as a reality check while building. The existing guides describe the target system well, but several parts are still plans rather than implemented code. Build in small, verifiable slices and do not mark a phase complete until the checks at the end pass.

## Current Repository Reality

| Area | Current state | What this means |
|------|---------------|-----------------|
| Root repo | Architecture docs and Terraform modules exist | Good planning base, but docs must not be mistaken for a working product |
| Backend repo | ML utilities exist; FastAPI app is not built yet | Start with `app/main.py`, config, health endpoint, tests, and Docker |
| Frontend repo | Clean Next.js scaffold exists | Build patient flow first before doctor/admin dashboards |
| Research repo | RQ notebooks, figures, metrics, and training scripts exist | Keep research code separate from production frontend |
| Mobile app | Planned only | Build after web/backend contract is stable |
| CI/CD | Planned in docs only | Add simple CI before deployment workflows |
| Terraform | Foundation modules exist | Add missing runtime modules before production deploy |

## Guide Update Map

| Guide | What to use it for | What needed correction |
|-------|--------------------|------------------------|
| `HOW_TO_BUILD.md` | Main navigation and build order | Add a Phase 0 implementation audit before AWS work |
| `SYSTEM_DESIGN_LEARNING_GUIDE.md` | Design learning | Explains why each major choice was made and what alternatives were rejected |
| `BUILD_PHASE_1_INFRASTRUCTURE.md` | Terraform build | Make missing modules and VPC wiring explicit blockers |
| `BUILD_PHASE_2_BACKEND.md` | FastAPI backend | Update dependency snippets and add a minimal vertical slice first |
| `BUILD_PHASE_3_FRONTEND.md` | Next.js frontend | Clarify current scaffold state and mobile-first/PWA requirements |
| `BUILD_PHASE_4_MOBILE.md` | Expo mobile | Clarify that mobile waits until backend/web API is stable |
| `BUILD_PHASE_5_CICD.md` | GitHub Actions/deploy | Add CI-first path, OIDC recommendation, and security scans |
| `SECURITY_CHECKLIST.md` | Launch security signoff | Add threat model, EXIF stripping, malware scanning, and audit log checks |
| `DEVELOPMENT_CHECKLIST.md` | Daily tracker | Keep it synced with actual implementation progress |

## Highest-Value Build Order

1. Build the smallest working backend API: `GET /health`, mocked `POST /api/v1/predict`, file validation, tests, and Docker.
2. Build the smallest working frontend: upload image, call `/predict`, show result, mobile-first layout, error/loading states.
3. Replace the mock model with real model loading from a local checkpoint.
4. Add explainability with `/api/v1/explain`, Redis cache, timeout/circuit breaker, and frontend heatmap viewer.
5. Add consent and curation with idempotent consent, S3 persistence at consent time, doctor review, admin approval, SQS, and DLQs.
6. Add production infrastructure: ECR, ECS service/task definition, ElastiCache, SQS, MLflow, Route53/ACM, CloudWatch alarms.
7. Add CI/CD: CI checks, Terraform plan, Docker build, container scan, staging deploy, production approval.
8. Add mobile: PWA first for fast mobile coverage, then Expo after the API stabilizes.

## Code Snippet Quality Notes

Several snippets in the phase guides are learning scaffolds, not copy-paste production code. Treat snippets as patterns unless the guide says "use exactly this".

Specific corrections:

- Backend dependency versions should match the backend repo's `requirements.txt` unless you intentionally upgrade everything together.
- Use `opencv-python-headless` for backend Docker images unless a GUI dependency is needed.
- Do not store tensors or raw images in Redis with `pickle` for production. Prefer object storage for images and JSON/msgpack metadata in Redis.
- Use `time.perf_counter()` for latency measurements, not wall-clock time.
- FastAPI tests should use modern `httpx` ASGI transports with current `httpx`.
- CI/CD should use GitHub OIDC to AWS instead of long-lived `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` when possible.
- MLflow in production should be a private service with RDS backend and S3 artifact store, not `file:./mlruns`.

## Production Blockers

Do not call the system production-ready until these exist:

- FastAPI app with real endpoints and tests
- Next.js patient upload/predict/explain flow
- Dockerfile and local compose stack
- ECR and ECS service/task definition
- Redis/ElastiCache for shared prediction/explain cache
- SQS and DLQs for consent/review/approval pipeline
- MLflow server and model promotion policy
- CI workflows for backend, frontend, Terraform, and Docker scans
- CloudWatch alarms, structured logs, request IDs, and audit logs
- Calibrated confidence and medical safety language
- GDPR export/delete endpoints implemented as code
- Threat model and launch security checklist completed

## Repo-Local Build Files

The backend and frontend repos also have local build guides:

- `Skin_Lesion_Classification_backend/BUILD_BACKEND.md`
- `Skin_Lesion_Classification_frontend/BUILD_FRONTEND.md`

They are not redundant. Use them as beginner-friendly, repo-local tutorials. Use the root `docs/BUILD_PHASE_*.md` files for production architecture, infrastructure, security, and cross-repo sequencing.

Rule of thumb:

- If you are learning the first files to create in one repo, open the repo-local `BUILD_*.md`.
- If you are making production decisions, open the root `docs/` guide.
- If the two disagree, treat the root `docs/` guide as the production source of truth and update the repo-local guide.
