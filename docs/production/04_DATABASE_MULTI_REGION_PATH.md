# Database And Multi-Region Path

Start with local Postgres for learning.

Do not start with multi-region active-active. It is a later learning stage.

## Database Order

1. Local Postgres.
2. Local migrations.
3. Single-region Aurora DSQL in staging.
4. Aurora PostgreSQL fallback only if DSQL blocks progress.
5. Multi-region Aurora DSQL learning last.

## Aurora DSQL Decision

Aurora DSQL is the planned cloud database target for this project.

Use it after local Postgres and local migrations are understood. Do not skip local Postgres, because local development is where the schema, migrations, tests, and app behavior become stable.

Before calling staging complete, validate:

- SQLAlchemy compatibility
- Alembic migrations
- transaction behavior
- latency
- failure behavior
- cost
- regional availability
- operational limits
- extension support (in particular, do not assume `pgvector` works on DSQL)

### The vector index is a deliberate carve-out from "DSQL is primary"

DSQL stays the primary database for transactional data: cases, consent, audit, and the rest. The one component that does not live on DSQL is the RAG vector index, because it needs the `pgvector` extension and DSQL's extension support does not include it as far as is known. Put the vector index on Aurora PostgreSQL or a small dedicated RDS PostgreSQL with pgvector, in the same VPC, or use OpenSearch Serverless vector search instead. This keeps the "DSQL primary" rule intact for OLTP while giving retrieval a store that can actually do similarity search. Full reasoning and the role-isolation rules are in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.3, and the RAG guides `product/07`, `product/14`, and `product/15` point here.

## Fallback Rule

Keep the app behind a normal database URL:

```text
DATABASE_URL=...
```

**What this means:**

- `DATABASE_URL` is an environment variable that holds the full database connection string, including host, port, username, password, and database name.
- The app reads this single variable and does not care whether it points to local Postgres, Aurora PostgreSQL, or Aurora DSQL.
- Swapping databases between environments is a config change, not a code change.

Why: the backend should use one connection setting across environments.

Important: `DATABASE_URL` does not make every PostgreSQL-compatible database identical. Migrations and transaction behavior still need explicit DSQL validation.

If DSQL blocks you, use Aurora PostgreSQL only as a documented fallback and return to DSQL after the blocker is understood.

## Multi-Region Active-Active

Multi-region Aurora DSQL is advanced because you must answer:

- where writes go
- how conflicts are handled
- what happens during regional failure
- how users are routed
- how secrets and data are replicated
- what RTO and RPO mean for each service

## RTO And RPO

RTO means:

```text
How long can the system be down?
```

**What RTO means in practice:** RTO (Recovery Time Objective) is the maximum acceptable time between a failure and full service restoration. A shorter RTO means you need faster failover mechanisms and more automation.

RPO means:

```text
How much data can be lost?
```

**What RPO means in practice:** RPO (Recovery Point Objective) is the maximum acceptable amount of data loss measured in time. An RPO of zero means every committed write must survive a failure, which typically requires synchronous replication.

For learning, define simple targets later:

```text
dev RTO: hours
dev RPO: acceptable to recreate
production-style RTO: minutes
production-style RPO: near zero for patient workflow state
```

**What these targets mean:**

- `dev RTO: hours` - for development, it is acceptable to spend hours restoring the environment after a failure.
- `dev RPO: acceptable to recreate` - for development, data loss is acceptable; you can recreate seed data.
- `production-style RTO: minutes` - production services should recover within minutes, not hours.
- `production-style RPO: near zero for patient workflow state` - patient consent records, case states, and audit logs must not be lost. These require synchronous or near-synchronous replication.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports current dev resource state.
- `make cloud-pause ENV=dev` pauses pausable resources to stop billing without destroying data.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag prevents accidental teardown.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` starts or resumes the dev environment.
- `make cloud-status ENV=dev` verifies it is healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
