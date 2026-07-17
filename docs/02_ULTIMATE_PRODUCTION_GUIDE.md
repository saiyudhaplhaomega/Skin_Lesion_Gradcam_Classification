# Ultimate Production Guide

This is the spine document. It is the answer to "how do I take this project from an empty repo to a launched product?" Every other guide in the curriculum sits underneath it.

Read this once after `00_START_HERE.md` and `01_BUILD_ORDER.md`. Then return to it whenever you finish a phase and need to remember what comes next and why.

The handholding guides tell you the steps. This file tells you the story.

## How To Use This File

- It is sequential. Read top to bottom the first time.
- Each phase has a "Patterns in play" link that drops you into `reference/09_SYSTEM_DESIGN_PATTERNS.md` so you understand the *why* behind the *what*.
- Each phase has gates - if a gate is not green, do not move to the next phase.
- Cross-phase concerns (privacy, observability, cost, model lifecycle) live in their own section because they do not fit one phase.
- The 28-gap checklist tells you which engineering gaps from auto-memory get closed in which phase.
- The production launch checklist is what you walk before you flip the switch.

# Section 1 - Mental Model

The Skin Lesion XAI platform is not a melanoma detector. It is an educational AI-supported tool for monitoring skin lesions, with explainability (Grad-CAM), human-in-the-loop training, and strict role separation (patient, doctor, admin, research reviewer). Call it that, design it as that, build it as that.

If you forget this mental model, the architecture decisions start to drift. You will accidentally build a clinical-grade diagnosis tool, which is regulated very differently. The curriculum is structured so you build the educational tool well, not the regulated tool badly.

## Three things that make this product hard

1. **Medical data is not normal data.** PHI handling, consent state, audit immutability, role-scoped agents - these are not optional layers.
2. **ML is not deterministic software.** Drift, calibration, fairness, distribution shift, promotion gates - patterns you do not need for normal CRUD apps.
3. **Explainability is the product, not a feature.** Grad-CAM honesty (RQ2) is your differentiator. The visual explanation is the deliverable, the prediction is supporting evidence.

## Three things to internalise before coding

1. **Build one thing, run one check, then move on.** The curriculum is intentionally slow. Resist the urge to scaffold everything at once.
2. **The 74 handholding guides are the path, not a buffet.** Sequence matters. A guide that says "after X is working" means it.
3. **The 28 known engineering gaps are not bugs - they are the curriculum.** Each gap is closed in a specific guide. Do not try to close them all at once.

# Section 2 - Day 0

Before you build anything:

## 2.1 Environment

- Windows 10/11 with PowerShell (the curriculum is Windows-first)
- Python 3.10+
- Node.js 20+
- Docker Desktop (Windows)
- VS Code (recommended) with Python, Pyright, ESLint, Prettier extensions
- Git with `core.autocrlf=false` (medical pipelines do not love CRLF surprises)

Do not install AWS CLI, Terraform, kubectl, Helm, or Power BI Desktop yet. The staging guides install them when you actually need them.

## 2.2 Repo Layout

You have one main repo with three sub-repos and an infra folder:

```text
Skin_Lesion_GRADCAM_Classification/        <-- main, you are here
  Skin_Lesion_Classification_backend/      <-- FastAPI, ML serving
  Skin_Lesion_Classification_frontend/     <-- Next.js
  Skin_Lesion_XAI_research/                <-- notebooks, RQ experiments
  infra/                                    <-- Docker, Kubernetes, Terraform
  docs/                                     <-- the curriculum
  graphify-out/                             <-- knowledge graph + Obsidian
  scripts/                                  <-- graphify wrappers, helpers
  Makefile                                  <-- root command menu
```

What this layout block means:

- `Skin_Lesion_GRADCAM_Classification/` is the main workspace containing docs, infra, scripts, and sub-repos.
- `Skin_Lesion_Classification_backend/` contains the FastAPI app, API routes, database models, and ML serving code.
- `Skin_Lesion_Classification_frontend/` contains the Next.js browser app.
- `Skin_Lesion_XAI_research/` contains notebooks, model training, Grad-CAM experiments, and research outputs.
- `infra/` contains infrastructure learning files such as Docker, Kubernetes, and Terraform.
- `docs/` contains this curriculum.
- `graphify-out/` contains generated project-memory artifacts.
- `scripts/` contains helper scripts such as the Graphify wrapper.
- `Makefile` is the root command menu that delegates to repo-specific commands.

Each sub-repo has its own `.git`, `Makefile`, `README.md`, `CLAUDE.md`. Run commands from the right directory; the guides tell you which.

## 2.3 When To Use Which Sub-Repo

| Task | Sub-repo |
|---|---|
| Touching API routes, ML inference, services, DB models | backend |
| Touching UI, dashboards, body maps, upload flows | frontend |
| Training a new model, running RQ notebooks, generating Grad-CAM variants for research | research |
| Editing Dockerfile, Kubernetes manifests, Terraform | infra (from main repo) |
| Editing curriculum, architecture, build order | main repo |

Cross-cutting changes (e.g., new API endpoint that the frontend will use) start in backend, end in frontend, get a guide entry in `docs/`.

## 2.4 First Commands

From the main repo root:

```powershell
make docs-check           # validate doc structure
make backend-test         # run backend tests (after backend exists)
make frontend-build       # build frontend (after frontend exists)
.\scripts\graphify.ps1 query "project overview"
```

What this command block does:

- `make docs-check` validates guide order, links, stale paths, and required safety sections.
- `make backend-test` runs backend tests through the root Makefile after the backend exists.
- `make frontend-build` builds the frontend through the root Makefile after the frontend exists.
- `.\scripts\graphify.ps1 query "project overview"` asks the project knowledge graph for a high-level project summary.
- The comments after `#` explain each command; PowerShell treats them as comments.

If `graphify` says no graph exists yet, run `.\scripts\graphify.ps1 update .` once.

# Section 3 - Phase Ladder

Six phases. Each phase has a goal, the patterns in play, the guides you read, and the gate to pass before moving on.

## Phase 1 - Local Development

**Goal.** Prove the app runs end-to-end on your machine. No cloud, no Docker yet, just code.

**Patterns in play** (from [System Design Patterns](reference/09_SYSTEM_DESIGN_PATTERNS.md)):
- Stateless Service (1.2)
- Idempotency Keys (3.1) - design space, even if not enforced yet
- Connection Pooling (4.4)
- Structured Logging (10.2)
- PHI Tokenization (11.1) - design space
- Role Separation (11.4) - design space

**Guides you read.** All 12 files under `local-dev/`. Read them in order. Each one builds on the last.

**Gate.**
```powershell
make backend-test
make frontend-build
make docs-check
```

What this gate checks:

- `make backend-test` proves backend tests still pass.
- `make frontend-build` proves the frontend still compiles.
- `make docs-check` proves the curriculum links and ordering are still valid.
- All three commands must pass before moving from local development to product features.

All three green. Plus you can do this end-to-end manually:

1. Start backend (`make backend-dev`).
2. Start frontend (`make frontend-dev`).
3. Upload an image. Get a (mocked or real) prediction. See a Grad-CAM heatmap. Refresh. See loading, result, error states cleanly.

If you cannot do that, do not move to Phase 2.

**Mistakes that cost the most time.** Skipping the database migration guide; building UI before backend `/health` works; calling AWS APIs before staging; copying snippets without checking the `Current repo` line.

## Phase 2 - Product Features

**Goal.** Build the medical workflows on top of stable local contracts. Consent, body mapping, safe LLM explanations, lab results, role-based agents.

**Patterns in play.**
- Consent State Machine (11.2)
- Audit-Immutable Log (11.3)
- Role Separation (11.4)
- De-Identification Pipeline (11.5)
- Prompt Injection Mitigation (12.1)
- Refusal Patterns (12.2)
- RAG Source Isolation (12.3)
- Role-Scoped Agents (12.4)
- Output Validation (12.5)
- Evidence Citation (12.6)
- Cache-Aside (4.1) - for the patient dashboard
- Saga choreography vs orchestration (3.4) - for the training-eligibility flow

**Guides you read.** 18 files under `product/`. Follow the sequence at the end of `01_BUILD_ORDER.md`. Do not jump to `15_ADMIN_MARKET_RESEARCH_RAG` before `13_LLM_RAG_AGENT_BOUNDARIES`.

**Gate.** Same `make` checks plus a manual flow:
1. Create a patient. Grant consent (state machine).
2. Upload an image. See body-map pin placement.
3. Receive an LLM-generated educational explanation. Confirm it does not say "diagnosis."
4. Doctor logs in. Sees the case. Submits a review.
5. Admin logs in. Approves training eligibility.
6. Research reviewer logs in. Sees de-identified data only.

If any role can see another role's data, stop. The boundary is broken.

**Mistakes.** Building admin market research RAG with the same vector index as patient education; trusting user-supplied role in JWT without verifying; logging the patient email "for debugging."

## Phase 3 - Staging Transition

**Goal.** Move from "works on my machine" to "works on production-like infrastructure." Docker, Kubernetes locally, Terraform, AWS dev, EKS, SQS workers, observability, CI/CD.

**Patterns in play.**
- Immutable Infrastructure (6.5)
- Bulkhead (2.2)
- Backpressure (2.5)
- Dead-Letter Queue (2.6)
- Outbox Pattern (3.5)
- Saga (3.4)
- Zero Trust (8.1)
- Least Privilege (8.2)
- Defense In Depth (8.3)
- Secret Rotation (8.4)
- RED and USE Metrics (10.1)
- Structured Logging (10.2)
- Distributed Tracing (10.3)
- SLOs and Error Budgets (10.4)
- Runbook-Linked Alerts (10.5)
- Analytics-Safe Views (7.2)

**Guides you read.** 20 files under `staging/`. The cloud cost guide (`00`) comes first. Then Docker, Terraform, Kubernetes, EKS, events, security, observability, CI/CD, Power BI.

**Gate.** All staging resources can be created, validated, and torn down via `make cloud-pause` / `make cloud-shutdown ENV=dev`. The promotion guide says when staging is "done."

**Mistakes.** Skipping `00_CLOUD_COST_CONTROL` and waking up to a $400 bill; provisioning EKS before the Docker image works; sending Power BI at the live patient DB; one IAM role with `AdministratorAccess` "just to get unblocked."

## Phase 4 - Embedded Analytics (Power BI)

**Goal.** Internal analytics for admins, doctors, researchers. Not patient-facing.

**Patterns in play.**
- OLTP vs OLAP Separation (7.1)
- Analytics-Safe Views (7.2)
- Role Separation (11.4)
- PHI Tokenization (11.1)

**Guide you read.** `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md`.

**Gate.** No patient PHI in any Power BI report. Every report reads from an analytics-safe view. Researcher views k-anonymity is at least 5.

**Mistakes.** Letting Power BI hit the live OLTP DB; one shared workspace across roles; embedding via a frontend secret.

## Phase 5 - Production Readiness

**Goal.** Understand production architecture. Plan the path, do not deploy yet.

**Patterns in play.**
- Blue/Green Deployment (6.1)
- Canary Deployment (6.2)
- Shadow Deployment (6.3)
- Feature Flags (6.4)
- Model Registry (9.1)
- Promotion Gates (9.2)
- Calibration (9.3)
- Drift Detection (9.4)
- Ensemble And Disagreement (9.5)
- Active Learning Queue (9.6)
- Frozen Reference Test Set (9.7)
- Circuit Breaker (2.1)
- Timeout Budget (2.4)
- Optimistic Concurrency (3.2)

**Guides you read.** 12 files under `production/`. These are "study guides" first - read them to understand the production architecture; build only when staging is solid.

**Gate.** You can answer:
- What is the rollback procedure for a bad model?
- What metric triggers an automatic canary rollback?
- How does AppConfig feature flag a feature in/out at runtime?
- Where does ElastiCache fit and what TTL is safe?
- What is the EKS auto-heal path on a failed liveness probe?

If you cannot answer those, re-read the relevant guide before doing the work.

**Mistakes.** Going straight to multi-region (out of scope for portfolio); deploying without runbooks; treating production as "staging but with more memory."

## Phase 6 - Reference And Advanced Topics

**Goal.** Topics that are documented but not on the critical path: 3D body mapping, agentic XAI, React Native mobile, recovery notes, full roadmap.

**Guides you read.** 8 files under `reference/`, plus this file (`02_ULTIMATE_PRODUCTION_GUIDE.md`) and the patterns catalog (`reference/09_SYSTEM_DESIGN_PATTERNS.md`).

**Gate.** This phase has no gate. You return to it ad hoc.

# Section 4 - Cross-Phase Concerns

Some concerns are not phase-shaped. They run through every phase and need consistent treatment.

## 4.1 Privacy

Always-on. Every phase touches it. Apply these patterns:
- PHI Tokenization (11.1)
- Consent State Machine (11.2)
- Audit-Immutable Log (11.3)
- Role Separation (11.4)
- De-Identification Pipeline (11.5)
- Signed URLs (8.5)

The rule: privacy is enforced at the *innermost* layer (database, S3 bucket policy, IAM, view). Frontend checks are UX, not security.

## 4.2 Observability

Build it from day 1. Adding observability after launch is 10x more expensive.

In Phase 1: structured logs from every endpoint.
In Phase 2: trace_id propagation; one log line per business event.
In Phase 3: CloudWatch metrics, alarms, runbooks, SLOs.
In Phase 4: per-role analytics dashboards.
In Phase 5: error budgets, drift detection, calibration monitoring.

## 4.3 Cost

The `make cloud-pause` / `make cloud-shutdown` ritual is not optional. Set up Cost Anomaly Detection on day 1 of Phase 3.

Approximate monthly cost ranges (USD) at portfolio scale:

| Phase | Cost | Notes |
|---|---|---|
| Local-dev | $0 | unless using a paid LLM API |
| Staging (paused) | $5-20 | RDS storage, S3, NAT gateway minutes |
| Staging (running) | $80-200/mo | RDS, EKS, NAT, ALB |
| Production-style | $300-600/mo | adds replicas, multi-AZ, observability |

If you forget to pause for a weekend, expect $30 extra.

## 4.4 Model Lifecycle

The ML model goes through: train -> register -> shadow -> canary -> full production -> monitor -> drift detected -> retrain -> compare on frozen reference -> promote new candidate -> rollback ready.

This loop never ends. The pattern catalog Family 9 covers each step.

# Section 5 - Closing The 28 Known Engineering Gaps

The auto-memory tracks 28 engineering gaps. Each one is closed in a specific guide. This is the master sequence.

| # | Gap | Closed in | Phase |
|---|---|---|---|
| 1 | ElastiCache not provisioned | `staging/05_TERRAFORM_STORAGE_SECRETS_AND_ECR_HANDHOLDING.md` + `production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md` | 3, 5 |
| 2 | ECS in public subnet (already corrected in arch) | `staging/03_TERRAFORM_VPC_HANDHOLDING.md` | 3 |
| 3 | No SQS queues for training pipeline | `staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` | 3 |
| 4 | Image to Redis 1h TTL race vs doctor validation | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` (persist to S3 immediately) | 2 |
| 5 | No idempotency on consent endpoint | `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` | 2 |
| 6 | ~~MLflow server not provisioned~~ - found already implemented, verified 2026-07-17: `infra/terraform/mlflow.tf` (EC2 + IAM + security group), deliberately gated behind `var.enable_mlflow_server` (default `false`, pending cost review) - a real cost gate, not missing code. Distinct from the local-dev MLflow tracking server (`05_BUILD_STATUS.md` guide 21, already running locally). | `product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md` | 2 |
| 7 | No circuit breaker on ML inference | `local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md` + `production/12` | 1, 5 |
| 8 | Model confidence not calibrated | `product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md` | 2 |
| 9 | No class distribution gate before retraining | `product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md` | 2 |
| 10 | metadata.csv in S3 not atomic | `product/17` (move metadata to Postgres) | 2 |
| 11 | ECS health-check grace period not set (model loads ~120s) | `staging/08_ECR_AND_EKS_HANDHOLDING.md` | 3 |
| 12 | MLflow version vs S3 model path divergence | `product/17` (atomic rollback script) | 2 |
| 13 | No CAM disagreement scoring in production (RQ4) | `product/12` | 2 |
| 14 | No shadow deployment | `production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md` | 5 |
| 15 | No frozen HAM10000 reference set | `product/12` + research repo | 2 |
| 16 | No model drift detection | `product/12` | 2 |
| 17 | num_workers=0 in DataLoaders | research repo notebooks | research |
| 18 | No AMP (mixed precision) | research repo notebooks | research |
| 19 | ~~Model undertrained (2 epochs)~~ RESOLVED (interim) 2026-07-17, EPOCHS=15 default, no convergence sweep yet | research repo notebooks | research |
| 20 | No ONNX export | `product/17` | 2 |
| 21 | XGBoost-on-frozen-features incompatible with Grad-CAM | already decided not to do (memory) | n/a |
| 22 | No retry policy on external calls | `product/06_SAFE_LLM_EXPLANATION_HANDHOLDING.md` + `staging/13` | 2, 3 |
| 23 | No bulkhead on FastAPI | `product/01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md` | 2 |
| 24 | No timeout budget enforced | `product/01` | 2 |
| 25 | No DLQ on SQS queues | `staging/13` | 3 |
| 26 | No outbox pattern for cross-service events | `staging/13` | 3 |
| 27 | RAG indexes not isolated across roles | `product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md` | 2 |
| 28 | No chatbots implemented yet (all five role agents) | `product/14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md` + `product/15` | 2 |

Mark each one done as you go. Do not deviate from the sequence - the dependencies are real (e.g., you cannot have idempotency on consent before consent has its own table).

# Section 6 - Production Launch Checklist

50 items. Walk this checklist before you flip the switch. If any item is not green, you are not launching.

## Functional

- [ ] Patient can upload image, see prediction with calibrated confidence, see Grad-CAM heatmap
- [ ] Patient can grant, view, and withdraw consent
- [ ] Patient can mark lesion on 2D body map
- [ ] Patient can upload lab result PDF/image with metadata
- [ ] Doctor can see queue, view case, submit verdict
- [ ] Doctor cannot see cases outside their assigned scope
- [ ] Admin can approve training eligibility
- [ ] Admin cannot see free-text doctor notes (or break-glass is logged)
- [ ] Research reviewer sees only de-identified data
- [ ] All five role-scoped agents respond to in-scope queries
- [ ] All five role-scoped agents refuse out-of-scope queries
- [ ] LLM output validation blocks diagnosis-like phrases
- [ ] Citations resolve to real source documents

## Non-Functional

- [ ] p95 latency on `/analysis` < 5s
- [ ] p95 latency on `/explain` < 8s
- [ ] Circuit breaker on `/explain` returns degraded mode under failure
- [ ] Idempotency keys enforced on every POST mutating state
- [ ] Read-replica routing for read-heavy endpoints
- [ ] Connection pool tuned (not at default 5)
- [ ] DLQ alarm on every SQS queue
- [ ] Backpressure on `/analysis` returns 429 under flood

## Compliance

- [ ] No PHI in any log line (audited via grep + lint rule)
- [ ] Audit-immutable log enforced at DB layer
- [ ] Consent state machine has explicit transitions and audit timestamps
- [ ] De-identification pipeline strips EXIF, geo, filename
- [ ] Right-to-be-forgotten flow tested end-to-end
- [ ] Power BI views are aggregated and pseudonymous
- [ ] No PHI in any frontend secret or environment variable
- [ ] Signed URLs TTL <= 15 minutes

## Observability

- [ ] Every endpoint emits RED metrics
- [ ] Every resource emits USE metrics
- [ ] Trace_id propagates across SQS and Lambda
- [ ] Every alarm links to a runbook
- [ ] SLOs defined for each user journey
- [ ] Error budget dashboard exists and is read
- [ ] Logs are structured JSON with required fields
- [ ] Drift detection runs nightly on input/output distribution

## ML

- [ ] Model registry holds current and previous versions
- [ ] Frozen reference test set exists and is locked
- [ ] Promotion gates run automatically; failures block promotion
- [ ] Calibration is recomputed after every retrain
- [ ] CAM disagreement scoring runs in production (RQ4 operationalised)
- [ ] Shadow deployment lane runs the candidate model
- [ ] Canary rollback automated on SLO breach
- [ ] Active learning queue feeds doctor review

## Security

- [ ] No IAM role has `AdministratorAccess`
- [ ] Secrets Manager rotation enabled for all secrets
- [ ] WAF rules deployed
- [ ] mTLS or IAM auth between internal services
- [ ] KMS encryption on RDS, S3, secrets
- [ ] Audit log retention configured per medical retention policy

## Cost

- [ ] Cost Anomaly Detection configured
- [ ] `make cloud-pause ENV=prod` would fail safely (prod is not for pausing)
- [ ] Cost dashboard reviewed weekly

# Section 7 - Post-Launch Operations Playbook

What to watch in the days and weeks after launch.

## Week 1

- Watch all RED metrics daily.
- Watch DLQ depth every shift.
- Confirm no PHI leaks in CloudWatch Logs Insights.
- Confirm canary rollback never fires unexpectedly.
- Document every alert that fires; update runbook if needed.

## Week 4

- Run the drift detection report. Compare input distribution week 1 vs week 4.
- Review consent withdrawal rate.
- Audit role-separation: pick 5 cases, prove cross-role data was not accessed.
- Review cost vs forecast.
- Rotate one secret manually to test the rotation flow.

## Week 12

- First production retraining cycle. Use the active learning queue + doctor-verified cases.
- Run candidate model through promotion gates.
- Shadow deploy. Compare against current model.
- If gates pass and shadow is stable, canary, then full.
- Update the model card.
- Re-calibrate.

## Ongoing

- Quarterly: re-run fairness audit per skin-tone bucket.
- Quarterly: review SLO targets.
- Quarterly: review runbooks. Update or delete stale ones.
- Annually: full security audit.
- Annually: re-verify de-identification pipeline against current re-identification techniques.

# Section 8 - What This Curriculum Does NOT Teach

Honesty about scope, so you do not assume you are ready for things you are not.

| Topic | Why excluded | Where to learn |
|---|---|---|
| HIPAA legal review | Lawyer territory, not engineer territory | Consult a healthcare lawyer |
| FDA SaMD (Software as a Medical Device) pathway | Regulatory; requires QMS, clinical evidence | FDA documentation + a regulatory consultant |
| Real clinical validation | Requires IRB-approved study | Academic / clinical partnership |
| Multi-region active-active | Out of scope at portfolio cost | AWS Well-Architected Reliability pillar |
| Real-world EHR (HL7 / FHIR) integration | Out of scope | HL7 FHIR specification, SMART on FHIR |
| Production-grade red-team of the LLM stack | Specialised | OWASP LLM Top 10, the `engineering:ai-security` skill |
| Real PHI handling for live patients | Regulated; cannot be done as a portfolio project | A real healthcare employer with BAAs |
| Detailed cost modelling | Project-specific | AWS Pricing Calculator, FinOps Foundation |

If you find yourself needing one of these, stop and ask whether you are still building the portfolio project or have crossed into territory the curriculum cannot teach.

# Section 9 - The Honest Bottom Line

The curriculum will make you competent at:
- Backend FastAPI for a healthcare-adjacent product
- Frontend Next.js with a strong design system
- ML lifecycle from research to model registry to canary
- AWS staging-to-production discipline
- Role-scoped LLM and RAG agents
- Healthcare-specific architecture patterns

It will not make you:
- A clinician
- A regulatory specialist
- A multi-region SRE
- A real-world FHIR engineer
- Compliant with HIPAA without a lawyer

Knowing the boundary is the most senior thing you can do.

## Cost Pause / Resume

This guide does not create cloud resources. No pause needed.

When you actually run staging or production, follow the standard ritual:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What this command block does:

- `make cloud-status ENV=dev` checks the dev cloud environment state.
- `make cloud-pause ENV=dev` stops or pauses resources that can be paused.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally destroys dev resources when you confirm destruction.
- `ENV=dev` keeps these commands scoped to development instead of staging or production.

Before starting the next guide:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What this command block does:

- `make cloud-start ENV=dev` resumes or recreates the dev cloud environment.
- `make cloud-status ENV=dev` verifies the environment after startup.
