# System Design and Data Engineering Learning Guide

This guide explains why the platform uses certain architecture choices, what alternatives were considered, and what questions you should ask while building. Read it alongside `HOW_TO_BUILD.md`.

## How To Use This Guide

For each component, ask:

1. What problem does this component solve?
2. What happens if it fails?
3. What data does it store or move?
4. Who can access it?
5. What cheaper/simpler option exists?
6. Why are we not using that simpler option for production?

## System Architecture Q&A

### Why use separate repos instead of one monorepo?

**Answer:** Backend, frontend, research, and infrastructure have different release cycles and dependencies. The backend is Python/PyTorch, the frontend is Next.js, research is notebooks and model experiments, and the root repo owns architecture/Terraform.

**Why not one monorepo?** A monorepo is simpler for one checkout, but it makes it easier to mix research artifacts into the frontend app, accidentally deploy notebook dependencies, or couple unrelated release histories.

**Learning check:** Can you explain which repo owns production model serving vs research experiments?

### Why FastAPI for the backend?

**Answer:** FastAPI gives typed request/response validation, automatic OpenAPI docs, async request handling, and a Python-native path for PyTorch model serving.

**Why not Flask?** Flask is simpler, but you would add validation, docs, async handling, and dependency injection patterns manually.

**Why not Django?** Django is strong for database-heavy apps, but this backend is API-first and ML-serving-heavy. Django can work, but it is more framework than needed for the inference service.

**Why not Node.js for the backend?** The ML model and Grad-CAM tooling are Python/PyTorch. Node would require a second Python service anyway.

### Why Next.js for the web frontend?

**Answer:** Next.js gives a structured React app, file-based routing, production build tooling, Vercel deployment, and a good path to responsive mobile web/PWA.

**Why not plain React/Vite?** Vite is excellent and simpler, but Next.js gives routing and deployment conventions that help when the app grows to patient/doctor/admin views.

**Why not only native mobile?** Web is faster to iterate, easier to share, and works on mobile browsers. Native mobile should come after the API and product flow are stable.

### Why AWS ECS Fargate instead of Lambda?

**Answer:** Model serving has large dependencies, slow cold starts, and long-running CPU/GPU-ish work. ECS Fargate gives predictable containers, health checks, rolling deploys, and easier model loading.

**Why not Lambda?** Lambda package size, cold start, timeout, and native dependency management are awkward for PyTorch and Grad-CAM.

**Why not EC2?** EC2 gives more control but more operations work. Fargate is a good middle ground while you are learning production deployment.

### Why a 3-tier VPC?

**Answer:** Public subnets expose only the ALB. App subnets run ECS privately. Data subnets hold RDS/Redis privately. This reduces the attack surface.

**Why not put ECS in public subnets?** Public ECS tasks bypass ALB/WAF protections and become direct internet targets.

**Why not keep everything public during development?** It is faster, but you learn the wrong deployment shape and later rewiring is painful.

### Why ALB plus WAF?

**Answer:** ALB routes HTTPS traffic to ECS services. WAF blocks common web attacks and rate-limit abuse before requests reach your app.

**Why not expose FastAPI directly?** Direct exposure skips centralized TLS, WAF, routing, and health-check integration.

### Why Cognito?

**Answer:** Cognito gives managed signup, email verification, JWT issuance, MFA, and hosted identity primitives without building auth from scratch.

**Why not custom auth tables only?** Password handling, MFA, refresh tokens, account recovery, and secure token issuance are easy to get wrong.

**Why not Auth0/Clerk?** They can be better developer experiences, but Cognito integrates naturally with AWS infrastructure and IAM.

### Why PostgreSQL/RDS?

**Answer:** Predictions, users, expert opinions, consent records, deletion requests, and audit metadata are relational and need consistency.

**Why not DynamoDB?** DynamoDB is strong for high-scale key-value access, but relational workflows and audit queries are easier to model first in PostgreSQL.

### Why Redis/ElastiCache?

**Answer:** `/predict` and `/explain` are separate calls. In production, different ECS tasks may handle them. Redis gives all tasks a shared short-lived cache for prediction metadata and explanation results.

**Why not an in-memory Python dict?** It works locally with one process and fails randomly with multiple ECS tasks.

**Why not store images only in Redis?** Redis is not durable storage. Store durable images in S3 when consent happens; use Redis for short-lived cache.

### Why S3 for images and model artifacts?

**Answer:** S3 is durable, cheap, versionable object storage. It is a good fit for raw uploads, curated training images, model artifacts, and exports.

**Why not store images in PostgreSQL?** Large binary objects make backups, queries, and database performance worse. Store paths/metadata in Postgres and objects in S3.

### Why SQS for training pipeline events?

**Answer:** Consent, doctor validation, admin approval, and S3 writes can fail independently. SQS gives retry, buffering, and dead-letter queues.

**Why not direct API calls between steps?** A failure halfway through can lose training cases unless you build your own retry/state machine.

### Why MLflow?

**Answer:** MLflow tracks experiments, metrics, artifacts, and model versions. It gives a controlled promotion path from candidate model to production model.

**Why not just copy `.pth` files to S3?** S3 alone does not record run metadata, metrics, promotion decisions, or lineage well.

### Why CloudWatch and structured logs?

**Answer:** You need to know when latency rises, errors spike, model loading fails, or upload failures increase. Structured logs and request IDs let you trace incidents.

**Why not print logs only?** Plain prints are hard to search, correlate, or alert on.

## Data Engineering Q&A

### What data exists in the platform?

| Data | Storage | Why |
|------|---------|-----|
| User account metadata | PostgreSQL | relational, access-controlled |
| Prediction metadata | PostgreSQL | audit/history |
| Temporary prediction cache | Redis | fast short-lived lookup |
| Raw uploaded image after consent | S3 | durable object storage |
| Doctor opinion | PostgreSQL | relational workflow |
| Training case state | PostgreSQL | state machine and audit |
| Model artifacts | S3 + MLflow | versioned model lineage |
| Deletion/export requests | PostgreSQL | GDPR tracking |

### Why patient-level train/val/test split?

**Answer:** The same patient can have multiple lesion images. If images from the same patient appear in both train and test, the model can leak patient-specific features and overstate performance.

**Alternative:** Random image-level split. Easier, but less scientifically valid.

### Why store raw and preprocessed images separately?

**Answer:** Raw images preserve original evidence. Preprocessed images make retraining reproducible and faster.

**Alternative:** Store only tensors. Faster for training, but loses image quality and makes future preprocessing changes impossible.

### What is data lineage?

**Answer:** Lineage answers: which user image became which training case, which training run used it, and which model version resulted.

**Tables to plan:**

```sql
training_runs(id, model_version, started_at, completed_at, metrics_json)
training_run_cases(training_run_id, training_case_id)
```

### Why idempotency on consent?

**Answer:** Users double-click. Networks retry. Mobile clients resend requests. The same `prediction_id` should create one training case, not duplicates.

**Implementation idea:**

```sql
CREATE UNIQUE INDEX idx_training_cases_prediction_id
ON training_cases(prediction_id);
```

### Why class distribution gates before retraining?

**Answer:** If new approved data is skewed, retraining can make the model worse for minority classes.

**Question to ask:** What is the minimum number of approved examples per class before retraining?

### Why demographic metadata?

**Answer:** Skin lesion datasets can underrepresent skin tones, regions, ages, and camera types. Without metadata, you cannot measure fairness or drift.

**Minimum schema:**

```json
{
  "age": 45,
  "sex": "female",
  "localization": "back",
  "skin_tone": null,
  "camera_type": null
}
```

### Why deletion request tracking?

**Answer:** GDPR deletion must be auditable. You need to know when the request was made, what was deleted, what could not be deleted because it was already used in training, and when the request completed.

### Why EXIF stripping?

**Answer:** Uploaded images may contain location, device, timestamp, or other private metadata. Strip EXIF before storage/display unless you explicitly need it and have consent.

### Why model drift monitoring?

**Answer:** Real user images may differ from HAM10000: lighting, cameras, skin tones, lesion types, geography. Drift monitoring catches distribution changes before model quality silently degrades.

## Questions To Answer Before Each Build Phase

### Before backend

- What is the exact request/response schema for `/predict`?
- What file types and max file size are allowed?
- What happens if the model is not loaded?
- What timeout is acceptable for prediction and explanation?
- Where is the image stored before and after consent?

### Before frontend

- What should a patient see if confidence is low?
- What should a doctor see that a patient should not?
- How does the UI behave on a slow phone connection?
- Does every interactive element have a label and keyboard/focus behavior?

### Before infrastructure

- Which resources are public?
- Which resources are private?
- Which security group allows which source?
- How does a failed deployment roll back?
- What is the monthly cost in dev vs prod?

### Before ML production

- Is confidence calibrated?
- Which frozen test set protects against regressions?
- What model metrics are required before promotion?
- How do you compare candidate vs production model?
- What demographic slices must be reported?

