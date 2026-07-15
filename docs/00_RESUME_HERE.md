# Resume Here

Pick up the project from this doc every time you open a new session.
Run the local session commands at the top, then find your current position in the checklist below.

---

## Latest Verified State (2026-07-15)

AWS SSO was refreshed this session (`aws sso login --profile skin-lesion-learning-dev`). With real provider state available, `terraform init -backend=false && terraform validate` ran for real for the first time and found 3 real errors in `infra/terraform/modules/aurora_dsql`: the module referenced `aws_dsql_cluster.main.endpoint` and `.id`, neither of which that resource exports (provider 5.100.0 only exposes `.identifier` and `.arn`; there is no endpoint attribute at all - the connection hostname has to be constructed as `{identifier}.dsql.{region}.on.aws`). Fixed by adding an `aws_region` input to the module and deriving the endpoint via a local instead of a nonexistent attribute. `terraform validate` now passes clean. Also confirmed no EKS cluster exists yet in eu-central-1 or us-east-1 under this account - consistent with the infra still being at learning-scaffold stage, not deployed.

## Latest Verified State (2026-07-14)

Everything in this section was independently verified this session (tests actually run, builds actually completed, changes actually checked in a real browser or against a real database/container where relevant) - not assumed from reading code. It supersedes the "Current Project State" table below, which is stale (dated 2026-05-13, predates the mobile app, all CI, and the security/eval campaign entirely). That table is left as historical record, not corrected line-by-line, since a full rewrite risks introducing new inaccuracies in sections not directly re-verified this session (in particular, anything about the research repo - out of scope this session by explicit instruction).

**All four repos build/test/lint clean as of the commits below** (parent, backend, frontend, mobile). Nothing is left uncommitted.

| Repo | Verified state |
|---|---|
| Backend | 491 tests passing, mypy clean (154 files), ruff clean (was 47 findings), bandit clean. `scripts/eval_status_report.py` reports every documented model-promotion gate (G1-G10) as PASS/FAIL/NOT_CHECKABLE against real imported data; `app/eval/rag_eval_runner.py` now actually enforces its own documented recall quality gate (previously computed but never gated on - a real bug). A real pgvector container run this session found and fixed 4 previously-undetected bugs in the Round 22 hybrid retrieval feature (missing `::vector` casts, a missing transaction rollback, a stub-embedding function that could produce NaN, and an `ivfflat` index that returned empty results at small table sizes). Lab-result file uploads were silently discarding files while returning success - now actually upload to S3. |
| Frontend | Next.js 16.2.10 + React 19 (was 14/18, had 2 unpatched CVEs). `npm run lint` was completely broken since that upgrade (Next 16 removed `next lint`) and had zero CI coverage - fixed, and found real issues once it ran for real, including one actual bug (a body-map front/back toggle that changed state but never changed what rendered). Fonts migrated to `next/font/google` in variable mode (the previous static-weight config was missing weights 650/800 that the stylesheet actually uses - would have rendered as browser-synthesized fake bold). `npm audit`: 0 vulnerabilities (was 2 - Next's own bundled postcss, fixed via an `overrides` entry). |
| Mobile | Full app built (M1-M9). Session-recovery bugs found and fixed in the Cognito auth flow (was clearing valid sessions on network blips, never retried on token expiry, and 3 of 4 upload/fetch call sites bypassed the retry logic entirely). CI added (none existed before) - typecheck, 14 jest tests, lint, expo-doctor, web export. |
| Parent (this repo) | `docs-validate.ps1` (the parent CI's own docs-check) was failing - fixed two real bugs in the check itself. Terraform's Kubernetes manifests (`eks-dev`, `eks-prod`) server-side dry-run validated against a real local Kubernetes API server, not just client-side YAML linting. |

**Genuinely blocked on things only the user can do** (not attempted further, to avoid guessing at credentials or making a unilateral call on a decision that isn't mine to make):

- ~~AWS SSO session expired~~ - RESOLVED 2026-07-15. Refreshed via `aws sso login --profile skin-lesion-learning-dev`; `terraform validate` now runs clean against real provider state (see above). No EKS cluster is provisioned yet, so there is nothing live to check further until infra work actually deploys one.
- No `MINIMAX_API_KEY` configured - blocks `run_live_generation_eval` (the live, manual-only generation-quality evaluator in `app/eval/generation_eval_runner.py`) and any live-embedding run of `scripts/run_rag_eval.py` against `admin_market_research`'s real retriever (only tested this session with a non-semantic hash-stub embedding and 3 seeded documents - retrieval *works*, but ranking *quality* under real embeddings and real data volume is still unverified).
- Two decisions that are the user's to make, not mine: whether to provision a dedicated S3 bucket for lab results (the current setup reuses the lesion-image bucket, which forecloses S3 Object Lock/WORM later since that can only be enabled at bucket creation), and what clinical region taxonomy to use for Grad-CAM explanations (`explanation_facts_service.py` still hardcodes `"central lesion area"` for every prediction - a real accuracy gap in patient-facing AI explanation text, not something to guess at without review).

For the detailed round-by-round trail of every fix this session (with verification evidence, MiniMax review findings, and adjudication of disagreements), see `docs/07_RAG_EVAL_AND_MULTI_AGENT_EXECUTION_PLAN.md`'s Round 21 onward - that file is excluded from git (`.git/info/exclude`) since it names the AI tools used, but it persists locally across sessions.

---

## Session Start Commands

Run these every time, from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
.\scripts\graphify.ps1 cluster-only graphify-out/graph.json
```

What this command block does:

- `cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification` moves the terminal into the main project workspace. Run this first so every relative path in the docs points to the right place.
- `.\scripts\graphify.ps1 cluster-only graphify-out/graph.json` refreshes the existing knowledge-graph community/report view from the saved graph file. It does not rebuild code extraction; it reorganizes the graph output that already exists.

If `graphify-out/.needs_update` exists, run this instead before anything else:

```powershell
.\scripts\graphify.ps1 update .
Remove-Item graphify-out/.needs_update -ErrorAction SilentlyContinue
```

What this command block does:

- `.\scripts\graphify.ps1 update .` asks the repo Graphify wrapper to refresh graph extraction for the current project directory.
- `Remove-Item graphify-out/.needs_update -ErrorAction SilentlyContinue` removes the marker file after the graph has been refreshed.
- `-ErrorAction SilentlyContinue` prevents PowerShell from stopping if the marker file is already gone.

Do not run cloud status commands until `docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md` has created `infra/terraform/Makefile`.

---

## Current Project State (as of 2026-05-13)

| Area | Status | Notes |
|---|---|---|
| Research (RQ1-RQ6) | Complete | ResNet50 + GradCAM++ wins; model undertrained at 2 epochs |
| Backend scaffold | Ready | FastAPI repo exists with the first `/health` app and test |
| Frontend scaffold | Ready | Next.js 14 repo exists; no product components yet |
| Local docs (82 guides) | Complete, pending validation | All phases: local-dev, product, staging, production, reference |
| Terraform learning area | Learning scaffold | `infra/terraform/` has README only; no `.tf` files yet. Root `main.tf` and helper Makefile created later by staging guides |
| ElastiCache Redis | NOT provisioned | Critical gap - see engineering_gaps.md |
| SQS queues | NOT provisioned | Critical gap |
| MLflow server | NOT provisioned | Critical gap |
| ECS subnet placement | Wrong (public) | Critical gap - tasks must be in private subnet |
| Model training | DISCREPANCY | EPOCHS ambiguity: train_backbones.py=2, run_training.py=10, docs say >=15. No authoritative value. num_workers=0, no AMP — see 15_AMP_TRAINING_OPTIMIZATION.md |
| CI/CD | Not started | After local tests pass |

---

## Where To Start (Pick Your Current Phase)

### I have not built anything yet - start here

```powershell
# 1. Get into the backend repo and activate the venv
cd Skin_Lesion_Classification_backend
py -0p
py -3.13 -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt

# 2. Verify the scaffold
python --version
pip list | Select-String "fastapi"
```

What this command block does:

- `cd Skin_Lesion_Classification_backend` moves from the main workspace into the backend repository.
- `py -0p` lists installed Python interpreters so you can confirm Python 3.13 exists.
- `py -3.13 -m venv .venv` creates a backend-only virtual environment using Python 3.13.
- `.\.venv\Scripts\Activate.ps1` activates that environment in the current PowerShell terminal.
- `python -m pip install --upgrade pip` upgrades pip inside `.venv`, not globally.
- `python -m pip install -r requirements-dev.txt` installs runtime and development dependencies for local backend work.
- `python --version` confirms the active interpreter is the one from the virtual environment.
- `pip list | Select-String "fastapi"` checks that FastAPI installed successfully.

Expected: `python --version` starts with `Python 3.13`. `requirements-dev.txt` already includes `requirements.txt`, so install the dev file only for local work.

Then open: `docs/local-dev/01_LOCAL_BACKEND_FIRST.md`

---

### I have a working /health endpoint - continue backend

Open: `docs/local-dev/03_BACKEND_API_HANDHOLDING.md`

Check you are here:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --port 8000
# in a second terminal:
curl http://localhost:8000/health
```

What this command block does:

- The first `cd` returns to the main workspace so the next relative path is predictable.
- `cd Skin_Lesion_Classification_backend` enters the backend repo.
- `.\.venv\Scripts\Activate.ps1` activates the backend Python environment.
- `uvicorn app.main:app --reload --port 8000` starts the FastAPI app from `app/main.py` on local port `8000`; `--reload` restarts the server when files change.
- `curl http://localhost:8000/health` runs in a second terminal and sends a health-check request to the running backend.

Expected: `{"status":"ok"}`

---

### I have /health and the upload mock - add the database

Open: `docs/local-dev/04_DATABASE_AND_MIGRATIONS_HANDHOLDING.md`

Check you are here:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
alembic current
```

What this command block does:

- `cd Skin_Lesion_Classification_backend` enters the backend repo where Alembic config lives.
- `.\.venv\Scripts\Activate.ps1` activates the Python environment that has Alembic installed.
- `alembic current` prints the migration revision currently applied to the configured database.

Expected: a migration revision hash, not an error.

---

### I have the database - add the real model and Grad-CAM

Open: `docs/local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md`

Check you are here:

```powershell
cd Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
pytest
curl -X POST http://localhost:8000/api/v1/analysis -F "image=@sample.jpg"
```

What this command block does:

- `pytest` runs backend tests from the backend repository.
- `curl -X POST ...` manually sends an image upload request to the analysis endpoint.
- `-X POST` chooses the HTTP method.
- `-F "image=@sample.jpg"` sends a multipart form field named `image`, using the local file `sample.jpg`.

Expected: tests pass, analysis endpoint returns label + confidence.

---

### I have model inference - wire up Docker Compose

Open: `docs/local-dev/12_DOCKER_COMPOSE_HANDHOLDING.md`

Check you are here:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up postgres redis backend -d
curl http://localhost:8000/health
```

What this command block does:

- `docker compose -f infra/compose/docker-compose.local.yml` tells Docker Compose which local stack file to use.
- `up postgres redis backend -d` starts only the database, cache, and backend services in the background.
- `curl http://localhost:8000/health` confirms the backend is reachable through the Compose port mapping.

Expected: all containers healthy.

---

### I have Docker Compose working - build product features

Work through `docs/product/` in order, starting at `01_BACKEND_DOMAIN_ARCHITECTURE_HANDHOLDING.md`.

Before each guide, check the previous one still passes:

```powershell
pytest
curl http://localhost:8000/health
```

What this command block does:

- `pytest` reruns backend tests before moving to product work.
- `curl http://localhost:8000/health` confirms the local API server still responds.
- This prevents you from building product features on a broken local foundation.

---

### I have product features locally - move to staging

Open: `docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md` first (cost safety), then `01_DOCKER_HANDHOLDING.md`.

After the cost-control guide creates `infra/terraform/Makefile`, check cloud status before touching cloud resources:

```powershell
make cloud-status ENV=staging
```

What this command does:

- `make cloud-status` runs the Terraform helper target that checks cloud resource status.
- `ENV=staging` tells the Makefile to inspect the staging environment, not dev or production.

---

## The 6 Critical Gaps (Must Close Before Production)

These are the highest-priority engineering gaps. Each has a guide:

| Gap | Guide |
|---|---|
| EPOCHS ambiguity (2 vs 10 vs >=15) | Research repo + resolve before any ML gap work |
| ElastiCache Redis not provisioned | `docs/staging/20_ELASTICACHE_REDIS_HANDHOLDING.md` |
| ECS tasks in public subnet | `docs/staging/08_ECR_AND_EKS_HANDHOLDING.md` (subnet section) |
| No SQS queues | `docs/staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md` |
| No MLflow server | `docs/staging/21_MLFLOW_SERVER_HANDHOLDING.md` |
| Consent endpoint not idempotent | `docs/product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md` |
| Model undertrained (2 epochs) | `docs/local-dev/15_AMP_TRAINING_OPTIMIZATION.md` (EPOCHS must be resolved first) |

---

## The 28-Gap Master List

Full list: `C:\Users\saiyu\.claude\projects\...\memory\engineering_gaps.md`

Quick reference categories:

- **Critical (production-blocking):** gaps 1-6 in the table above
- **High priority:** circuit breaker on inference, confidence calibration, class distribution gate before retraining
- **AI safety:** CAM disagreement scoring, shadow deployment, regression test set, drift detection
- **ML training:** num_workers, AMP, proper epoch count, ONNX export

### Gap 19 Detail (EPOCHS Ambiguity)

| Gap | Description | Notes |
|-----|-------------|-------|
| 19 | Model undertrained — EPOCHS ambiguity: train_backbones.py=2, run_training.py=10, docs say >=15. No single authoritative value. EPOCHS must be resolved before any training pipeline gap can be trusted. | See M1, M2, M3 below |

### Missing Gaps (Not in Original 28)

| Gap | Description |
|-----|-------------|
| M1 | No frozen reference evaluation — not in 28-gap list |
| M2 | No model promotion gate — not in 28-gap list |
| M3 | Makefile facade — commands exist, implementation doesn't — not in 28-gap list |

---

## Key File Paths

```text
Backend:    Skin_Lesion_Classification_backend/
Frontend:   Skin_Lesion_Classification_frontend/
Research:   Skin_Lesion_XAI_research/
Infra:      infra/terraform/
Compose:    infra/compose/

Docs root:  docs/
  Local:    docs/local-dev/     (01-15)
  Product:  docs/product/       (01-18)
  Staging:  docs/staging/       (00-21)
  Prod:     docs/production/    (01-12)
  Ref:      docs/reference/     (01-09)

System design patterns: docs/reference/09_SYSTEM_DESIGN_PATTERNS.md
Memory:     C:\Users\saiyu\.claude\projects\...\memory\
```

What this path block means:

- `Backend` is where FastAPI, API routes, database models, and inference services live.
- `Frontend` is where the Next.js app, UI components, and browser API calls live.
- `Research` is where notebooks, model training, Grad-CAM experiments, and evaluation scripts live.
- `Infra` and `Compose` are where local/staging infrastructure learning files live.
- `Docs root` is the tutorial curriculum.
- `System design patterns` is the concept reference linked by many guides.
- `Memory` points to local project memory notes outside the repository.

---

## Three Rules For Every Session

1. **Never skip ahead.** If the previous guide's check command fails, fix it before opening the next guide.
2. **Cloud cost.** After `docs/staging/00_CLOUD_COST_CONTROL_HANDHOLDING.md` creates the Terraform helper Makefile, run `make cloud-status ENV=dev` before cloud work and `make cloud-pause ENV=dev` before stopping.
3. **No GitHub Actions / Terraform / Kubernetes** until all local checks pass.
