# ElastiCache Redis Handholding Guide

Use this after Docker Compose local Redis works and Terraform VPC + subnets exist in staging.

This closes Critical Gap #1: "ElastiCache NOT provisioned - in-memory predictions_store breaks with multiple ECS tasks."

## Current Project Implementation

Guide 20 now has local Redis support and optional Terraform scaffolding.

Files created or edited:

```text
Skin_Lesion_Classification_backend/requirements.txt
Skin_Lesion_Classification_backend/app/core/redis_client.py
Skin_Lesion_Classification_backend/app/services/model_service.py
Skin_Lesion_Classification_backend/tests/test_redis_cache.py
infra/compose/docker-compose.local.yml
infra/terraform/redis.tf
infra/terraform/variables.tf
infra/terraform/outputs.tf
infra/terraform/env/staging.tfvars
```

Current implemented behavior:

```text
local Compose already includes Redis 7
backend has a lazy Redis client
model_service has cache_cam and get_cached_cam helpers
CAM cache TTL is 300 seconds
Terraform has enable_elasticache=false by default
```

Current check:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests/test_redis_cache.py -v
```

Expected result:

```text
CAM cache writes with the 300-second TTL and reads back the stored base64 value.
```

Why: this proves the backend cache boundary locally before paying for ElastiCache.

## Goal

Provision a Redis 7.x ElastiCache cluster in the private data subnet, then wire the backend to use it for activation cache, session cache, and rate limiting.

## Why Redis, Not In-Process Cache

The backend runs as multiple Kubernetes pods in the EKS path. In-process Python dicts are per-process.
Pod A generates a CAM activation. Pod B receives the `/explain` request.
Pod B has no activation. The request fails, or you re-run the expensive forward pass.

ElastiCache solves this: all tasks share one cache. See `docs/reference/09_SYSTEM_DESIGN_PATTERNS.md` section 1.1 (Sticky Sessions) and 1.2 (Stateless Service) for the full pattern reasoning.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\infra\terraform
```

**What this does:** moves you to the Terraform root directory. ElastiCache resources are defined here, and all `terraform plan` and `terraform apply` commands run from this location.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Terraform root: `infra/terraform/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Add Redis dependency and backend cache code under `Skin_Lesion_Classification_backend/`.
- Create ElastiCache Terraform files under `infra/terraform/`.
- When switching from Terraform work to backend work, run `cd ..\..\Skin_Lesion_Classification_backend` from `infra/terraform` or start again from the main workspace.

## Step 1: Add Redis Dependency To Backend

In `Skin_Lesion_Classification_backend/requirements.txt`, add:

```text
redis==5.2.1
```

Current state: this dependency is present in `requirements.txt`.

**What this adds:** pins the `redis` Python package at version 5.2.1. This is the official Redis client for Python - it handles connection pooling, AUTH tokens, and TLS (rediss://) connections to ElastiCache without any extra configuration.

Install locally:

```powershell
cd ..\..\Skin_Lesion_Classification_backend
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python -c "import redis; print('redis ok')"
```

**What these commands do:** `cd ..\..\Skin_Lesion_Classification_backend` moves from the Terraform directory up two levels and into the backend repo. `.\.venv\Scripts\Activate.ps1` activates the Python virtual environment. `pip install -r requirements.txt` installs all backend dependencies including the newly added `redis==5.2.1`. The final `python -c` line imports the package and prints a confirmation - if this prints "redis ok" without an ImportError, the dependency is installed and importable.

## Step 2: Create Redis Client Helper

Create `Skin_Lesion_Classification_backend/app/core/redis_client.py`:

```python
"""
Redis client singleton.
REDIS_URL format: redis://:password@host:6379/0
For ElastiCache (TLS): rediss://:token@cluster.abc.cache.amazonaws.com:6379/0
"""
from __future__ import annotations

import os
import redis

_client: redis.Redis | None = None


def get_redis() -> redis.Redis:
    global _client
    if _client is None:
        url = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
        _client = redis.Redis.from_url(url, decode_responses=False, socket_timeout=2.0)
    return _client
```

Current state: this file exists.

**What this module does:** `_client` is a module-level singleton - the connection pool is created once per process and reused. `get_redis()` is lazy: it only creates the client on the first call, then returns the same instance every time after that. `REDIS_URL` defaults to localhost for local dev but picks up the ElastiCache endpoint via environment variable in staging. `decode_responses=False` keeps values as raw bytes - needed because CAM activations are stored as base64-encoded bytes, not text. `socket_timeout=2.0` means Redis operations fail fast after two seconds instead of hanging, which prevents a slow or down cache from stalling an API response.

## Step 3: Store And Retrieve CAM Activations

Update `Skin_Lesion_Classification_backend/app/services/model_service.py` to cache activations.

Add this helper alongside the existing `ModelService`:

```python
import pickle
from app.core.redis_client import get_redis

# TTL reasoning:
# - Patient upload -> polling `/result` takes ~5-10 seconds
# - Patient views heatmap usually within 60 seconds
# - Doctor review can take HOURS - do NOT cache doctor-facing data
# - 5 minutes is enough for the immediate post-prediction heatmap request
# - For doctor review, store the CAM PNG to S3, not Redis
CAM_CACHE_TTL_SECONDS = 300  # 5 minutes - NOT 1 hour (see gap 3 in engineering_gaps.md)


def cache_cam(case_id: str, cam_b64: str) -> None:
    r = get_redis()
    r.setex(f"cam:{case_id}", CAM_CACHE_TTL_SECONDS, cam_b64.encode())


def get_cached_cam(case_id: str) -> str | None:
    r = get_redis()
    val = r.get(f"cam:{case_id}")
    return val.decode() if val else None
```

Current state: `cache_cam`, `get_cached_cam`, and `CAM_CACHE_TTL_SECONDS = 300` exist in `model_service.py`.

**What this helper does:** `CAM_CACHE_TTL_SECONDS = 300` sets the expiry to 5 minutes. The comment explains why: patients view heatmaps within seconds to a minute of upload, so 5 minutes covers the whole patient flow. Doctor reviews take hours, so doctor-facing CAM data goes to S3, not Redis - Redis keys would expire long before a doctor opens the case. `cache_cam` uses `setex` which sets the value and the TTL atomically in one command. The key format `cam:{case_id}` groups all CAM keys under a `cam:` prefix, which makes them easy to find with `keys "cam:*"` during debugging. `get_cached_cam` returns `None` on a cache miss, so callers can check for `None` and fall back to recomputation.

Update the `/explain` endpoint to check Redis before recomputing:

```python
from app.services.model_service import get_cached_cam, cache_cam

@router.get("/analysis/{case_id}/explanation")
async def get_explanation(case_id: str, db: Session = Depends(get_db)):
    # Try cache first
    cam_b64 = get_cached_cam(case_id)
    if cam_b64:
        return ExplanationResponse(case_id=case_id, cam_png_b64=cam_b64)

    # Cache miss - recompute from stored image
    case = db.query(TrainingCase).filter(TrainingCase.id == case_id).first()
    if not case:
        raise HTTPException(status_code=404, detail="Case not found")

    image_bytes = Path(case.image_key).read_bytes()
    result = _model_service.predict(image_bytes, return_cam=True)

    cache_cam(case_id, result.cam_png_b64)   # warm the cache for follow-up requests
    return ExplanationResponse(case_id=case_id, cam_png_b64=result.cam_png_b64)
```

**What this endpoint does:** the cache-check comes first - if the key exists in Redis, the response returns immediately without touching the database or running the model. On a cache miss, the endpoint queries the database for the case, raises 404 if it does not exist, reads the image bytes from the stored path, runs the full model forward pass with `return_cam=True`, then calls `cache_cam` to warm the cache for any follow-up requests. The last `cache_cam` call is important: if the patient or doctor requests the heatmap twice within 5 minutes, the second call hits Redis instead of re-running the GPU inference.

## Step 4: Terraform - ElastiCache Module

Current Terraform path:

```text
infra/terraform/redis.tf
```

The optional resources are controlled by:

```text
enable_elasticache = false
```

Do not set this to true until you have a secure Redis auth token plan and are ready for ElastiCache cost.

Reference module shape if you later split the file into a module:

Create `infra/terraform/modules/elasticache/main.tf`:

```hcl
variable "vpc_id"              {}
variable "subnet_ids"          { type = list(string) }
variable "allowed_sg_id"       {}  # backend EKS workload or node security group
variable "environment"         {}
variable "auth_token_secret_arn" {}  # SSM or Secrets Manager

resource "aws_elasticache_subnet_group" "redis" {
  name       = "skin-lesion-redis-${var.environment}"
  subnet_ids = var.subnet_ids  # private data subnets only
}

resource "aws_security_group" "redis" {
  name   = "skin-lesion-redis-sg-${var.environment}"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [var.allowed_sg_id]  # only from backend ECS tasks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "skin-lesion-redis-${var.environment}"
  description                = "Skin Lesion activation + session cache"
  node_type                  = "cache.t3.micro"   # upgrade to cache.r7g.large for production
  num_cache_clusters         = 1                  # 2 for production HA
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]

  # TLS + auth token - required for HIPAA-adjacent workloads
  transit_encryption_enabled = true
  auth_token                 = data.aws_secretsmanager_secret_version.redis_token.secret_string

  engine_version             = "7.1"
  at_rest_encryption_enabled = true

  # Eviction: LRU on all keys - activation cache is volatile
  parameter_group_name = aws_elasticache_parameter_group.lru.name
}

resource "aws_elasticache_parameter_group" "lru" {
  name   = "skin-lesion-redis-lru-${var.environment}"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }
}

data "aws_secretsmanager_secret_version" "redis_token" {
  secret_id = var.auth_token_secret_arn
}

output "primary_endpoint" {
  value = aws_elasticache_replication_group.redis.primary_endpoint_address
}
```

**What this HCL does:** `aws_elasticache_subnet_group` tells ElastiCache which private subnets it can place nodes into - using private data subnets keeps Redis off the public internet. The `aws_security_group` for Redis only allows inbound on port 6379 from the backend ECS security group (`allowed_sg_id`) - nothing else can reach Redis, not even other services in the VPC. `aws_elasticache_replication_group` is the main cluster resource: `cache.t3.micro` is the cheapest node type for staging, `num_cache_clusters = 1` means a single node (upgrade to 2 for production HA). `transit_encryption_enabled = true` requires TLS on all connections, which is why the REDIS_URL uses `rediss://`. `auth_token` is read from Secrets Manager - the token is never in plaintext in the Terraform files. `at_rest_encryption_enabled = true` encrypts the data on disk. The `aws_elasticache_parameter_group` sets `maxmemory-policy = allkeys-lru` so when Redis runs out of memory it evicts the least recently used keys instead of refusing new writes. `primary_endpoint_address` is the DNS name the backend uses to connect.

Add to your root `main.tf`:

```hcl
module "elasticache" {
  source                  = "./modules/elasticache"
  vpc_id                  = module.vpc.vpc_id
  subnet_ids              = module.vpc.private_data_subnet_ids
  allowed_sg_id           = module.eks.backend_security_group_id
  environment             = var.environment
  auth_token_secret_arn   = aws_secretsmanager_secret.redis_token.arn
}
```

**What this block does:** wires the ElastiCache module into the root Terraform configuration. `module.vpc.private_data_subnet_ids` places Redis in the private data subnets, not the app subnets where EKS workloads run - this is intentional separation so database-tier resources are on different subnets with different routing. The EKS backend workload security group is passed as `allowed_sg_id`, so only backend pods can reach port 6379. `aws_secretsmanager_secret.redis_token.arn` passes the Secrets Manager ARN for the auth token to the module, which reads the actual token value via the data source inside the module.

Apply:

```powershell
cd infra/terraform
terraform plan -var="environment=staging"
terraform apply -var="environment=staging"
```

For the current repo, use:

```powershell
terraform plan -var-file="env/staging.tfvars"
```

This needs AWS credentials because the Terraform backend is remote S3. Ask before running it.

**What these commands do:** `terraform plan -var="environment=staging"` previews all resources Terraform will create for the staging ElastiCache cluster. Read this output carefully before applying - it should show exactly four new resources: the replication group, subnet group, security group, and parameter group. `terraform apply -var="environment=staging"` creates the cluster - ElastiCache clusters take 5-10 minutes to become available, so wait for the apply to finish before testing the connection.

Before applying, read the plan and confirm it shows one ElastiCache replication group, one subnet group, one Redis security group, and the related parameter group. Do not apply if Terraform plans to replace unrelated networking, database, or compute resources.

## Step 5: Update Backend Environment

After Terraform outputs the endpoint, add to your ECS task definition (via SSM or .env):

```text
REDIS_URL=rediss://:YOUR_AUTH_TOKEN@<primary_endpoint>:6379/0
```

**What this value configures:** `rediss://` (two s characters) tells the Redis Python client to use TLS for the connection. One `s` (`redis://`) is plaintext. Since `transit_encryption_enabled = true` in Terraform, the cluster only accepts TLS connections - using `redis://` here will get a connection refused. `:YOUR_AUTH_TOKEN` is the token value from Secrets Manager. `<primary_endpoint>` is replaced with the DNS name from `terraform output`. `/0` selects database 0, which is the default.

## Step 6: Verify Cache Is Working

After deploying:

```powershell
# From a bastion host or ECS exec session:
redis-cli -u $env:REDIS_URL ping
# Expected: PONG

# Run an analysis, then check the key was cached:
redis-cli -u $env:REDIS_URL keys "cam:*"
# Expected: at least one cam:<uuid> key within 60 seconds of a test upload
```

**What these commands verify:** `redis-cli ping` sends a PING command to the cluster and expects PONG back - confirms the connection is working, TLS is negotiating correctly, and the auth token is accepted. If this fails with a connection error, the security group or TLS URL is wrong. `keys "cam:*"` lists all keys matching the CAM cache prefix - after uploading a test image and calling the `/explain` endpoint, a `cam:<uuid>` key should appear. If no key appears, `cache_cam` is not being called or the write is failing silently.

## Stop Point

Do not provision ElastiCache in production until staging has run for at least one week without evictions exceeding 5% of requests.

Check eviction rate:

```powershell
aws cloudwatch get-metric-statistics `
  --namespace AWS/ElastiCache `
  --metric-name Evictions `
  --dimensions Name=CacheClusterId,Value=skin-lesion-redis-staging-0001 `
  --start-time (Get-Date).AddHours(-24).ToString("o") `
  --end-time (Get-Date).ToString("o") `
  --period 3600 `
  --statistics Sum
```

**What this command does:** fetches the `Evictions` metric from CloudWatch for the staging Redis cluster over the last 24 hours, grouped into 1-hour buckets (`--period 3600`). An eviction means Redis ran out of memory and had to remove a key before its TTL expired to make room for new data. If the sum of evictions is high relative to your cache write volume, the node type is too small or CAM_CACHE_TTL_SECONDS is too long. The threshold in the stop point is 5% - if more than 1 in 20 cache writes results in an early eviction, the cluster is undersized for production.

## Concepts You Just Touched

- [Sticky Sessions (1.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#11-sticky-sessions--session-affinity) - why you chose Redis instead of sticky sessions
- [Stateless Service (1.2)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#12-stateless-service) - the backend is now stateless because activations live in Redis
- [TTL And Cache Invalidation (1.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#14-cache-invalidation-and-ttl) - why 5 minutes, not 1 hour

## Questions You Should Be Able To Answer

1. You set CAM_CACHE_TTL_SECONDS = 300. A doctor reviews a case 45 minutes after the patient uploads. Why is 300 seconds correct here, and what stores the CAM for the doctor's view?
2. The Terraform uses `allkeys-lru` as the eviction policy. What would happen if you used `noeviction` instead when Redis fills up?
3. `transit_encryption_enabled = true` in Terraform requires `rediss://` in the connection URL. What does that tell you about the difference between the local and staging Redis connections?
4. The ElastiCache cluster is in `private_data_subnet_ids`. Why is it not in the same subnet as the ECS tasks?
5. If the Redis cluster goes down for 5 minutes, what happens to patients trying to view their heatmap? Design the fallback.

## Cost Pause / Resume

ElastiCache continues to cost money while the replication group exists. Pausing Kubernetes workloads does not pause ElastiCache.

Run from the repo root:

```powershell
make cloud-status ENV=staging
```

**What this does:** reports the current running state of all staging cloud resources. Check this before deciding whether to leave staging up or shut it down.

If you are done testing Redis for the day and this is a disposable staging environment, shut it down:

```powershell
make cloud-shutdown ENV=staging CONFIRM_DESTROY=YES
```

**What this does:** runs `terraform destroy` against the staging workspace, which removes the ElastiCache replication group, subnet group, security group, and parameter group. ElastiCache is billed by the hour while the replication group exists - destroying it stops the charges.

Expected result:

```text
Terraform destroys resources tracked in the staging workspace, including the Redis replication group if this guide created it.
```

**What this means:** the ElastiCache cluster is gone and charges stop. The backend will fall back to `redis://localhost:6379/0` if REDIS_URL is unset, or fail to connect if REDIS_URL still points to the destroyed endpoint.

If you are continuing within the hour, leave staging up only if you are actively testing cache behavior. Record why it is still running before you stop.
