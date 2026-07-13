# System Design Patterns

This is the reference catalog for the patterns the rest of the curriculum touches but does not teach explicitly. The handholding guides tell you *what* to build. This file tells you *why* the building blocks exist and how they compose into a production system.

Read this once, return to it whenever a guide says "Concepts you just touched: [pattern]". Do not try to memorise everything in one pass. The point of the Socratic questions at the end of every pattern is to give you a way to test yourself before moving on.

## How To Read This File

Each pattern entry has the same shape:

```text
1. One-line definition - what the pattern is, in plain terms.
2. Why it exists - the failure it prevents or the property it gives you.
3. Where it shows up in YOUR project - file path, guide reference.
4. Where it should but does not yet - linked gap from auto-memory.
5. Anti-patterns - 2-3 ways people screw it up.
6. Trade-offs - what you give up to get the benefit.
7. Questions you should be able to answer - 5 Socratic prompts.
```

**What this entry shape means:** every pattern in this file follows the same structure so you always know where to look. The definition tells you what the pattern is. The "why it exists" tells you the specific failure mode or property it gives you - that is the most important part to remember. The "where in YOUR project" tells you the exact file or guide where the concept is applied. The "where it should but is not yet" is honest about gaps - it means the pattern is known but not yet wired up. The anti-patterns are the most common mistakes, not exhaustive lists. The trade-offs explain what you give up to gain the benefit. The Socratic questions are how you verify that you understood the pattern deeply enough to use it correctly.

If a pattern says "where it should but does not yet" and lists a file you have not built, that is fine. The curriculum sequences these so you build them in order. The point is to know that the gap exists and where it will be closed.

## Engineering Lenses Applied

Every pattern in this catalog was written through a specific engineering discipline. The lens is named at the top of each family so you know which mental model the section reflects.

- **Architect lens** - service boundaries, dependency direction, cohesion, blast radius
- **Backend lens** - API contracts, idempotency, transactions, concurrency, ports and adapters
- **ML engineer lens** - model lifecycle, serving topology, evaluation gates, drift
- **Observability lens** - SLOs, RED and USE metrics, runbook-linked alerts, trace propagation
- **Security lens** - zero trust, least privilege, defense in depth, secret hygiene
- **AI safety lens** - prompt injection, RAG isolation, refusal patterns, evidence citation
- **DevOps lens** - immutable infrastructure, rolling vs immutable releases, environment parity
- **Data engineer lens** - OLTP vs OLAP, analytics-safe views, CDC, batch vs stream

When lenses disagree, the trade-off is recorded inline.

---

# Family 1 - State And Session

Lens: Architect.

State is the hardest part of distributed systems. The whole point of going stateless is so you can scale horizontally without surprises. The patterns in this family teach you where state has to live, how to fence it off, and what to do when "stateless" is not actually possible.

## 1.1 Sticky Sessions / Session Affinity

**Definition.** A load balancer routes all requests from one client to the same backend instance for the duration of a session.

**Why it exists.** Some servers cache user-specific data in process memory (model warmup, partially-decoded image, in-flight prediction). If the next request lands on a different instance, the cache miss is expensive or the workflow breaks.

**Where in YOUR project.** Not yet implemented. The prediction flow is the natural candidate: the patient uploads, you run inference, the user polls for `/result` and then asks for `/explain` (Grad-CAM). If the polling lands on a different instance and you cached the activations for CAM generation in-process, the second request has to re-run forward pass.

**Where it should be but is not yet.** When you wire up ECS or EKS in `staging/08_ECR_AND_EKS_HANDHOLDING.md`, the ALB target group needs a session-affinity decision. Default for medical workflows: prefer stateless, push activation cache to Redis/ElastiCache (see `production/12_CACHE_REDIS_ELASTICACHE_HANDHOLDING.md`), use sticky only as a last resort. Auto-memory gap: ElastiCache not yet provisioned, so you currently have no choice but stateless or sticky.

**Anti-patterns.**
- Using sticky sessions as a shortcut so you never have to externalise state. The first instance failure surfaces every hidden assumption.
- Mixing sticky for some endpoints and stateless for others on the same load balancer without documenting it.
- Hashing on patient ID for routing without considering hot-key skew (one very active patient overloads one pod).

**Trade-offs.** Stickiness reduces cache miss but breaks instance failover, uneven load, and rolling deploys (in-flight requests die). Externalising to Redis costs latency and adds a dependency but lets you scale and deploy freely.

**Questions you should be able to answer.**
1. What state, specifically, would your prediction flow lose if instance A dies and instance B takes over?
2. Why is ALB cookie-based affinity insufficient for HIPAA-sensitive flows?
3. If you use Redis for activation cache, what TTL do you set and why is 1 hour a known footgun?
4. How would a sticky-session config interact with EKS rolling deploys?
5. Which is cheaper to recover from: a forgotten activation cache or a Redis outage during an active session?

## 1.2 Stateless Service

**Definition.** A service that holds no per-client state between requests; every request carries everything the service needs to answer it.

**Why it exists.** Horizontal scaling, blue/green deploys, failure isolation, and instance immortality all assume any request can hit any instance.

**Where in YOUR project.** The FastAPI app (`Skin_Lesion_Classification_backend`) is mostly stateless, but the prediction store is currently an in-memory dict (per memory: "predictions_store"). That breaks the property the moment you have more than one ECS task.

**Where it should be but is not yet.** All ephemeral request state belongs in Postgres (durable) or Redis (volatile, fast). The image bytes go to S3, the prediction record goes to Postgres, the activation cache goes to Redis. The process holds nothing.

**Anti-patterns.**
- "Just stash it in a module-level dict, we'll fix it later." You won't. It will silently fail in staging.
- Storing JWT contents in process memory after first decode. Cache the verified claims in Redis with the token's TTL.
- Counting requests in process for rate limiting. Two pods, two counters, half the rate limit.

**Trade-offs.** External state is slower (network hop) and adds operational dependencies. Pure statelessness can force you to denormalise data into every request payload, which gets ugly.

**Questions you should be able to answer.**
1. Which endpoints in your backend currently violate statelessness?
2. What is the smallest change to move `predictions_store` out of process?
3. Why is "stateless" a property of the service, not the request?
4. Can a service be stateless and still cache? When and where?
5. If you have a singleton ML model loaded in memory, are you stateless? Why or why not?

## 1.3 Session Cache Versus Session Store

**Definition.** Cache is best-effort fast retrieval; store is durable source of truth. For session data, choose deliberately.

**Why it exists.** Treating cache as a store is the single most common bug in young systems. Redis is not your database. Postgres is not your cache.

**Where in YOUR project.** Consent state, audit log, doctor verdicts - durable, must survive a Redis flush. Image activation cache, signed-URL pre-resolution, recently-viewed list - cache, can be regenerated.

**Where it should be but is not yet.** Auto-memory gap: "Image persisted to Redis (1h TTL) but doctor validation can take more than 1h - race condition." Persist the image to S3 immediately and store the S3 URI in Postgres. Redis can hold a hot copy for performance, but losing it must not lose the case.

**Anti-patterns.**
- Storing consent decisions in Redis only. Lose Redis, lose compliance.
- Long TTLs (24h, 7d) used to paper over the fact that you should have written to Postgres.
- Reading from cache without a fallback path to the store.

**Trade-offs.** Cache + store double-writes are harder to keep consistent. But it is the only way to get both speed and durability for medical workflows.

**Questions you should be able to answer.**
1. List every piece of state currently in Redis. For each, ask: is this regenerable?
2. What is the failure mode if Redis is wiped during a busy doctor review queue?
3. Why does a cache-aside pattern need an explicit invalidation strategy?
4. When is it acceptable to use Redis as primary store? (Hint: almost never in healthcare.)
5. If the doctor validates a case after Redis TTL expired but before S3 promotion, what breaks?

---

# Family 2 - Reliability

Lens: Backend + Observability.

The reliability patterns let your system stay up when something downstream is sick. Most outages are not "everything died at once" - they are "one slow dependency took everyone else down with it." These patterns isolate that blast radius.

## 2.1 Circuit Breaker

**Definition.** A wrapper that tracks failures of a downstream call and "trips" open after a threshold, short-circuiting subsequent calls with a fast failure instead of waiting for the dependency.

**Why it exists.** Without it, a slow ML inference call hangs every worker thread, queue depth balloons, healthchecks start failing, and the whole API goes down because of one bad component.

**Where in YOUR project.** Not yet wired. The natural homes are: (a) the Grad-CAM call from `/explain`, (b) the LLM call from `/safe-explanation`, (c) the OCR call for lab results, (d) the RAG retrieval inside the doctor agent.

**Where it should but is not yet.** Auto-memory gap: "No circuit breaker on ML inference - hung CAM generation can exhaust thread pool." Add at the boundary between `routes/analysis.py` and `services/inference.py`. Threshold around 5 consecutive failures or 50% error rate over 30s. When open, return a soft-fail JSON with `degraded: true` and let the frontend show a banner.

**Anti-patterns.**
- Catching the open-circuit exception and silently returning empty data. The user thinks it worked.
- One global circuit for all downstream calls. You want per-dependency circuits so DB outage does not trip the LLM circuit.
- Long half-open recovery windows. You should retry probes quickly and re-close on success.

**Trade-offs.** Circuit-broken calls return errors faster but you lose a chance at a slow success. For medical workflows, fast known failure is much better than uncertain timeout.

**Questions you should be able to answer.**
1. What is the difference between a circuit breaker and a retry?
2. If your `/explain` endpoint trips its circuit, what should the frontend show the patient?
3. Why is a global circuit a bad idea?
4. How does a circuit breaker compose with a timeout budget?
5. What happens to in-flight requests when the breaker trips?

## 2.2 Bulkhead

**Definition.** Resource pools (threads, connections, queues) are partitioned per workload so one workload cannot starve the others.

**Why it exists.** A single shared thread pool means a slow LLM call can consume every thread and your `/health` endpoint stops responding, even though it doesn't touch the LLM.

**Where in YOUR project.** Your FastAPI app should have separate worker pools or async semaphores for: prediction inference, Grad-CAM, LLM/RAG calls, DB queries. Currently they share the default Uvicorn worker pool.

**Where it should but is not yet.** Add semaphores in `services/` for each high-cost call. Or run separate ECS services for inference vs API, and let ALB route by path.

**Anti-patterns.**
- One semaphore size for all dependencies. Pick per call type based on its latency and failure profile.
- Bulkheading without observability. You need metrics on saturation per bulkhead to tune sizes.
- Treating DB connections as infinite. Connection pool exhaustion is the most common form of failed bulkheading.

**Trade-offs.** Each bulkhead costs some throughput because resources are not pooled globally. The win is that one bad dependency cannot kill the others.

**Questions you should be able to answer.**
1. If LLM calls saturate, should `/health` still return 200? Why?
2. How does Uvicorn's worker count interact with the bulkhead pattern?
3. Why is a DB connection pool a bulkhead in disguise?
4. What metric tells you a bulkhead is undersized?
5. Could you achieve bulkheading by separating into multiple microservices instead?

## 2.3 Retry With Jitter

**Definition.** When a transient call fails, retry after a delay that is randomised so concurrent failures do not retry in lockstep.

**Why it exists.** Synchronous retries without jitter cause thundering-herd: 1000 clients all retry exactly 1 second later, hammering the downstream that just recovered.

**Where in YOUR project.** S3 multipart upload, ECR pulls, RDS connection establishment, SQS receive (handled by AWS SDK), LLM API calls (Anthropic SDK retries; configure max attempts).

**Where it should but is not yet.** Define a project-wide retry policy in a single utility: max 3 attempts, exponential backoff 250ms / 1s / 4s, jitter +/- 25%. Apply only to idempotent calls.

**Anti-patterns.**
- Retrying on non-idempotent endpoints (a POST that creates an entity) without an idempotency key.
- Retrying inside a retry. Nested retries multiply the latency budget.
- Retrying on 4xx errors. 4xx means the client is wrong; retrying changes nothing.

**Trade-offs.** Retries hide flakiness from the user but mask underlying problems. Always log the retry count so you can see when it spikes.

**Questions you should be able to answer.**
1. Why is jitter mathematically necessary?
2. Which HTTP status codes are safe to retry?
3. How does retry interact with the circuit breaker?
4. If you retry a POST, what must the server contract guarantee?
5. What is the latency budget after 3 retries with 250/1000/4000ms backoff?

## 2.4 Timeout Budget

**Definition.** Every external call has an explicit deadline; the deadline is propagated downstream so deep calls do not exceed the outer caller's patience.

**Why it exists.** Default HTTP client timeouts (often "infinite" or 60s) are the silent killer. The patient's browser gave up 10 seconds ago; your inference is still chugging.

**Where in YOUR project.** Define per-call timeouts: S3 = 10s, RDS query = 2s, LLM = 8s, inference = 5s, total `/analysis` budget = 12s. Frontend gives up at 15s.

**Where it should but is not yet.** Audit every `requests.get/post`, `httpx`, `boto3` call site. Set `timeout=` on all of them. None should fall back to default.

**Anti-patterns.**
- Setting one global timeout. Each call has a different baseline.
- Timeouts that do not propagate. The outer call has 5s left, the inner call gets a fresh 30s.
- No timeout on health checks. Your liveness probe hangs and Kubernetes thinks the pod is healthy.

**Trade-offs.** Tight timeouts kill some slow successes. Tune by measuring p95/p99 latency in dev and adding margin.

**Questions you should be able to answer.**
1. What is your end-to-end budget for `/analysis`?
2. If the LLM is slow, can the frontend safely retry with a longer timeout?
3. Why must the timeout be set on the client side, not relied upon from the server side?
4. How do you propagate a deadline across an SQS hop?
5. What logs let you spot a timeout that masked a hung call?

## 2.5 Backpressure

**Definition.** A producer slows down or rejects when a consumer cannot keep up; the system fails predictably instead of building unbounded queues.

**Why it exists.** Without backpressure, a spike in uploads queues up infinitely, memory blows out, and the OOM killer ends the party.

**Where in YOUR project.** SQS receive concurrency limit on the training worker. Frontend disable-while-uploading. FastAPI request rate limiter (slowapi or middleware). Database connection pool with max_overflow=0 in some cases.

**Where it should but is not yet.** When you add the training pipeline worker (`staging/13_EVENTS_SQS_WORKER_HANDHOLDING.md`), bound max concurrent jobs explicitly. Add a rate limiter on `/analysis` to prevent burst floods.

**Anti-patterns.**
- Unbounded in-memory queues (`asyncio.Queue()` with no maxsize).
- Frontend that allows multiple parallel uploads without a global concurrency cap.
- Worker auto-scaling that scales up faster than the downstream can scale.

**Trade-offs.** Rejected requests are user-visible. Better than silent unbounded queueing that fails later in a worse way.

**Questions you should be able to answer.**
1. Where in your current architecture is queueing unbounded?
2. What HTTP status should `/analysis` return when overloaded?
3. How does SQS visibility timeout interact with backpressure?
4. Why is "scale infinitely" not a backpressure strategy?
5. What metric on the worker tells you it is the bottleneck?

## 2.6 Dead-Letter Queue (DLQ)

**Definition.** Messages that fail processing repeatedly are moved to a separate queue for inspection instead of being retried forever or silently dropped.

**Why it exists.** Without a DLQ, a single poison message can re-enter the main queue forever, blocking healthy messages and burning compute.

**Where in YOUR project.** The training-eligibility SQS queue, the lab OCR queue, the de-identification queue. Each needs a paired DLQ with a maxReceiveCount.

**Where it should but is not yet.** When you provision SQS in `staging/13`, every queue gets a DLQ. Add an admin UI screen to inspect and replay (see Stitch DLQ-inspector prompt).

**Anti-patterns.**
- DLQ exists but nobody monitors it. Add an alarm on `ApproximateNumberOfMessagesVisible > 0`.
- Replaying DLQ messages without fixing the cause.
- DLQ size limit too low; messages lost.

**Trade-offs.** DLQ adds operational overhead. The alternative (no DLQ) is much worse.

**Questions you should be able to answer.**
1. How does SQS know when to move a message to the DLQ?
2. What should the maxReceiveCount be? How do you tune it?
3. Why is a DLQ a queue and not a database table?
4. What information does the operator need to triage a DLQ message?
5. When is it safe to replay a DLQ message without code changes?

## 2.7 Poison Pill Handling

**Definition.** Detect messages that will never succeed (malformed schema, missing required field, corrupted payload) and divert them before they exhaust retries.

**Why it exists.** DLQ catches the message eventually, but you waste max-receive-count attempts. Detecting up-front is cheaper.

**Where in YOUR project.** Validate every SQS message at the worker boundary with a Pydantic model. If validation fails, log + send straight to DLQ via `DeleteMessageBatch` then `SendMessage` to the DLQ ARN.

**Anti-patterns.**
- Try/except that silently swallows malformed messages.
- Validating partway through processing, after side-effects.
- Treating poison pills as transient errors.

**Trade-offs.** Detecting eats CPU before the work starts. Worth it for any message that can have a schema.

**Questions you should be able to answer.**
1. What is the schema check at the boundary of your training-eligibility worker?
2. How is a poison pill different from a transient error?
3. Should poison pills count against your error-budget SLO?
4. What is the audit trail for a poison-pill divert?
5. Could a malicious producer create poison pills to flood your DLQ?

---

# Family 3 - Consistency

Lens: Backend + Architect.

Distributed consistency is where junior engineers learn humility. The patterns below are the minimum you need so that two concurrent requests, one retry, and one network blip do not corrupt your data.

## 3.1 Idempotency Keys

**Definition.** A client-supplied unique key on a request; the server records the key after first successful handling and returns the same response on retry.

**Why it exists.** Networks fail mid-response. The client retries. Without idempotency, you create two consent records, two predictions, two doctor verdicts.

**Where in YOUR project.** Every state-changing POST should accept `Idempotency-Key` header: `/consent`, `/analysis`, `/lab-results`, `/doctor-review`. Store the key + response in Postgres `idempotency_log` with TTL.

**Where it should but is not yet.** Auto-memory gap: "No idempotency on consent endpoint - duplicate training entries possible." Highest priority. Add table `idempotency_log(key, endpoint, request_hash, response_body, created_at)` with unique constraint on `(key, endpoint)`.

**Anti-patterns.**
- Hashing the request body alone (the request might legitimately repeat with different keys).
- TTL too short (the client retried after a long break).
- Storing only success keys (a 4xx is also a response; replay it).

**Trade-offs.** Every state-changing endpoint pays one DB lookup per request. The alternative is data corruption.

**Questions you should be able to answer.**
1. What happens if two requests with the same idempotency key arrive at the same time?
2. Why must the key be supplied by the client, not the server?
3. How does idempotency interact with retry?
4. Can you make a GET endpoint idempotent? Is it already idempotent by definition?
5. What is the difference between idempotency and exactly-once?

## 3.2 Optimistic Concurrency Control

**Definition.** Every row has a version number; updates include the expected version; the DB rejects if the version has moved on.

**Why it exists.** Two doctors open the same case, both modify the verdict, one save overwrites the other. Without OCC, the second save wins silently.

**Where in YOUR project.** Add `version INT NOT NULL DEFAULT 1` to `cases`, `lesions`, `lab_results`, `doctor_reviews`. UPDATE statements include `WHERE id = ? AND version = ?` and increment version. On 0 rows affected, return 409 Conflict.

**Where it should but is not yet.** Auto-memory gap: "metadata.csv in S3 is not atomic - concurrent admin approvals cause write conflicts." For S3 you cannot use OCC directly; use S3 conditional writes (If-Match on ETag) or move metadata to Postgres.

**Anti-patterns.**
- Locking with `SELECT FOR UPDATE` everywhere (pessimistic, hurts throughput).
- Last-write-wins as a deliberate choice without telling the user.
- Version stored as timestamp (collisions on rapid updates).

**Trade-offs.** Optimistic costs a retry round-trip on conflict. Pessimistic blocks readers. Pick by contention level.

**Questions you should be able to answer.**
1. What HTTP status should a version conflict return?
2. How does the frontend handle a 409? Auto-retry or surface to the user?
3. Why is OCC called optimistic?
4. When is pessimistic locking the better choice for this project?
5. How does OCC interact with database transactions?

## 3.3 Eventual Consistency

**Definition.** Reads might return stale data for a short window after a write; the system converges given time.

**Why it exists.** Strong consistency across regions / read replicas / caches is expensive. For non-critical data (recently-viewed list, cached dashboard counts), eventual is fine.

**Where in YOUR project.** Read replicas of RDS, ElastiCache, CDN for static assets. The lesion timeline read after a write may show the new entry up to a few seconds late.

**Anti-patterns.**
- Eventual consistency on consent (must be strongly consistent - never serve a deleted consent as still-valid).
- Reading-your-own-write from a read replica.
- Surfacing eventual delay as a "system error" instead of a UX-handled refresh.

**Trade-offs.** You buy throughput and latency by giving up freshness. Always be explicit about which fields are eventually consistent.

**Questions you should be able to answer.**
1. Which fields in your data model can tolerate eventual consistency?
2. Which fields cannot? Why?
3. How does ElastiCache TTL affect eventual consistency?
4. What is "read-your-own-write" and how do you guarantee it?
5. Is Aurora DSQL eventually consistent? Strongly consistent?

## 3.4 Saga (Choreography Versus Orchestration)

**Definition.** A long-running business workflow is split into local transactions; if one step fails, compensating transactions undo the prior steps. Choreography = each service reacts to events. Orchestration = a central coordinator calls services in order.

**Why it exists.** Distributed transactions (2PC) are slow and brittle. Sagas replace ACID-across-services with a documented compensation strategy.

**Where in YOUR project.** Training-eligibility flow: (1) patient consent → (2) doctor validation → (3) admin approval → (4) image promotion to training bucket → (5) metadata.csv update → (6) training pool insert. Each step can fail. Choreography fits because steps are queued.

**Where it should but is not yet.** Auto-memory gap: "No SQS queues for training pipeline - synchronous calls with no retry." When you wire SQS in `staging/13`, choose choreography: each service publishes "step done" events; subscribers fire compensation events on failure.

**Anti-patterns.**
- Sagas without documented compensations. You will need them; figure them out at design time.
- Mixing choreography and orchestration without a clear rule. Pick per workflow.
- Treating each step as final without an explicit rollback plan.

**Trade-offs.** Choreography is decentralised and resilient but hard to trace. Orchestration is easier to debug but the orchestrator becomes a single point of failure.

**Questions you should be able to answer.**
1. Sketch the saga for the training-eligibility flow on paper.
2. What is the compensation for "image promoted to training bucket"?
3. Choreography or orchestration for the doctor review flow? Why?
4. How do you know a saga has succeeded versus is still in flight?
5. How does the DLQ fit into saga compensation?

## 3.5 Outbox Pattern

**Definition.** Write events to a local DB table (the "outbox") inside the same transaction as the business write; a separate process drains the outbox and publishes to the message bus.

**Why it exists.** Two-phase commit between DB and message bus is unreliable. Without outbox: you commit the business row, the network drops, the event never goes out; or you publish the event and the DB write fails.

**Where in YOUR project.** When consent is recorded → publish `ConsentGranted`. When doctor verdict saved → publish `CaseValidated`. Both must be transactional with the DB write.

**Where it should but is not yet.** Add table `event_outbox(id, aggregate_id, event_type, payload, status, created_at, published_at)`. Worker polls every 5s, publishes, marks published. After successful publish, mark for delete.

**Anti-patterns.**
- Publishing the event before the DB commit. Crash between → ghost event.
- Publishing after, outside the transaction. Crash between → lost event.
- Polling the outbox too aggressively (DB load).

**Trade-offs.** Outbox adds latency (poll interval) and a worker. Buys you atomicity guarantees.

**Questions you should be able to answer.**
1. Why is outbox needed even if SQS guarantees at-least-once delivery?
2. What is the failure mode of "publish after commit, outside the transaction"?
3. How does outbox interact with the saga pattern?
4. What is the maximum lag introduced by outbox polling?
5. Could you use Postgres logical replication (CDC) instead of an outbox poller?

## 3.6 The "Exactly-Once" Illusion

**Definition.** Network message delivery is never exactly-once. It is at-most-once, at-least-once, or "effectively-once" via idempotency.

**Why it matters.** Engineers reach for "exactly-once" and then build systems that double-process or lose data because the contract is misunderstood.

**Where in YOUR project.** SQS is at-least-once. Worker must be idempotent (use idempotency keys on the message ID). FIFO queues are "effectively exactly-once within a deduplication window" - read the AWS docs and understand the windows.

**Anti-patterns.**
- Picking standard SQS and assuming exactly-once because "messages usually arrive once."
- Picking FIFO and assuming the dedup window is infinite. It is 5 minutes.
- Believing Kafka exactly-once is end-to-end without configuring transactional producers and consumers.

**Trade-offs.** True exactly-once requires producer + broker + consumer all cooperating with transactional semantics. Most systems are better off with at-least-once + idempotency.

**Questions you should be able to answer.**
1. If your worker reads the same SQS message twice, what guards against double-processing?
2. What does SQS FIFO actually guarantee?
3. Why is exactly-once impossible in the general case?
4. Where does idempotency turn at-least-once into "effectively-once"?
5. How does the outbox pattern interact with exactly-once semantics?

---

# Family 4 - Performance

Lens: Backend + Data engineer.

## 4.1 Cache-Aside

**Definition.** On read, check cache; on miss, read DB and populate cache. On write, update DB and invalidate cache.

**Why it exists.** Cheapest cache pattern, most flexible. The application owns the logic, not the cache.

**Where in YOUR project.** The patient dashboard: lesion count, recent activity, last 3 predictions. ElastiCache when provisioned (`production/12`).

**Anti-patterns.**
- Forgetting invalidation. Stale dashboards.
- Cache-aside on data that is hot-and-fresh (defeats the purpose).
- TTL as the only invalidation. Add explicit invalidate on write.

**Questions you should be able to answer.**
1. Which fields in the patient dashboard are cache-able?
2. What is the failure mode if cache is unavailable?
3. When does cache-aside cause a stampede on miss?
4. How does cache-aside differ from read-through?
5. What is the cardinality of your cache key space? (Affects Redis memory sizing.)

## 4.2 Write-Through Versus Write-Behind

**Definition.** Write-through = write hits cache and DB synchronously. Write-behind = write hits cache, returns success, DB is updated asynchronously.

**Where in YOUR project.** Use neither for medical-critical data. Write-behind especially is dangerous: if the cache evicts before the DB write, the data is gone. Use cache-aside instead.

**Anti-patterns.**
- Write-behind for consent or audit. Hard no.
- Write-through with no fallback when cache is down (you've coupled writes to cache availability).

**Questions you should be able to answer.**
1. Why is write-behind unsafe for consent?
2. When is write-through acceptable?
3. What is the equivalent of write-through in cache-aside terms?
4. How does write-through interact with cache TTL?
5. Could you make write-behind safe with the outbox pattern?

## 4.3 Read-Replica Routing

**Definition.** Read traffic goes to replicas; writes go to primary; the application chooses which based on the query.

**Where in YOUR project.** RDS read replicas in staging or prod. The research dashboard, the public SEO pages, the doctor case-list - all are read-heavy.

**Anti-patterns.**
- Reading-your-own-write from a replica (replication lag → stale data).
- Sending consent reads to a replica during the consent flow.
- One connection pool that randomly picks primary or replica.

**Questions you should be able to answer.**
1. Which endpoints in your project are safe to read from a replica?
2. How does replication lag interact with the lesion timeline?
3. What is the worst-case lag on RDS Multi-AZ vs a read replica?
4. Should the doctor's case-list use a replica? Why or why not?
5. How does Aurora DSQL change the read-replica conversation?

## 4.4 Connection Pooling

**Definition.** A bounded pool of pre-established DB connections shared across requests; new requests check out a connection, use it, return it.

**Where in YOUR project.** SQLAlchemy / asyncpg pool inside FastAPI. The pool size must be tuned: too small and requests queue, too large and the DB chokes.

**Anti-patterns.**
- Default pool size (often 5). With 4 ECS tasks * 5 = 20 connections; RDS will tolerate hundreds, but Aurora Serverless v2 has tighter limits.
- Long-running transactions that hold a connection.
- No `pool_pre_ping` to detect stale connections after RDS failover.

**Questions you should be able to answer.**
1. What is your current pool size?
2. What is the DB-side max_connections?
3. How does connection pooling interact with ECS task scaling?
4. Why is RDS Proxy useful for serverless workloads?
5. What is the failure mode of pool exhaustion?

## 4.5 Query Batching

**Definition.** Combine N queries into one round-trip; combine N inserts into one INSERT.

**Where in YOUR project.** Loading the lesion timeline for a patient: fetch all lesions + all predictions + all Grad-CAM URLs in joined queries, not in a loop.

**Anti-patterns.**
- N+1: 1 query for patients, then 1 query per patient for lesions, then 1 query per lesion for predictions.
- Selecting all columns when you only need three.
- Loading associations eagerly when you only need IDs.

**Questions you should be able to answer.**
1. Where in your code is an N+1 most likely?
2. What tool detects N+1 in SQLAlchemy?
3. How does N+1 interact with read-replica latency?
4. Why is `SELECT *` an anti-pattern?
5. What is the latency cost of a single DB round-trip in your local setup vs RDS?

---

# Family 5 - Scale

Lens: Architect.

## 5.1 Horizontal Versus Vertical Scaling

**Definition.** Horizontal = more instances of the same service. Vertical = a bigger instance of one service.

**Where in YOUR project.** API and prediction service should scale horizontally (stateless). The model inference instance may scale vertically first (need GPU/larger instance) before splitting horizontally.

**Anti-patterns.**
- Scaling vertically because the service is not actually stateless.
- Scaling horizontally without externalising state (see Family 1).
- Auto-scaling without backpressure on the consumers downstream.

**Questions you should be able to answer.**
1. Which services in your architecture must be horizontally scalable?
2. Which constraints make horizontal scaling hard? (state, GPU, license)
3. How does the load balancer fit into horizontal scaling?
4. What is the cost difference between horizontal and vertical at production scale?
5. Why is vertical scaling sometimes the right first step?

## 5.2 Sharding And Partitioning

**Definition.** Split a single dataset across multiple physical units by some key.

**Where in YOUR project.** Not needed at portfolio scale (RDS handles your dataset easily). Become relevant if you ever have millions of patients. Aurora DSQL handles this automatically; that is one of its selling points.

**Questions you should be able to answer.**
1. Why is sharding "not needed at portfolio scale"?
2. What key would you shard on if you had to? (patient_id? region?)
3. What is the hot-key problem in sharding?
4. How does Aurora DSQL approach sharding differently from manual sharding?
5. Why is sharding a one-way door?

## 5.3 Leader Election

**Definition.** Multiple instances of a service coordinate so only one acts as primary for a given task.

**Where in YOUR project.** Only one instance should run the outbox poller, the cron-scheduled retraining job, the active-learning refresh. Without leader election, each instance does it and you get duplicate work.

**Where it should but is not yet.** Use a dedicated worker service (single instance) for now. When you need leader election, Redis Redlock or AWS Lambda + EventBridge cron is simpler than Raft.

**Questions you should be able to answer.**
1. Why is "just run it on one pod" not a leader election strategy?
2. What is split-brain?
3. How does Redis Redlock claim leadership?
4. Why might Lambda + EventBridge replace leader election for your project?
5. What state must be guarded by leader election?

---

# Family 6 - Deployment

Lens: DevOps.

## 6.1 Blue/Green Deployment

**Definition.** Two production environments (blue and green) exist; one serves traffic, the other receives the new version; you flip the LB to switch.

**Where in YOUR project.** `production/08_RELEASE_STRATEGIES_BLUE_GREEN_CANARY.md`. Best for risky migrations and large schema changes where rollback must be instant.

**Anti-patterns.**
- Blue/green with shared database that has incompatible schema changes (you cannot flip back).
- No DB migration strategy that supports both versions during the flip.
- Switching DNS instead of a load balancer target group (DNS TTLs ruin your day).

**Questions you should be able to answer.**
1. What kinds of changes are NOT safe under blue/green?
2. How do you handle in-flight requests at the moment of flip?
3. How does blue/green interact with sticky sessions?
4. What is the cost penalty of blue/green vs rolling?
5. When is rolling deployment a better choice than blue/green?

## 6.2 Canary Deployment

**Definition.** Roll out the new version to a small fraction of traffic, measure, expand or roll back.

**Where in YOUR project.** ALB weighted target groups or AppMesh for canary. For ML model promotion, canary by patient ID hash so the same patient sees the same model.

**Anti-patterns.**
- Canary by simple random routing (one patient sees old then new in same session).
- No automated rollback trigger on error-rate spike.
- Canary metric is "no errors yet" instead of an SLO comparison.

**Questions you should be able to answer.**
1. What is the canary cohort size? Why?
2. How do you ensure the same user sees a consistent model version?
3. What metric triggers automatic rollback?
4. How does canary differ from A/B test of models?
5. Why is canary safer than blue/green for ML changes?

## 6.3 Shadow Deployment

**Definition.** Send a copy of production traffic to a new version; compare outputs to the current version; never return the new version's response to the user.

**Where in YOUR project.** Auto-memory gap: "No shadow deployment for model candidate evaluation before full promotion." Add when you have a new model checkpoint. Run both, log both, compare.

**Anti-patterns.**
- Shadow that touches the database (writes from the shadow corrupt state).
- Shadow that races the primary (latency suddenly doubles).
- Comparison metric that does not match what you actually care about.

**Questions you should be able to answer.**
1. Why is shadow safer than canary for a new ML model?
2. What outputs do you log for shadow comparison?
3. How do you keep shadow reads from causing extra DB load?
4. When do you graduate from shadow to canary?
5. How does shadow interact with the frozen reference test set?

## 6.4 Feature Flags

**Definition.** Runtime switches that gate behaviour without redeploying.

**Where in YOUR project.** `production/11_APPCONFIG_FEATURE_FLAGS_HANDHOLDING.md`. AppConfig holds flags; the app polls and applies.

**Anti-patterns.**
- Flag that is permanent (becomes a config; rename or remove).
- Flag dependency hidden in three places.
- Flag with no rollout plan (always-on or always-off, no gradual).

**Questions you should be able to answer.**
1. What is the difference between a feature flag and a config value?
2. What flag would you create for the next risky feature?
3. Why is AppConfig better than env vars for feature flags?
4. How do you test code that is behind a flag?
5. When does a flag become technical debt?

## 6.5 Immutable Infrastructure

**Definition.** Servers are never patched in place. To change them, build a new image and deploy.

**Where in YOUR project.** Docker + ECS/EKS: each release is a new image tag. No SSH-in-and-fix.

**Anti-patterns.**
- Hotfixing a container with `exec`.
- Mutable secrets baked into the image instead of mounted at runtime.
- Persistent state on the container filesystem.

**Questions you should be able to answer.**
1. Why is immutable infra a precondition for reliable rollback?
2. Where do logs go on an immutable container?
3. How does immutable infra interact with stateful services?
4. What is the deploy time for a new image vs an in-place patch?
5. How do you handle emergency hotfixes without breaking immutability?

---

# Family 7 - Data Architecture

Lens: Data engineer.

## 7.1 OLTP Versus OLAP Separation

**Definition.** OLTP = transactional, write-heavy, small reads. OLAP = analytical, read-heavy, big aggregations. Different stores.

**Where in YOUR project.** RDS / Aurora for OLTP. Power BI reads from analytics-safe views on a replica or a separate analytics store. Never let Power BI hit the live patient-facing DB.

**Where it should but is not yet.** `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` covers this. The views must be aggregated and de-identified.

**Anti-patterns.**
- Patient-facing dashboard queries doing GROUP BY over millions of rows.
- Power BI joining patient and lab tables at query time.
- "We'll add OLAP later" - you bake yourself into a corner.

**Questions you should be able to answer.**
1. List 3 queries that belong in OLTP.
2. List 3 queries that belong in OLAP.
3. What is an "analytics-safe view"?
4. Why never expose PHI to Power BI?
5. How would a research reviewer's query differ in pattern from a doctor's?

## 7.2 Analytics-Safe Views

**Definition.** SQL views that aggregate, pseudonymise, or de-identify data before exposing it to analytics tools.

**Where in YOUR project.** Heavily covered in `staging/19`. Every Power BI dashboard reads from a view, never from a base table.

**Anti-patterns.**
- View that includes patient email "just in case."
- View that returns row-level data ungrouped.
- View that is owned by an admin role instead of a dedicated analytics role.

**Questions you should be able to answer.**
1. What columns are NEVER in an analytics view?
2. Why is GROUP BY a privacy primitive?
3. Why does a k-anonymity threshold matter?
4. What role should own the views?
5. How do you audit who queried which view?

## 7.3 Change Data Capture (CDC) And Event Sourcing

**Definition.** CDC = stream changes from a DB to other systems. Event sourcing = the DB's state IS the log of events.

**Where in YOUR project.** CDC could replace the outbox poller with Postgres logical replication. Event sourcing is overkill for this project but the audit log is morally event-sourced (immutable, append-only).

**Questions you should be able to answer.**
1. How does CDC differ from outbox?
2. Is your audit log event-sourced?
3. What is the storage cost of full event sourcing?
4. When is CDC the right tool?
5. What is the replay story for an event-sourced system?

## 7.4 CQRS (Command Query Responsibility Segregation)

**Definition.** Separate the write path (commands that change state) from the read path (queries that read state). They use different models, sometimes different stores.

**Why it exists.** Your write path optimises for consistency, constraints, and auditability. Your read path optimises for speed, shape, and aggregation. Combining them forces the write model to serve both, and it serves neither well. Power BI dashboards querying the live RDS patient table during peak inference hours is the failure CQRS prevents.

**Where in YOUR project.** Partial implementation exists today:
- Write side: `training_cases` / `case_events` / `outbox_events` in RDS - normalised, transactional, consistent.
- Read side: Power BI reads analytics-safe views on a read replica (or will when `staging/19` is implemented).
- Gap: the patient dashboard `/api/v1/patient/cases` currently queries the same RDS instance used for writes. Under load this will degrade write latency.

**Where it should be but is not yet.** `staging/19_POWERBI_EMBEDDED_ANALYTICS_HANDHOLDING.md` covers the read-side store. The backend API read paths (case list, lesion timeline, prediction history) should eventually read from a read replica or a dedicated read model, not the primary.

**Anti-patterns.**
- One Postgres instance serving both Power BI dashboards and patient inference API. Read replica or separate store required for production scale.
- Syncing the read model with complex application code rather than a simple DB view or CDC stream.
- Exposing raw write-model tables (with foreign keys, normalised columns, UUID PKs) directly to analytics tools - leads to overly complex SQL in reports.

**Trade-offs.** Full CQRS adds synchronisation lag between write and read model. For this project, a read replica (a few seconds of replication lag) is enough. Full eventual-consistency read models are overkill at portfolio scale.

**Questions you should be able to answer.**
1. Why can the patient dashboard read from a read replica but the consent endpoint cannot?
2. What is the replication lag on an Aurora read replica and when does it matter?
3. The `case_events` table is append-only. Why is it safe to read directly for audit display, but not safe to aggregate over it for the research dashboard?
4. If you add a read replica for Power BI, do you still need analytics-safe views? Why?
5. CQRS says commands and queries use different models. In your project, what is the "write model" and what is the "read model" for the lesion timeline?

---

# Family 8 - Security

Lens: Security + Secops.

## 8.1 Zero Trust

**Definition.** No implicit trust based on network position; every call authenticated and authorised regardless of where it comes from.

**Where in YOUR project.** Backend-to-DB uses IAM auth (or rotated Secrets Manager creds). Backend-to-S3 uses signed URLs with short TTL. Internal calls between services use mTLS or IAM.

**Anti-patterns.**
- "It's in the VPC so it's fine."
- Long-lived static credentials.
- Trusting the user's role claim without verifying.

**Questions you should be able to answer.**
1. Where in your architecture is implicit trust still present?
2. How does Cognito + JWT enforce zero trust?
3. What is the replacement for "VPC is the security boundary"?
4. How do you authenticate the worker to RDS?
5. Why are signed URLs better than IAM users for direct S3 uploads?

## 8.2 Least Privilege

**Definition.** Every identity has the minimum permissions to do its job and no more.

**Where in YOUR project.** ECS task roles, Lambda execution roles, Cognito role mappings, IAM policies on S3 buckets. Audit every wildcard `Action: "*"`.

**Anti-patterns.**
- `AdministratorAccess` for the ECS task.
- One role shared across backend, worker, and frontend deploy.
- Bucket policy that allows `s3:GetObject` for any AWS principal.

**Questions you should be able to answer.**
1. List every IAM role in your project. What is the smallest set of actions each one needs?
2. How do you detect over-privileged roles?
3. What is IAM Access Analyzer?
4. Why is `iam:PassRole` dangerous?
5. How does least privilege apply to database roles, not just IAM?

## 8.3 Defense In Depth

**Definition.** Multiple independent layers of protection so one failure does not breach the system.

**Where in YOUR project.** WAF → ALB → ECS security group → app authn → app authz → DB IAM → KMS. Each layer is one defense.

**Anti-patterns.**
- Single layer ("we use Cognito, we're secure").
- Defense in depth but no monitoring of each layer.
- Identical rules at multiple layers (does not add depth).

**Questions you should be able to answer.**
1. List the layers between a public attacker and a patient's image.
2. What does WAF protect against that ALB does not?
3. How does KMS fit into defense in depth?
4. What is the monitoring story for each layer?
5. If layer 3 fails open, do layers 4 and 5 catch it?

## 8.4 Secret Rotation

**Definition.** Credentials are rotated on a schedule; the system must keep working through the rotation.

**Where in YOUR project.** Secrets Manager rotation for RDS credentials. Cognito client secrets. Anthropic API key.

**Anti-patterns.**
- Secrets in env vars baked into the image.
- Rotation that requires a deploy.
- Single secret used across environments.

**Questions you should be able to answer.**
1. How does Secrets Manager rotation work for RDS?
2. What does your app do when a secret rotates mid-request?
3. How is the Anthropic API key rotated?
4. What is the blast radius of a leaked secret in your project?
5. How does AWS detect leaked credentials in public repos?

## 8.5 Signed URLs

**Definition.** A pre-signed URL grants time-limited access to a specific S3 object; bearer of the URL needs no AWS credentials.

**Where in YOUR project.** Patient image upload, lab result upload, image retrieval in the doctor UI. All time-limited (15 minutes).

**Anti-patterns.**
- Long TTL on signed URLs (24h+ defeats the point).
- Re-using a signed URL to support refresh; mint a new one.
- Signing for PUT without content-type and size constraints.

**Questions you should be able to answer.**
1. Why is a signed URL better than letting the browser hit S3 with an IAM key?
2. What constraints can you put on a presigned PUT?
3. What is the failure mode of a 24h TTL?
4. How do signed URLs interact with CloudFront?
5. What logs let you spot a signed-URL abuse pattern?

---

# Family 9 - ML-Specific Patterns

Lens: ML engineer.

ML systems have failure modes that pure software systems do not. The patterns below are how you keep an ML system honest in production.

## 9.1 Model Registry

**Definition.** A versioned catalog of trained models with metadata, lineage, and promotion state.

**Where in YOUR project.** MLflow is the choice. Auto-memory gap: "MLflow server not provisioned in Terraform - no production model registry." Highest-priority gap.

**Anti-patterns.**
- Model in an S3 bucket with no version table.
- Model file overwrites without a checksum.
- "Production" tag attached to the model file directly; instant rollback impossible.

**Questions you should be able to answer.**
1. What metadata belongs in the registry? (architecture, dataset version, metrics, training run ID)
2. How does the API know which model to load?
3. What is the rollback procedure?
4. How does the registry interact with canary deployment?
5. Where do model cards live?

## 9.2 Promotion Gates

**Definition.** A new model only reaches production if it passes a fixed set of automated checks.

**Where in YOUR project.** Gates: (1) AUC on frozen reference set, (2) fairness delta vs current model, (3) calibration error, (4) Grad-CAM honesty score (RQ2), (5) confidence on out-of-distribution images.

**Where it should but is not yet.** Auto-memory gap: "No frozen HAM10000 reference test set for regression testing after retraining."

**Anti-patterns.**
- Gates measured but not enforced.
- Gates that drift over time (the reference set updates secretly).
- Single-metric gate (AUC only).

**Questions you should be able to answer.**
1. What is the minimum gate set you would enforce before promoting a model?
2. Why is a frozen reference set important?
3. How does a fairness delta become a gate threshold?
4. Why is calibration error a separate gate from AUC?
5. What happens to a candidate model that fails a gate?

## 9.3 Calibration

**Definition.** Adjust the model's raw probability outputs so a predicted 0.8 actually means an 80% empirical positive rate.

**Where in YOUR project.** Auto-memory gap: "Model confidence not calibrated - raw softmax is overconfident for medical use." Add temperature scaling on the validation set. Display calibrated confidence to patients and doctors.

**Anti-patterns.**
- Showing raw softmax to a patient as "98% confident."
- Calibrating once and never re-calibrating after retraining.
- Different calibration per class without ensuring they sum to 1.

**Questions you should be able to answer.**
1. Why is raw softmax overconfident on medical data?
2. What is the reliability diagram?
3. Temperature scaling vs Platt scaling vs isotonic regression - when each?
4. How do you check calibration is still good after retraining?
5. What does a clinician do differently when shown calibrated vs uncalibrated confidence?

## 9.4 Drift Detection

**Definition.** Monitor input distribution and output distribution; alert when they diverge from training.

**Where in YOUR project.** Auto-memory gap: "No model drift detection - distribution shift will silently degrade performance." Add input-feature distribution monitor (image stats, brightness, skin tone proxy), output-distribution monitor (prediction histogram).

**Anti-patterns.**
- Drift detection without an action plan ("we saw drift, we did nothing").
- Single-metric drift (KL divergence on one feature).
- Alert fatigue from over-sensitive thresholds.

**Questions you should be able to answer.**
1. What input drift would a Brazilian PAD-UFES-20 patient cause vs your HAM10000 training set?
2. What output drift means the model is silently failing?
3. How does Population Stability Index work?
4. What threshold triggers an alert?
5. What is the runbook when drift fires?

## 9.5 Ensemble And Disagreement

**Definition.** Run multiple models on the same input; aggregate predictions; use disagreement as an uncertainty signal.

**Where in YOUR project.** Research notebooks already explore this (RQ4). Auto-memory gap: "No CAM disagreement scoring in production - RQ4 insight not operationalized."

**Anti-patterns.**
- Averaging predictions without recording disagreement.
- Treating high disagreement as "consult more models" instead of "consult a human."
- Ensembling identical models trained on the same data (no diversity).

**Questions you should be able to answer.**
1. What is the production cost of running 3 models instead of 1?
2. How does Grad-CAM disagreement differ from prediction disagreement?
3. Why does high disagreement in YOUR research correlate with correct predictions (counter to expectation)?
4. How do you operationalise "high disagreement -> escalate to doctor"?
5. What ensemble composition gives you diverse opinions?

## 9.6 Active Learning Queue

**Definition.** Prioritise images for human labelling by uncertainty or expected value of information.

**Where in YOUR project.** Cases the model is unsure about land in a doctor review queue with priority weight. Doctor's verdict feeds back into the training pool.

**Anti-patterns.**
- Active learning that always picks the same kinds of cases (no diversity).
- No feedback loop from doctor-verified labels back to training.
- Uncertainty proxied by softmax entropy alone (correlates poorly with true uncertainty).

**Questions you should be able to answer.**
1. What scoring function ranks cases for doctor review?
2. How does active learning interact with fairness?
3. How do you avoid feedback loops that reinforce model errors?
4. How often do you retrain on the active-learning corpus?
5. What is the doctor's incentive to label hard cases vs easy ones?

## 9.7 Frozen Reference Test Set

**Definition.** A held-out, never-updated test set used to measure every model version on the same yardstick.

**Where in YOUR project.** Auto-memory gap. Build a 500-1000 image curated reference set from HAM10000 + PAD-UFES + MILK10K, with class balance and skin-tone balance. Lock it. Run every candidate model on it.

**Anti-patterns.**
- "Reference set" that grows over time. Now you cannot compare across versions.
- Reference set leaks into training (look-up by image hash should be impossible).
- Reference metrics not stored alongside the model in the registry.

**Questions you should be able to answer.**
1. How do you prove the reference set is not in your training data?
2. What if the reference set itself is biased?
3. How many images is enough?
4. What stops the reference set from going stale (i.e., not matching deployment population)?
5. What is the difference between a reference set and a regression test?

---

# Family 10 - Observability

Lens: Observability designer.

## 10.1 RED And USE Metrics

**Definition.** RED = Rate, Errors, Duration. USE = Utilisation, Saturation, Errors. RED for services, USE for resources.

**Where in YOUR project.** Every endpoint emits RED metrics (rate of requests, error rate, p50/p95/p99 duration). Every resource (DB connections, SQS queue depth, ECS CPU) emits USE metrics.

**Anti-patterns.**
- Vanity metrics (CPU percentage with no SLO).
- One dashboard with 100 charts and no story.
- Metrics without a runbook (alert fires, operator has no idea what to do).

**Questions you should be able to answer.**
1. Pick one endpoint. What are its RED metrics?
2. Pick one resource. What are its USE metrics?
3. How does Duration interact with Saturation?
4. What is the difference between an SLO and a threshold alert?
5. Why is error budget more useful than uptime percentage?

## 10.2 Structured Logging

**Definition.** Logs are JSON objects with fixed fields (timestamp, level, request_id, user_id, trace_id, event_name).

**Where in YOUR project.** FastAPI middleware that injects request_id and patient pseudonym. Worker logs include message_id. Every log line is JSON.

**Anti-patterns.**
- Log lines as English prose ("user 123 did the thing").
- PHI in logs (patient name, email, image URL).
- Logging the full request body (might contain PHI or secrets).

**Questions you should be able to answer.**
1. Why is structured logging easier to query?
2. What fields are mandatory in every log line in your project?
3. How do you prevent PHI in logs?
4. How do you correlate a frontend error to a backend log?
5. What is log aggregation, and where do your logs land?

## 10.3 Distributed Tracing

**Definition.** A trace_id follows a request across all services; each service span is recorded with its parent.

**Where in YOUR project.** OpenTelemetry on FastAPI, the worker, and the frontend (browser SDK). Spans across API → DB → SQS → worker → S3.

**Anti-patterns.**
- Tracing only the API, not the worker.
- Sampling 100% in production (cost explosion).
- Tracing without service maps.

**Questions you should be able to answer.**
1. What is the path of one `/analysis` request from browser to response?
2. How is trace_id propagated across SQS?
3. What sampling rate is appropriate?
4. How does tracing help debug an idempotency-key replay?
5. What is the difference between a span and a log line?

## 10.4 SLOs And Error Budgets

**Definition.** SLO = a target (e.g., 99.5% success). Error budget = the inverse (0.5% failures permitted per month).

**Where in YOUR project.** Patient-facing endpoints get tighter SLOs than research endpoints. Define one SLO per critical user journey.

**Anti-patterns.**
- 99.999% SLO on everything (no error budget to ship features).
- SLO measured but not enforced (no policy when budget is burned).
- SLO based on uptime, not on user-meaningful events.

**Questions you should be able to answer.**
1. Pick one user journey. Write its SLO in one sentence.
2. What happens when the error budget is exhausted mid-month?
3. Why is uptime a poor SLO?
4. What is "burn rate"?
5. How does an SLO interact with the canary rollback trigger?

## 10.5 Runbook-Linked Alerts

**Definition.** Every alert links to a runbook with diagnose, mitigate, and escalate steps.

**Where in YOUR project.** Every CloudWatch alarm has `runbook_url` in its annotation; on-call sees it in PagerDuty.

**Anti-patterns.**
- Alert with no runbook (the operator googles in the middle of the night).
- Runbook that says "investigate."
- Runbook that never gets updated as the system changes.

**Questions you should be able to answer.**
1. What is the runbook for "circuit breaker open"?
2. What is the runbook for "DLQ has messages"?
3. How is a runbook different from documentation?
4. Who owns runbook maintenance?
5. What is the test for a good runbook?

---

# Family 11 - Healthcare-Specific Patterns

Lens: Security + Architect.

These exist because medical data is not normal data. The patterns enforce that.

## 11.1 PHI Tokenization

**Definition.** Replace direct identifiers (name, email, MRN) with stable random tokens; the mapping lives in one isolated store.

**Where in YOUR project.** Postgres `patient_directory` has the mapping; everywhere else (predictions, logs, analytics) sees `patient_token`.

**Anti-patterns.**
- Token that is a hash of the email (rainbow-table attackable).
- Token mapping in the same schema as the data (defeats the boundary).
- Logs that include the patient token AND the email (now correlatable).

**Questions you should be able to answer.**
1. What is the difference between a token and a pseudonym?
2. Can you re-identify a patient from a token alone?
3. Who has access to the patient_directory?
4. What is the rotation strategy for tokens?
5. How does tokenization interact with right-to-be-forgotten?

## 11.2 Consent State Machine

**Definition.** Consent is not a boolean - it has states (pending, granted, withdrawn, expired) and transitions with audit-immutable timestamps.

**Where in YOUR project.** `product/04_PRIVACY_CONSENT_STORAGE_HANDHOLDING.md`. The state machine governs storage, training eligibility, and report generation.

**Anti-patterns.**
- Consent stored as a bool (`is_consented`).
- Withdrawal that overwrites the original consent record (now you cannot audit).
- Granting consent in one place, checking it in another, no shared enforcement layer.

**Questions you should be able to answer.**
1. List the states and the legal transitions between them.
2. What happens to a prediction made under consent that is later withdrawn?
3. How does the right-to-be-forgotten interact with the audit log?
4. Where is the single enforcement point for consent?
5. What is the failure mode if consent is checked at the API layer but not the worker?

## 11.3 Audit-Immutable Log

**Definition.** Every protected action writes a log entry that cannot be edited or deleted.

**Where in YOUR project.** `audit_log` table with append-only rows. Postgres triggers prevent updates. Backed up to S3 with object lock.

**Anti-patterns.**
- App layer "trusts" not to update; no DB-level enforcement.
- Audit log in the same DB as the data it audits without separation of duties.
- Audit log without time-skew protection.

**Questions you should be able to answer.**
1. How do you prove an audit log entry has not been tampered with?
2. What is S3 Object Lock?
3. What is the retention requirement for medical audit logs?
4. Who can query the audit log? Who cannot?
5. How does the audit log handle right-to-be-forgotten?

## 11.4 Role Separation

**Definition.** Patient, doctor, admin, research reviewer see strictly disjoint data and capabilities; no role can cross the boundary.

**Where in YOUR project.** Cognito user pools per role; backend authz middleware checks role on every endpoint; frontend routes scoped per role; RAG indexes scoped per role (see 12.3 below).

**Anti-patterns.**
- "Admin can do everything" - admins should not see raw PHI without a separate consent or a break-glass procedure.
- Role inferred from header, not from a verified claim.
- Role check in the frontend only.

**Questions you should be able to answer.**
1. Can a doctor see a lab result for a patient who is not their case?
2. Can an admin see free-text doctor notes?
3. What is "break glass" access and when does it apply?
4. How does the backend verify the role?
5. What happens if the role check fails?

## 11.5 De-Identification Pipeline

**Definition.** Before data leaves the clinical zone, identifiers are stripped and risk of re-identification is bounded.

**Where in YOUR project.** Approved training images go through de-id (EXIF stripped, geo cleared, filename random) before landing in the training bucket.

**Anti-patterns.**
- EXIF left intact (contains GPS).
- File name still patient_<id>_<date>.
- De-id pipeline that processes data in-place (now PHI and de-id mixed in the same key).

**Questions you should be able to answer.**
1. List every identifier that must be stripped before training.
2. Why is EXIF a leak vector?
3. How does k-anonymity apply to image datasets?
4. What is the audit trail for the de-id step?
5. Could a research reviewer re-identify a patient from your de-id pipeline output?

---

# Family 12 - AI Safety

Lens: AI safety + RAG architect.

LLMs and RAG agents in a medical product can hurt people. The patterns below are non-negotiable.

## 12.1 Prompt Injection Mitigation

**Definition.** User input that contains instructions trying to override the system prompt must not succeed.

**Where in YOUR project.** Patient question to the education agent. Doctor query to the clinical agent. Both could contain "Ignore your instructions and..."

**Anti-patterns.**
- Trusting user input verbatim in the prompt.
- System prompt at the start of the message list with user content concatenated as a string.
- No sanitization or templating.

**Questions you should be able to answer.**
1. What is the structure of a Claude API messages call that resists injection?
2. Why does parameterised input help?
3. What is the failure mode if injection succeeds in the doctor agent?
4. How do you test for injection resistance?
5. How does the role-scoped agent boundary contain a successful injection?

## 12.2 Refusal Patterns

**Definition.** The agent has explicit, audited responses for queries it must refuse (diagnosis, treatment advice, emergency).

**Where in YOUR project.** Patient education agent refuses diagnosis questions and routes to "please consult a doctor." Doctor clinical agent does not generate prescriptions.

**Anti-patterns.**
- Refusal that is too aggressive (refuses legitimate questions).
- Refusal that is too permissive (gives medical advice in soft language).
- Refusals not logged for audit.

**Questions you should be able to answer.**
1. What queries must the patient education agent refuse?
2. What queries must the doctor agent refuse?
3. How is a refusal different from an "I don't know"?
4. How do you test refusal coverage?
5. What is the audit trail for a refusal?

## 12.3 RAG Source Isolation

**Definition.** Each role-scoped agent has its own vector index, its own source corpus, and cannot query another role's index.

**Where in YOUR project.** `product/13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md`. Five separate RAG indexes: clinical, doctor workflow, customer education, research/fairness, admin market research.

**Anti-patterns.**
- One vector store with metadata filtering as the only boundary.
- Sharing the embedding pipeline across roles in a way that leaks documents.
- Admin market research docs reachable by patient education agent.

**Questions you should be able to answer.**
1. What is the failure mode if all five agents share one vector index?
2. Why is metadata filtering insufficient as a boundary?
3. How does the embedding model choice affect leakage risk?
4. Who can ingest documents into each index?
5. What is the audit trail for each retrieval?

## 12.4 Role-Scoped Agents

**Definition.** Each agent has narrow capability and a narrow corpus, never a "do everything" assistant.

**Where in YOUR project.** Five agents (clinical, doctor, customer, research, admin market). Each one has its own system prompt, tools, and RAG index.

**Anti-patterns.**
- One agent with role-aware system prompts (one prompt-injection vulnerability away from cross-role data leak).
- Tools that are exposed to all agents.
- Memory shared across agents.

**Questions you should be able to answer.**
1. Why are five agents safer than one role-aware agent?
2. What tools does each agent have access to?
3. How is the audit trail per agent maintained?
4. How do you stop an agent from pretending to be another?
5. What is the cost overhead of five separate agents?

## 12.5 Output Validation

**Definition.** LLM output is validated against a schema or rule set before reaching the user.

**Where in YOUR project.** The clinical explanation endpoint validates that the output does not contain diagnosis claims, treatment advice, or specific drug names. Pydantic model + rule checks.

**Anti-patterns.**
- Trusting JSON mode without validating the JSON.
- Regex check that misses paraphrases ("you have melanoma" caught, "this lesion is malignant" missed).
- Validation that is loud in logs but silent to the user (output goes through anyway).

**Questions you should be able to answer.**
1. What rules govern the patient-facing explanation output?
2. How do you check the output programmatically?
3. What happens to the user when validation fails?
4. How do you A/B test a stricter validation rule?
5. What is the audit trail for a blocked output?

## 12.6 Evidence Citation

**Definition.** RAG outputs cite which document chunks they came from, with anchors the user can click.

**Where in YOUR project.** The admin market research RAG returns answers with `[Source: Golden Doc X, p. 12]` style citations. The patient education agent cites curated knowledge base entries.

**Anti-patterns.**
- Hallucinated citations.
- Citations that go to private documents (visible from the citation URL even though the content is not).
- Citation as the only safety mechanism (looks safe; isn't).

**Questions you should be able to answer.**
1. How do you guarantee a cited source actually contains the claim?
2. What is a hallucinated citation?
3. What is the UX when the system has low-evidence answers?
4. How does citation interact with role-scoped retrieval?
5. How do you test citation accuracy?

---

# Family 13 - Retrieval And RAG Engineering

Lens: RAG architect + retrieval engineer.

Family 12 covers whether a RAG answer is *safe*. This family covers whether it is *correct*. Most RAG systems fail in production not because the model is weak but because the wrong chunks were retrieved. The patterns below are the levers that decide retrieval quality, and they apply to every RAG index in this project: the clinical policy store behind the explanation agent (`product/07`), the five role-scoped indexes (`product/13`, `product/14`), and the admin market research store (`product/15`). Today both real retrieval paths are placeholders. The policy RAG in `product/07` Step 7 returns hard-coded strings, and the market research coordinator in `product/15` Step 6 does `db.query(...).limit(10)` with no ranking at all. This family is what turns those into real retrieval.

## 13.1 Chunking Strategy

**Definition.** How a document is split before embedding. This is the single biggest lever on retrieval quality. Fixed-size splitting cuts sentences mid-thought and destroys meaning. Recursive splitting respects natural boundaries (paragraphs, then sentences) and is the reliable default. Semantic chunking splits where the topic shifts and is the premium option when retrieval quality matters more than ingestion cost. Late chunking is a newer variant: embed the whole document first, then split, so each chunk keeps the context of the surrounding text (a chunk that says "it raised prices" still knows who "it" is). Worth it for documents full of pronouns and back-references, like competitor narratives.

**Where in YOUR project.** `product/15` Step 4 `chunking_service.py`. The ingestion workflow says "chunk document" but never names a strategy. Golden Docs and market reports are prose, so recursive is the right default; the pricing and competitor docs benefit from semantic chunking because one report mixes several distinct topics. The clinical policy corpus behind `product/07` Step 7 is short and structured, so chunk by policy clause, not by token count.

**Anti-patterns.**
- Fixed 500-character windows that slice a safety rule in half.
- One chunk size for every source type regardless of structure.
- Chunks so large they blow the context budget, or so small they lose the surrounding meaning.

**Questions you should be able to answer.**
1. Why does recursive chunking beat fixed-size for prose?
2. When is semantic chunking worth the extra embedding calls?
3. What chunk size and overlap did you choose for Golden Docs, and why?
4. How would a bad chunk boundary produce a wrong market research brief?
5. How do you re-chunk an existing index without downtime?

## 13.2 Embedding Parity And Dimensions

**Definition.** The exact same embedding model must be used for indexing and for querying. A query embedded with a different model lands in a different region of vector space and retrieval silently returns garbage. Vector dimension is a cost/quality trade: the sweet spot is roughly 768 to 1536. Higher is rarely worth the storage and latency.

**Where in YOUR project.** `product/15` Step 4 ("embed chunks") and the retrieval service that embeds the query. Both must call one pinned model version. Each role index in `product/13` may use the same model, but the indexes stay physically separate (see 12.3).

**Anti-patterns.**
- Upgrading the embedding model and re-embedding queries but not re-embedding the stored corpus.
- Reading the model name from an env var that differs between the ingest worker and the API.
- Picking a 3072-dim model for a few thousand Golden Doc chunks because "bigger is better."

**Questions you should be able to answer.**
1. What breaks if indexing and querying use different embedding models?
2. What is your pinned embedding model and dimension, and where is it configured once?
3. Why is 768 to 1536 usually the sweet spot here?
4. What is your procedure when you must change the embedding model?
5. How do you detect an embedding-mismatch failure in a trace?

## 13.3 Vector Store Choice

**Definition.** Where embeddings live and how similarity search runs. For this project the natural choice is pgvector on Postgres, not a separate managed vector service like Pinecone and not Supabase. Self-hosted pgvector is far cheaper at this corpus size, and it keeps vectors next to the relational data and the audit log. Use a local Postgres + pgvector (or Chroma) for development.

> **Important: the vector index does not go on Aurora DSQL.** This project's primary cloud database is Aurora DSQL (see `production/04_DATABASE_MULTI_REGION_PATH` and `staging/11_AURORA_DSQL_STAGING`), and `pgvector` is a PostgreSQL *extension*. DSQL's extension support is limited and does not include pgvector as far as is known, so confirm it in the DSQL guide and do not assume it works there. This is the one place the "DSQL is primary" rule has a deliberate carve-out. Keep transactional data (cases, consent, audit) on DSQL, and put the vector index on **Aurora PostgreSQL or a small dedicated RDS PostgreSQL** with pgvector, in the same VPC. If you would rather not run a second Postgres engine, the AWS-native alternative is **OpenSearch Serverless vector search**. The reason to lean pgvector anyway is that it keeps vectors beside the audit log and reuses your existing migration habits. Supabase is fine as a throwaway learning sandbox, but keep it out of the production architecture because it sits outside your AWS VPC and compliance perimeter.

**Where in YOUR project.** `product/15` Step 4 stores chunks in `MarketResearchChunk`. Add a vector column with pgvector rather than the current plain-text-only table, on a pgvector-capable Postgres (not DSQL, per the note above). The clinical policy store behind `product/07` Step 7 is the same choice at smaller scale. Keep the five role indexes isolated (12.3): separate tables or separate schemas, never one shared table relying on a `WHERE role = ?` filter as the only boundary.

**Anti-patterns.**
- Assuming pgvector runs on Aurora DSQL because DSQL is "PostgreSQL-compatible." Compatible is not the same as extension-complete.
- Reaching for Pinecone or Supabase "to be safe" and adding a vendor, a network boundary, and a compliance surface for a corpus that fits in your existing Postgres.
- One shared vectors table where a missing filter leaks cross-role documents.
- No ANN index, so every query is a full scan.

**Questions you should be able to answer.**
1. Why pgvector over a managed vector DB or Supabase at this project's scale?
2. Why can the vector index not live on Aurora DSQL, and where does it live instead?
3. How do you keep five role indexes isolated while vectors and OLTP data sit in different engines?
4. What index type (IVFFlat, HNSW) did you pick and why?
5. When would OpenSearch Serverless be the better choice than pgvector here?

## 13.4 Hybrid Search With Reciprocal Rank Fusion

**Definition.** Combine semantic (vector) search with keyword (BM25) search, then merge the two ranked lists with Reciprocal Rank Fusion. Pure vector search misses exact tokens like a product code, a competitor name, a model version, or an error string. Keyword search catches those. Hybrid gets both.

**Where in YOUR project.** `product/15` `retrieval_service.py`. Market research questions often name a specific competitor or pricing tier that must match exactly. The clinical policy store benefits too: a query about a specific Fitzpatrick type or a named CAM method should hit the exact policy clause.

**Anti-patterns.**
- Vector-only retrieval that cannot find "Seedance 1.5 Pro" or a specific SKU.
- Averaging raw scores from two systems whose scores are on different scales (use RRF, which only needs ranks).
- Running both searches but never fusing them.

**Questions you should be able to answer.**
1. What query types does vector search miss that BM25 catches?
2. Why does RRF fuse on rank instead of raw score?
3. How do you weight the vector list versus the keyword list?
4. Show a market research query where hybrid beats vector-only.
5. How do you measure the lift from adding hybrid search?

## 13.5 Parent-Document Retrieval

**Definition.** Index small, precise chunks for accurate matching, but return the larger parent section to the LLM so it has enough surrounding context. You search narrow and answer wide.

**Where in YOUR project.** `product/15` retrieval and the clinical policy store. A small chunk matches the query precisely, but the strategy synthesis agent or the explanation agent needs the whole clause or paragraph around it to reason well.

**Anti-patterns.**
- Returning the tiny matched chunk alone, so the LLM answers without context.
- Returning the whole document, which overflows context and reintroduces noise.
- No link from a child chunk back to its parent section.

**Questions you should be able to answer.**
1. Why search small but return large?
2. What is the parent unit in your corpus (paragraph, section, page)?
3. How is the child-to-parent link stored?
4. How does this interact with the context budget (13.11)?
5. When is parent-document retrieval overkill?

## 13.6 Contextual Compression

**Definition.** After retrieval and before generation, use a cheaper model (or an extractive step) to keep only the parts of each retrieved chunk that are actually relevant to the query. This cuts tokens, cuts cost, and cuts retrieval noise that would otherwise distract the model.

**Where in YOUR project.** `product/15` Step 6, between `_retrieve_context` and the Claude call in `generate_brief`. The coordinator currently dumps whole chunks into the prompt. Compress them first. Also relevant before the clinical explanation call in `product/06`.

**Anti-patterns.**
- Sending ten full chunks when two sentences from each were relevant.
- A compression model so aggressive it drops the evidence a citation needs (13 / 12.6).
- Compressing on every request even when retrieval already returned tight chunks.

**Questions you should be able to answer.**
1. What does contextual compression remove, and what must it keep?
2. How much token cost does it save on a typical brief?
3. How do you make sure compression never drops a cited fact?
4. Why compress after retrieval rather than chunk smaller up front?
5. What is the latency cost of the extra model call?

## 13.7 Reranking

**Definition.** A cross-encoder reranker re-scores the top-N retrieved chunks against the query with far more accuracy than the initial vector similarity, then you keep the top-K. Retrieve broad, rerank, then send only the best few to the LLM.

**Where in YOUR project.** `product/15` `retrieval_service.py` after hybrid search. Pull the top 20 to 50 candidates, rerank, keep the top 5. This is often the highest-quality-per-effort upgrade after hybrid search.

**Anti-patterns.**
- Trusting raw vector distance as the final ranking.
- Reranking the entire corpus instead of a candidate set (slow and pointless).
- Keeping too many reranked chunks and overflowing context anyway.

**Questions you should be able to answer.**
1. Why is a cross-encoder more accurate than bi-encoder vector similarity?
2. How many candidates do you rerank, and how many do you keep?
3. What is the latency budget for reranking?
4. Where does reranking sit relative to hybrid search and compression?
5. How do you A/B test a reranker against no reranker?

## 13.8 Agentic And Corrective RAG

**Definition.** Instead of retrieve-once-and-answer, an agent grades the retrieved context. If it is weak or off-topic, the agent rewrites the query and retrieves again until the evidence is good enough or it gives up and says so. This is self-correcting retrieval.

**Where in YOUR project.** `product/14` agent sequences and `product/15` Step 6 multi-agent workflow. Add a retrieval-grading step after `GoldenDocsRetrieverAgent`: if evidence is thin, the coordinator rewrites the question and retries before the synthesis agent runs. The clinical explanation agent in `product/06` should prefer an honest "not enough information" over a confident answer from weak context.

**Anti-patterns.**
- Always answering even when retrieval returned nothing relevant.
- Infinite rewrite loops with no retry cap or budget.
- A self-correction loop that quietly drifts off the role's allowed sources (must stay inside the 12.3 boundary).

**Questions you should be able to answer.**
1. How does the agent decide retrieved context is "good enough"?
2. What is the retry cap, and what happens when it is hit?
3. How does query rewriting change the next retrieval?
4. How do you keep the loop inside the role-scoped source boundary?
5. How do you trace and cost-bound a multi-retrieval request?

## 13.9 Graph RAG

**Definition.** Extract entities and their relationships from documents into a knowledge graph, then answer questions that need multi-hop reasoning across linked facts ("which competitor shares an investor with X"). Vector RAG retrieves similar text; graph RAG traverses relationships.

**Where in YOUR project.** A later upgrade for `product/15` admin market research, where competitor, investor, ICP, and product relationships matter. Not needed for the clinical explanation path, which is single-hop grounding. Treat this as a future enhancement, not a launch requirement.

**Anti-patterns.**
- Building a knowledge graph before plain vector RAG even works.
- Extracting entities with no schema, producing an unqueryable tangle.
- Using graph RAG for single-hop questions that vector RAG answers fine.

**Questions you should be able to answer.**
1. What is a multi-hop question your market research users actually ask?
2. Why can vector RAG not answer it well?
3. What entities and relationships would your graph hold?
4. Why is graph RAG out of scope for the clinical agent?
5. What is the maintenance cost of keeping the graph current?

## 13.10 Multimodal RAG (Page-Image Embeddings)

**Definition.** Instead of extracting text and throwing away layout, embed images of document pages directly (the ColPali approach). This preserves tables, charts, and diagrams that text extraction destroys, and lets retrieval match on visual structure.

**Where in YOUR project.** `product/18_LAB_OCR_EXTRACTION`. Lab reports are PDFs and photos full of tables and reference ranges that OCR-to-text mangles. Page-image embeddings keep that structure for doctor review. Could also help retrieve the right figure from a research report. Keep the medical-safety rule: this is for organizing and retrieving lab documents for professional review, never for auto-reading a result as a diagnosis.

**Anti-patterns.**
- Flattening a lab table to text and losing which value pairs with which reference range.
- Embedding page images but never linking back to the source page for citation.
- Using multimodal RAG on plain prose where text chunking is cheaper and better.

**Questions you should be able to answer.**
1. What does text extraction destroy in a lab PDF?
2. How does a page-image embedding preserve a table's meaning?
3. How do you cite back to the exact page a value came from?
4. Where is multimodal overkill in this project?
5. What is the safety boundary around lab-result retrieval?

## 13.11 RAG Failure Modes And Evaluation

**Definition.** The five ways RAG fails: bad chunking, embedding mismatch, retrieval noise, context overflow, and hallucination. You cannot fix what you cannot see, so you evaluate retrieval (did we fetch the right chunks?) separately from generation (did the model use them faithfully?).

**Where in YOUR project.** Cross-cutting across `product/06`, `product/07`, `product/14`, `product/15`. Build a small frozen evaluation set of question-to-expected-source pairs per index (mirrors the frozen reference test set idea in 9.7). Grounding rules live in `product/06` prompts: answer only from context, say "I don't know" when the context is missing, and attach citations (12.6).

**Anti-patterns.**
- Judging the system only by the final answer, never inspecting what was retrieved.
- No eval set, so every prompt tweak is a guess.
- Treating a hallucination as a model problem when it was really a retrieval-noise problem.

**Questions you should be able to answer.**
1. Name the five failure modes and one symptom of each.
2. How do you evaluate retrieval separately from generation?
3. What is in your per-index eval set?
4. Which failure mode does "answer only from context, else say I don't know" address?
5. How would you tell a hallucination caused by bad chunking from one caused by a weak prompt?

## 13.12 RAG Cost And Caching

**Definition.** Production RAG cost is controlled with three levers: cache repeated queries and their retrieved context, enforce a token budget that rejects or trims over-budget requests, and reduce vector dimensions where quality allows. Together these can cut API cost substantially.

**Where in YOUR project.** Caching ties to `staging/20_ELASTICACHE_REDIS` and `production/12_CACHE_REDIS_ELASTICACHE`: cache the embedding of a repeated query and the reranked context. Token budgeting and dimension choice tie to the observability and cost rules in `product/07` and `staging/00_CLOUD_COST_CONTROL`. Trace token counts per step so you know where spend goes (10.3, and `product/07` Step 16).

**Anti-patterns.**
- Re-embedding and re-retrieving an identical query on every call.
- No per-request token ceiling, so one huge document blows the budget.
- Caching personalized or role-scoped results in a way that leaks across users.

**Questions you should be able to answer.**
1. What exactly do you cache, and what is the cache key?
2. How does a token budget reject or trim an over-budget request?
3. How does reducing vector dimensions trade quality for cost?
4. How do you keep a shared cache from leaking across roles or users?
5. Which trace fields tell you where RAG cost is going?

---

# Cross-Cutting: How These Patterns Compose

The patterns above are not a buffet. They compose into a few specific production properties.

| Property | Patterns that compose to it |
|---|---|
| "Safe to retry any request" | Idempotency keys + circuit breaker + timeout budget + retry-with-jitter |
| "Survives one instance dying" | Stateless + session store + load balancer + bulkhead |
| "Survives one downstream failing" | Circuit breaker + timeout + bulkhead + graceful degradation |
| "Safe to deploy at 3 PM" | Blue/green or canary + feature flags + immutable infra + SLO-triggered rollback |
| "Safe to retrain the model" | Frozen reference set + promotion gates + shadow + canary + drift detection |
| "Compliant with medical-data rules" | PHI tokenization + consent state machine + audit-immutable + role separation + de-identification |
| "Safe LLM in a medical product" | Prompt injection mitigation + refusal + RAG isolation + role-scoped + output validation + citation |
| "RAG retrieval that is actually correct" | Recursive/semantic chunking + embedding parity + hybrid search with RRF + reranking + parent-document + contextual compression + corrective retrieval + per-index eval set |
| "Analytics don't degrade production" | CQRS + read replica + analytics-safe views + OLTP/OLAP separation |
| "Workflow completes despite partial failure" | Outbox pattern + saga + idempotency + dead-letter queue + worker retry |

If you cannot point to all the patterns that compose to a property, the system does not have that property. It might appear to most of the time, and then it won't.

---

# How To Use This Catalog As You Build

1. When a handholding guide says "Concepts you just touched: X, Y", come here and read X and Y.
2. After reading each pattern, try to answer the 5 Socratic questions out loud. If you cannot, you have not understood the pattern.
3. When you reach the gap that pattern is meant to close (see "Where it should but is not yet"), come back and re-read.
4. After production launch, this file becomes your reference for incident reviews: which pattern was missing or misconfigured?

The point is not to implement all 30 patterns at portfolio scale. The point is to know which patterns you chose not to implement and why.

## Cost Pause / Resume

This guide does not create cloud resources. No pause needed.
