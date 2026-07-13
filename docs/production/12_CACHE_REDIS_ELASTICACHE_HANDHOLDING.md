# Redis And ElastiCache Handholding Guide

Use this only after authentication, audit logging, and core database flows work.

The app should not require Redis for correctness. PostgreSQL/Aurora DSQL remains the source of truth.

## Goal

Use Redis for short-lived operational cache only:

```text
rate limiting
temporary upload/session hints
short-lived inference result cache
background job coordination hints
```

**What these allowed uses mean:**

- `rate limiting` - Redis is well-suited for tracking request counts per IP or user within a rolling time window (e.g., max 10 uploads per minute). Data loss on restart is acceptable.
- `temporary upload/session hints` - short-lived flags like "user X is currently uploading an image" can live in Redis because they expire naturally and a restart just resets them.
- `short-lived inference result cache` - caching a recent Grad-CAM result for a few minutes avoids re-running the model for the same image when the patient refreshes the page. Set a short TTL.
- `background job coordination hints` - Redis can hold a lightweight "is this job running?" flag to prevent duplicate workers, but the canonical job state must live in the database.

Do not use Redis as the source of truth for:

```text
consent
diagnostic review state
training eligibility
audit logs
lab result records
patient identity
```

**Why these must stay in the database:**

- `consent` - a Redis restart or eviction would silently remove consent state. The patient's rights cannot depend on a cache that can be cleared.
- `diagnostic review state` - if a doctor's verdict is only in Redis and Redis restarts, the verdict is lost without audit trail.
- `training eligibility` - training pipeline decisions must be reproducible and auditable. Redis cannot provide that.
- `audit logs` - audit logs must be immutable and durable. Redis is neither.
- `lab result records` - lab reports are medical records and must persist beyond any cache lifecycle.
- `patient identity` - identity data must be authoritative and recoverable. A cache is not the right store.

## Command Location

Start from:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal to the main workspace root so relative paths and Makefile targets work correctly.

Local Compose changes belong in:

```text
infra/compose/docker-compose.local.yml
```

**What this file is:** the Docker Compose file used to run local multi-service infrastructure (Postgres, Redis, backend) for development.

Backend files belong in:

```text
Skin_Lesion_Classification_backend
```

**What this is:** the FastAPI repository where `cache_service.py` and cache-related backend code live.

Terraform files belong in:

```text
infra/terraform
```

**What this is:** the directory where `elasticache.tf` and other AWS infrastructure definitions go.

## Parameters You Must Set First

```text
LOCAL_REDIS_PORT=6379
REDIS_URL=redis://localhost:6379/0
CACHE_DEFAULT_TTL_SECONDS=300
RATE_LIMIT_TTL_SECONDS=60
INFERENCE_CACHE_TTL_SECONDS=900
ELASTICACHE_NODE_TYPE=cache.t4g.micro for dev
ELASTICACHE_ENGINE_VERSION=<current supported Redis or Valkey version>
```

**What these parameters mean:**

- `LOCAL_REDIS_PORT=6379` - the port Redis listens on inside Docker Compose. The default Redis port; do not change unless you have a port conflict.
- `REDIS_URL=redis://localhost:6379/0` - the connection string the backend uses to connect to Redis. `/0` selects database 0, which is the conventional default.
- `CACHE_DEFAULT_TTL_SECONDS=300` - 5-minute default TTL for cached values. After 300 seconds, Redis automatically evicts the key.
- `RATE_LIMIT_TTL_SECONDS=60` - rate limit counters expire after 60 seconds, resetting the window.
- `INFERENCE_CACHE_TTL_SECONDS=900` - cached Grad-CAM results expire after 15 minutes. Long enough to serve repeat page views but short enough to reflect model updates.
- `ELASTICACHE_NODE_TYPE=cache.t4g.micro for dev` - the smallest and cheapest ElastiCache node type, suitable for learning purposes. Not for production.
- `ELASTICACHE_ENGINE_VERSION` - pin to a specific supported version when you create the Terraform resource. AWS periodically deprecates older versions.

## Step 1: Add Redis Locally

Create or edit:

```text
infra/compose/docker-compose.local.yml
```

**What this file is:** the Docker Compose configuration for local development services. Adding Redis here starts a local Redis container when you run `docker compose up`.

Add:

```yaml
  redis:
    image: redis:7
    container_name: skin-lesion-redis-local
    ports:
      - "6379:6379"
    command: ["redis-server", "--appendonly", "no"]
```

**What this Docker Compose service definition does:**

- `image: redis:7` uses the official Redis 7 Docker image. Redis 7 introduced multi-part AOF and other improvements; use a pinned version for consistency.
- `container_name: skin-lesion-redis-local` gives the container a consistent name so `docker ps`, `docker logs`, and `docker stop` always work with this exact name.
- `ports: "6379:6379"` maps host port 6379 to container port 6379, making the local Redis accessible at `redis://localhost:6379`.
- `command: ["redis-server", "--appendonly", "no"]` starts Redis with Append-Only File persistence disabled. For local development, persistence is not needed and disabling it makes Redis start faster.

Check:

```powershell
docker compose -f infra/compose/docker-compose.local.yml up redis
docker ps --filter "name=skin-lesion-redis-local"
```

**What these commands do:**

- `docker compose -f ... up redis` starts only the Redis service from the Compose file, not the entire stack.
- `docker ps --filter "name=skin-lesion-redis-local"` confirms the container is running by filtering the container list by name.

Expected result:

```text
Redis container is running locally.
```

## Step 2: Add Backend Cache Abstraction

Create:

```text
Skin_Lesion_Classification_backend/app/services/cache_service.py
```

**What this file is:** the cache service abstraction module. It defines the interface and a no-op implementation so the app can run without Redis during local development and tests.

Paste:

```python
from typing import Protocol


class CacheService(Protocol):
    def get(self, key: str) -> str | None:
        ...

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        ...


class NullCacheService:
    def get(self, key: str) -> str | None:
        return None

    def set(self, key: str, value: str, ttl_seconds: int) -> None:
        return None
```

**What this code does:**

- `from typing import Protocol` imports Protocol, which allows structural subtyping - any class with `get` and `set` methods matching the signature satisfies `CacheService` without explicitly inheriting from it.
- `class CacheService(Protocol)` defines the interface. Both `RedisCacheService` and `NullCacheService` are valid implementations as long as they provide `get` and `set` with the right signatures.
- `def get(self, key: str) -> str | None:` returns the cached value as a string, or `None` if the key does not exist or has expired.
- `def set(self, key: str, value: str, ttl_seconds: int) -> None:` stores a value with an expiry time. Every cached key must have a TTL; a key without a TTL can grow forever.
- `class NullCacheService` is the no-op implementation. Its `get` always returns `None` (cache miss) and its `set` does nothing. This lets the app run in test and local environments without a Redis connection.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.services.cache_service import NullCacheService; print(NullCacheService().get('x'))"
```

**What this check does:** imports `NullCacheService` and calls `get`. If it returns `None` without error, the abstraction works correctly without Redis.

Expected result:

```text
Backend works without Redis.
```

Why: cache failure must not break core medical workflow state.

## Step 3: Add ElastiCache Later

Create:

```text
infra/terraform/elasticache.tf
```

**What this file is:** the Terraform file where AWS ElastiCache resources are declared - the subnet group, security group, and the ElastiCache cluster itself.

Add ElastiCache only after local Redis usage is proven and the VPC private subnet path is understood.

Check:

```powershell
cd infra/terraform
terraform fmt
terraform validate
terraform plan
```

**What these commands do:**

- `cd infra/terraform` enters the Terraform directory.
- `terraform fmt` formats all `.tf` files to canonical style. Run this before every commit.
- `terraform validate` checks that all resource types and required arguments are correct without making API calls.
- `terraform plan` shows what AWS resources would be created. Confirm the ElastiCache cluster is in a private subnet, not a public one.

Expected result:

```text
Terraform plans private cache resources only.
No public Redis endpoint is created.
```

## Completion Gate

Redis is ready only when:

```text
app works without Redis
Redis is used only for short-lived cache
TTL is set for every key
no consent/audit/training truth lives in Redis
ElastiCache is private-only
```

**What this gate means:**

- `app works without Redis` - test by stopping the Redis container and hitting all API endpoints. Core workflows must still function.
- `Redis is used only for short-lived cache` - review every Redis `set` call in the codebase. None should store data that must survive a Redis restart.
- `TTL is set for every key` - check that every `cache_service.set(...)` call passes a non-zero `ttl_seconds`. A key without a TTL can grow indefinitely and consume all available memory.
- `no consent/audit/training truth lives in Redis` - grep for Redis writes in the consent, audit, and training eligibility code paths. These writes must not exist.
- `ElastiCache is private-only` - confirm via the Terraform plan or AWS console that the ElastiCache subnet group uses only private subnets. Redis must not be reachable from the internet.

## Concepts You Just Touched

- [Sticky Sessions / Session Affinity (1.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#11-sticky-sessions--session-affinity)
- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service)
- [Session Cache vs Session Store (1.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#13-session-cache-versus-session-store) - the most-violated pattern in young projects
- [Cache-Aside (4.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#41-cache-aside)
- [Write-Through vs Write-Behind (4.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#42-write-through-versus-write-behind) - know what to avoid
- [Circuit Breaker (2.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#21-circuit-breaker) - around the Redis client
- [Defense In Depth (8.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#83-defense-in-depth) - cache is not a security boundary

## Questions You Should Be Able To Answer

1. Why does this guide insist that "the app should not require Redis for correctness"? What breaks if you violate that rule?
2. Which of these belong in Redis: consent record, recently-viewed list, doctor verdict, JWT verified claims, Grad-CAM activation cache? For each, justify.
3. What is the failure mode if Redis is wiped during business hours?
4. Why is a 1-hour TTL on a doctor-review-eligible image a known footgun (auto-memory gap #4)?
5. What does cache-aside invalidation look like for the patient dashboard after the patient adds a new lesion?

If you cannot answer Q1-Q3, re-read the "cache vs store" section above.
If you cannot answer Q4-Q5, read [System Design Patterns: 1.3 Session Cache vs Store](../reference/09_SYSTEM_DESIGN_PATTERNS.md#13-session-cache-versus-session-store) and [4.1 Cache-Aside](../reference/09_SYSTEM_DESIGN_PATTERNS.md#41-cache-aside).

## Common Failure Modes

| Symptom | Likely cause | Where to look |
|---|---|---|
| Doctor review queue empty after Redis restart | data stored in Redis only; gap #4 | persist to S3 + DB first; cache for speed only |
| Cache stampede on miss | many concurrent requests miss simultaneously | request coalescing, or singleflight pattern |
| Stale dashboard after a write | invalidation missing | explicit invalidate on write, not just TTL |
| Cache available but always cold | TTL too short or key mismatch | log hit/miss ratio |
| Redis spike during deploy | warmup logic loads everything at boot | lazy-load instead |

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources to stop billing without destroying data.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the explicit flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` confirms it is healthy before work begins.

If this guide was local-only, no cloud shutdown is needed.
