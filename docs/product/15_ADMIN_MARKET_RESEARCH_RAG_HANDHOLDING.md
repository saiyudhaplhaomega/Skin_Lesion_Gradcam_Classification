# Admin Market Research RAG And Multi-Agent Handholding Guide

Use this after:

```text
13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md
10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md
12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md
14_ROLE_BASED_EVOLVING_AGENTS_HANDHOLDING.md
```

What this prerequisite block means:
- These guides define the LLM boundaries, doctor/admin workflows, research monitoring, and role-based agent rules required before admin market research RAG.
- Do not build this feature until those boundaries are understood.

Do not build this before the admin role, admin dashboard, audit rules, research-safe data boundaries, and role-based agent boundaries are understood.

## Command Location

Run commands from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- Start here because backend and frontend repositories are both inside this folder.

Backend commands run from:

```powershell
cd Skin_Lesion_Classification_backend
```

What this command does:
- This moves into the backend repository.
- Run backend file creation, migrations, and tests from there.

Frontend commands run from:

```powershell
cd Skin_Lesion_Classification_frontend
```

What this command does:
- This moves into the frontend repository.
- Run Next.js and `npm` commands from there.

## Goal

Build an administrator-only market research LLM that uses RAG and multi-agent workflows.

It should behave like a strategic consultant:

```text
research analyst
ICP analyst
competitor analyst
sales advisor
product opportunity analyst
pricing and packaging assistant
GTM strategy assistant
```

What this role block means:
- These are the strategic roles the admin-only market research LLM should support.
- They are business and product strategy roles, not patient-care roles.

It must not retrieve or reason over patient PHI.

## Step 1: Create Golden Docs Folder

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Golden Docs and backend market-research files are created inside the backend repository.

Create:

```text
docs/market-research/golden-docs/
docs/market-research/intake/
docs/market-research/briefs/
```

What this folder list means:
- `golden-docs` stores approved high-trust strategy documents.
- `intake` stores incoming research material before approval.
- `briefs` stores generated or approved market research briefs.

Command:

```powershell
New-Item -ItemType Directory -Force docs\market-research\golden-docs, docs\market-research\intake, docs\market-research\briefs
```

What this command does:
- `New-Item -ItemType Directory` creates directories.
- `-Force` makes it safe to rerun if folders already exist.
- The comma-separated paths create all three market-research folders.

Create starter files:

```text
docs/market-research/golden-docs/01_COMPANY_OVERVIEW.md
docs/market-research/golden-docs/02_ICP_AND_BUYER_PERSONAS.md
docs/market-research/golden-docs/03_COMPETITOR_INTELLIGENCE.md
docs/market-research/golden-docs/04_MARKET_AND_AI_TRENDS.md
docs/market-research/golden-docs/05_HEALTHCARE_COMPLIANCE_AND_PRIVACY.md
docs/market-research/golden-docs/06_PRICING_AND_PACKAGING_HYPOTHESES.md
docs/market-research/golden-docs/07_PRODUCT_POSITIONING_AND_MESSAGING.md
docs/market-research/golden-docs/08_ADMIN_MARKET_RESEARCH_AGENT_POLICY.md
```

What this starter-file list means:
- These files define the initial Golden Docs knowledge base.
- Company overview, ICP, competitors, trends, compliance, pricing, positioning, and agent policy become the admin-approved strategy memory.

Check:

```powershell
Get-ChildItem docs\market-research\golden-docs
```

What this command does:
- It lists the Golden Docs folder so you can confirm the placeholder files exist.

Expected result: the Golden Doc placeholders exist.

Why: Golden Docs are the high-trust strategic memory foundation, but they belong after the admin system exists.

## Step 2: Add Golden Doc Creation Prompts

Create:

```text
docs/market-research/GOLDEN_DOC_PROMPTS.md
```

What this path block means:
- Create this Markdown file in the backend market-research docs folder.
- It stores prompts for producing high-quality Golden Docs.

Paste:

```md
# Golden Doc Prompts

Use Google Gemini Deep Research Mode or another research workflow to create these admin-approved documents.

## Company Overview

Create an executive-level company overview for Skin Lesion XAI, an educational AI-assisted skin lesion monitoring platform for patients, doctors, administrators, and research reviewers.

Include company summary, target users, services/features, buyer personas, positioning, competitive differentiators, privacy posture, and growth opportunities.

## ICP And Competitor Intelligence

Create an ICP and competitor intelligence report for an AI-assisted skin lesion monitoring platform.

Include buyer pain points, buying triggers, objections, competitor messaging patterns, market gaps, positioning opportunities, and healthcare trust barriers.

## Market And AI Trends

Create a market and AI trends report for digital dermatology, explainable AI in healthcare, patient monitoring, doctor-review workflows, and privacy-aware medical imaging tools.

Include market growth trends, AI disruption, buyer behavior changes, emerging opportunities, and strategic GTM recommendations.

## Pricing And Packaging

Create pricing and packaging hypotheses for patient, clinic, doctor, research, and administrator use cases.

Include free/demo mode, patient subscription, clinic workflow package, research analytics package, enterprise/admin package, and risks.
```

What this prompt file does:
- It gives copy-paste prompts for creating admin-approved Golden Docs.
- The company overview prompt asks for target users, features, positioning, privacy posture, and growth opportunities.
- The ICP and competitor prompt asks for buyer pain points, triggers, objections, market gaps, and trust barriers.
- The market trends prompt asks for digital dermatology, XAI, monitoring, doctor-review workflows, and privacy-aware imaging trends.
- The pricing prompt asks for packaging hypotheses across patient, clinic, research, and enterprise/admin use cases.
- These prompts should be used with public or admin-approved sources, not patient data.

Check:

```powershell
Get-Content docs\market-research\GOLDEN_DOC_PROMPTS.md
```

What this command does:
- `Get-Content` prints the Golden Doc prompt file so you can confirm it was written.

Expected result: prompts are ready to copy into a research tool.

Why: the market research LLM improves when its knowledge base starts with high-quality source material.

## Step 3: Add Market Research Models

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Market research database models belong in the backend repository.

Create `app/models/market_research.py`:

```python
import enum
import uuid
from datetime import datetime

from sqlalchemy import DateTime, Enum, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class SourceStatus(str, enum.Enum):
    draft = "draft"
    approved = "approved"
    golden = "golden"
    archived = "archived"
    rejected = "rejected"


class TrustLevel(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class ConfidenceLevel(str, enum.Enum):
    low = "low"
    medium = "medium"
    high = "high"


class MarketResearchSource(Base):
    __tablename__ = "market_research_sources"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(300), nullable=False)
    source_type: Mapped[str] = mapped_column(String(100), nullable=False)
    status: Mapped[SourceStatus] = mapped_column(Enum(SourceStatus), default=SourceStatus.draft, nullable=False)
    trust_level: Mapped[TrustLevel] = mapped_column(Enum(TrustLevel), default=TrustLevel.medium, nullable=False)
    uploaded_by_admin_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    source_uri: Mapped[str | None] = mapped_column(String(500), nullable=True)
    checksum: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    approved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)

    chunks: Mapped[list["MarketResearchChunk"]] = relationship("MarketResearchChunk", back_populates="source")


class MarketResearchChunk(Base):
    __tablename__ = "market_research_chunks"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    source_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("market_research_sources.id"), nullable=False)
    chunk_index: Mapped[int] = mapped_column(Integer, nullable=False)
    content_text: Mapped[str] = mapped_column(Text, nullable=False)
    embedding_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    metadata_json: Mapped[str | None] = mapped_column(Text, nullable=True)

    source: Mapped["MarketResearchSource"] = relationship("MarketResearchSource", back_populates="chunks")


class MarketResearchBrief(Base):
    __tablename__ = "market_research_briefs"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    admin_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), nullable=False)
    question: Mapped[str] = mapped_column(Text, nullable=False)
    executive_summary: Mapped[str] = mapped_column(Text, nullable=False)
    recommendation: Mapped[str] = mapped_column(Text, nullable=False)
    evidence_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    risks_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    missing_data_json: Mapped[str] = mapped_column(Text, default="[]", nullable=False)
    confidence_level: Mapped[ConfidenceLevel] = mapped_column(
        Enum(ConfidenceLevel), default=ConfidenceLevel.medium, nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
```

What this model code does:
- `enum` defines fixed status, trust, and confidence values.
- `uuid` creates unique IDs for sources, chunks, and briefs.
- `datetime` stores created, approved, and archived timestamps.
- SQLAlchemy imports define database column types, foreign keys, and relationships.
- `Mapped`, `mapped_column`, and `relationship` are SQLAlchemy ORM helpers.
- `Base` is the shared SQLAlchemy model base.
- `SourceStatus` controls the lifecycle of market research sources.
- `TrustLevel` records how reliable a source is considered.
- `ConfidenceLevel` records the confidence of a generated brief.
- `MarketResearchSource` stores one uploaded or approved market research source.
- `uploaded_by_admin_id` links a source to the admin who uploaded it.
- `source_uri` and `checksum` support source tracking and duplicate detection.
- `chunks` defines the relationship from a source to its text chunks.
- `MarketResearchChunk` stores chunked text used for retrieval.
- `embedding_id` can reference a vector-store embedding record.
- `metadata_json` stores extra chunk metadata.
- `MarketResearchBrief` stores a generated admin decision brief.
- `evidence_json`, `risks_json`, and `missing_data_json` store structured lists as JSON text.

Create `app/schemas/market_research_schema.py`:

```python
import uuid
from datetime import datetime
from pydantic import BaseModel


class BriefRequest(BaseModel):
    question: str
    focus_area: str = "general"   # "icp" | "competitor" | "market_trends" | "pricing" | "gtm"
    include_recent_sources: bool = True


class BriefResponse(BaseModel):
    brief_id: uuid.UUID
    executive_summary: str
    recommendation: str
    evidence_used: list[str]
    risks_and_assumptions: list[str]
    suggested_next_actions: list[str]
    confidence_level: str
    missing_data: list[str]
    created_at: datetime

    model_config = {"from_attributes": True}


class SourceResponse(BaseModel):
    id: uuid.UUID
    title: str
    source_type: str
    status: str
    trust_level: str
    created_at: datetime

    model_config = {"from_attributes": True}
```

What this schema code does:
- `uuid` supports UUID fields in API responses.
- `datetime` supports created-at fields.
- `BaseModel` is Pydantic’s schema base class.
- `BriefRequest` defines the admin’s brief-generation request.
- `question` is the business question.
- `focus_area` defaults to `general` and can narrow the analysis to ICP, competitors, trends, pricing, or GTM.
- `include_recent_sources` lets the request include newer approved material.
- `BriefResponse` defines the structured decision brief returned by the API.
- `evidence_used`, `risks_and_assumptions`, `suggested_next_actions`, and `missing_data` are lists so the frontend can render them cleanly.
- `SourceResponse` defines the shape returned for market research sources.
- `model_config = {"from_attributes": True}` lets Pydantic build responses from SQLAlchemy models.

Add to `app/models/__init__.py`:

```python
from app.models.market_research import MarketResearchBrief, MarketResearchChunk, MarketResearchSource
```

What this code does:
- Importing the models helps Alembic discover them when generating migrations.

Migrate:

```powershell
alembic revision --autogenerate -m "add market research tables"
alembic upgrade head
make test
```

What this command block does:
- `alembic revision --autogenerate -m "add market research tables"` creates a migration for the new tables.
- `alembic upgrade head` applies the migration.
- `make test` runs backend tests after the database change.

Expected result: model imports and migrations/tests pass.

Why: sources, chunks, and generated briefs need durable records with review status.

## Step 4: Add Market Research RAG Ingestion

Create:

```text
app/rag/admin_market_research/ingestion_service.py
app/rag/admin_market_research/chunking_service.py
app/rag/admin_market_research/retrieval_service.py
```

Ingestion workflow:

```text
upload document
classify source type
extract metadata
redact sensitive data
chunk document
embed chunks
store chunks in market research index
mark source draft
show source in admin review queue
```

Allowed source types:

```text
golden_doc
competitor_note
market_report
sales_note
admin_note
pricing_experiment
seo_search_insight
product_feedback_summary
conference_note
approved_strategy_brief
```

Blocked source types:

```text
patient_image
lesion_record
lab_report
doctor_note
patient_free_text
clinical_report
raw_private_analytics
secret_or_credential
```

Check:

```powershell
make test
```

Expected result: blocked source types cannot be ingested into admin market research RAG.

Why: market research RAG can update over time, but only with the right data.

### Learning: get ingestion right or everything downstream is noise

The ingestion workflow above lists "chunk document" and "embed chunks" as single lines. Those two lines decide retrieval quality more than any other code in this feature. Production RAG fails far more often from bad indexing than from a weak model. The full pattern catalog is in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13; here is what it means for these three files.

- **Chunking (`chunking_service.py`).** Do not use fixed-size character windows; they cut sentences mid-thought. Use recursive chunking as the default, since it respects paragraph and sentence boundaries. For the mixed-topic sources here (competitor notes, pricing experiments, market reports), semantic chunking, which splits where the topic shifts, is worth the extra cost. See Family 13.1.
- **Embeddings (`ingestion_service.py` + `retrieval_service.py`).** Pin one embedding model and dimension, and use the exact same model for both indexing and querying. A query embedded with a different model returns silent garbage. Keep the dimension in the 768 to 1536 sweet spot; bigger is rarely worth the storage and latency here. See Family 13.2.
- **Vector store.** Store an actual vector on `MarketResearchChunk` using pgvector, not a separate managed service like Pinecone and not Supabase. Self-hosted pgvector is far cheaper at this corpus size and keeps vectors next to the audit log. One catch: pgvector is a PostgreSQL extension, and this project's primary cloud database is Aurora DSQL, which does not support it (confirm in `staging/11_AURORA_DSQL_STAGING`). So keep transactional data on DSQL but put this vector index on **Aurora PostgreSQL or a small dedicated RDS PostgreSQL** with pgvector, in the same VPC. The AWS-native alternative is OpenSearch Serverless vector search. Keep this index physically separate from the other four role indexes (`product/13`). Use local Postgres + pgvector or Chroma in development. Full reasoning in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.3.

## Step 5: Add Admin Approval Workflow

Create:

```text
app/api/v1/admin_market_research_sources.py
app/services/admin_market_research_source_service.py
```

Endpoints:

```text
POST /api/v1/admin/market-research/sources
GET /api/v1/admin/market-research/sources
POST /api/v1/admin/market-research/sources/{source_id}/approve
POST /api/v1/admin/market-research/sources/{source_id}/promote-to-golden
POST /api/v1/admin/market-research/sources/{source_id}/archive
POST /api/v1/admin/market-research/sources/{source_id}/reject
```

Rules:

```text
only admin role can upload or approve
draft sources are visible in admin review but not used by default retrieval
approved sources can be retrieved
golden sources have highest retrieval priority
archived and rejected sources are not retrieved
all status changes create audit logs
```

Check:

```powershell
make test
```

Expected result: admin can approve market research sources and status changes are audited.

Why: evolving RAG needs human approval before new material affects strategy answers.

## Step 6: Add Multi-Agent Workflow

Create the coordinator first - this is the only file you need to get the API working. The specialist agents can be added incrementally.

Create `app/agents/admin_market_research/coordinator.py`:

```python
"""
Admin Market Research multi-agent coordinator.
Start with a single-agent stub (coordinator calls Claude directly).
Add specialist agents (ICPAnalyst, CompetitorAnalyst, etc.) one by one as needed.
"""
from __future__ import annotations

import json
import os

import anthropic
from sqlalchemy.orm import Session

from app.models.market_research import MarketResearchChunk, MarketResearchSource, SourceStatus
from app.schemas.market_research_schema import BriefRequest, BriefResponse


class MarketResearchCoordinator:
    MODEL = "claude-haiku-4-5-20251001"

    def __init__(self) -> None:
        self._client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])

    def _retrieve_context(self, db: Session, question: str, limit: int = 10) -> list[str]:
        """Retrieve relevant chunks from golden/approved sources only."""
        chunks = (
            db.query(MarketResearchChunk)
            .join(MarketResearchSource, MarketResearchChunk.source_id == MarketResearchSource.id)
            .filter(
                MarketResearchSource.status.in_([SourceStatus.golden, SourceStatus.approved])
            )
            .limit(limit)
            .all()
        )
        return [c.content_text for c in chunks]

    def generate_brief(self, db: Session, request: BriefRequest) -> BriefResponse:
        context_chunks = self._retrieve_context(db, request.question)
        context_str = "\n\n---\n\n".join(context_chunks) if context_chunks else "No approved sources available yet."

        system_prompt = """You are an admin-only strategic market research assistant for Skin Lesion XAI.
You produce structured decision briefs using only approved Golden Docs sources.
You never use patient data, clinical records, or PHI.
Always return valid JSON matching the brief schema."""

        user_message = f"""Question: {request.question}
Focus area: {request.focus_area}

Approved source context:
{context_str}

Return a JSON object with these keys:
executive_summary, recommendation, evidence_used (list), risks_and_assumptions (list),
suggested_next_actions (list), confidence_level (low/medium/high), missing_data (list)"""

        response = self._client.messages.create(
            model=self.MODEL,
            max_tokens=1500,
            system=system_prompt,
            messages=[{"role": "user", "content": user_message}],
        )

        try:
            brief_data = json.loads(response.content[0].text)
        except json.JSONDecodeError:
            brief_data = {
                "executive_summary": response.content[0].text[:500],
                "recommendation": "See full response above",
                "evidence_used": [],
                "risks_and_assumptions": [],
                "suggested_next_actions": [],
                "confidence_level": "low",
                "missing_data": ["JSON parsing failed - response not structured"],
            }

        import uuid
        from datetime import datetime
        return BriefResponse(
            brief_id=uuid.uuid4(),
            created_at=datetime.utcnow(),
            **brief_data,
        )
```

Create the remaining specialist agent files as empty stubs - fill them in as you build out the workflow:

```powershell
$agents = @(
    "request_classifier_agent",
    "icp_analyst_agent",
    "competitor_analyst_agent",
    "market_trends_agent",
    "product_opportunity_agent",
    "pricing_packaging_agent",
    "evidence_reviewer_agent",
    "risk_compliance_reviewer_agent",
    "strategy_synthesis_agent"
)
foreach ($a in $agents) {
    $path = "app\agents\admin_market_research\$a.py"
    if (-not (Test-Path $path)) {
        Set-Content $path "# TODO: implement $a"
    }
}
```

Workflow:

```text
AdminMarketResearchCoordinator
  -> RequestClassifierAgent
  -> ScopeAndPolicyAgent
  -> GoldenDocsRetrieverAgent
  -> ParallelResearchTeam
       - ICPAnalystAgent
       - CompetitorAnalystAgent
       - MarketTrendsAgent
       - ProductOpportunityAgent
       - PricingPackagingAgent
       - SalesMessagingAgent
  -> EvidenceAndCitationAgent
  -> RiskAndComplianceReviewerAgent
  -> StrategySynthesisAgent
  -> AdminDecisionBriefAgent
```

Decision brief shape:

```json
{
  "executive_summary": "...",
  "recommendation": "...",
  "evidence_used": [],
  "icp_impact": "...",
  "competitor_impact": "...",
  "product_opportunity": "...",
  "risks_and_assumptions": [],
  "suggested_next_actions": [],
  "confidence_level": "medium",
  "missing_data": []
}
```

Check:

```powershell
make test
```

Expected result: each specialist writes to its own key and the synthesis agent returns a structured brief.

Why: multi-agent fan-out lets each strategic lens run independently before synthesis.

### Learning: the coordinator's `_retrieve_context` is a placeholder, not real retrieval

Look closely at `_retrieve_context` in the coordinator above. It does `db.query(...).filter(status in golden/approved).limit(10)`. That returns the first ten chunks by insertion order, not the ten most relevant to the question. It ignores the query entirely. This is fine as a stub to get the API working, but it is not retrieval, and a brief built on irrelevant chunks will be confidently wrong. When you make `retrieval_service.py` real, layer these in roughly this order (depth in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13):

1. **Hybrid search (13.4).** Run vector similarity and keyword (BM25) search, then merge with Reciprocal Rank Fusion. Market research questions name exact competitors, SKUs, and pricing tiers that vector search alone misses.
2. **Reranking (13.7).** Pull the top 20 to 50 candidates, re-score them with a cross-encoder, keep the top 5. This is usually the biggest quality jump after hybrid search.
3. **Parent-document return (13.5).** Match on small precise chunks but hand the surrounding section to the synthesis agent so it has enough context.
4. **Contextual compression (13.6).** Before the Claude call in `generate_brief`, trim each retrieved chunk to the parts that answer the question. The coordinator currently joins whole chunks into the prompt; compress first to cut tokens and noise.
5. **Corrective retrieval (13.8).** Add a grading step after `GoldenDocsRetrieverAgent`. If the evidence is thin, rewrite the question and retrieve again, with a retry cap, before `StrategySynthesisAgent` runs. Keep every retry inside the approved-source boundary.

The `EvidenceAndCitationAgent` and the `evidence_used` field already point at grounding: keep answers tied to retrieved chunks and cite them (`reference/09` 12.6). Graph RAG (13.9) is a later upgrade for competitor and investor relationships, not a launch requirement. For cost, cache repeated queries and budget tokens per request (13.12, and `staging/20`).

## Step 7: Add Admin API

Create:

```text
app/api/v1/admin_market_research.py
app/services/admin_market_research_service.py
```

Endpoint:

```text
POST /api/v1/admin/market-research/briefs
GET /api/v1/admin/market-research/briefs
GET /api/v1/admin/market-research/briefs/{brief_id}
```

Request:

```json
{
  "question": "What GTM opportunity should we prioritize for clinics?",
  "focus_area": "gtm",
  "include_recent_sources": true
}
```

Response:

```json
{
  "brief_id": "uuid",
  "executive_summary": "...",
  "recommendation": "...",
  "evidence_used": [],
  "risks_and_assumptions": [],
  "suggested_next_actions": [],
  "confidence_level": "medium",
  "missing_data": []
}
```

Check:

```powershell
make test
```

Expected result: admin can request a market research brief and retrieve saved briefs.

Why: the frontend needs a stable API contract.

## Step 8: Add Admin Frontend Screens

Current repo:

```text
Skin_Lesion_Classification_frontend
```

Create:

```text
app/admin/market-research/page.tsx
app/admin/market-research/sources/page.tsx
app/admin/market-research/briefs/[briefId]/page.tsx
lib/adminMarketResearchApi.ts
```

UI sections:

```text
Golden Docs status
Source upload and review queue
Approved source library
Ask market research question
Generated decision brief
Evidence and citations
Risks and missing data
Promote brief insight to Golden Doc candidate
```

States:

```text
empty sources
uploading
source rejected
source approved
brief generating
brief failed
no evidence found
admin permission denied
```

Check:

```powershell
npm run type-check
npm run build
```

Expected result: admin market research screens compile.

Why: market intelligence belongs in admin UI, not patient, doctor, or public SEO pages.

## Step 9: Add Observability

Trace spans:

```text
llm.admin_market_research.classify_request
llm.admin_market_research.retrieve_context
llm.admin_market_research.parallel_agents
llm.admin_market_research.evidence_review
llm.admin_market_research.risk_review
llm.admin_market_research.synthesize
llm.admin_market_research.persist_brief
```

Never trace:

```text
raw uploaded documents
secrets
credentials
patient identifiers
patient notes
lab report text
raw private URLs
```

Check:

```powershell
make test
```

Expected result: trace payload tests show only safe metadata, source IDs, statuses, timings, and counts.

Why: strategy observability is useful, but it must not become a data leak.

## Step 10: Stop Point

Stop before adding live web browsing.

Live browsing can be added later behind:

```text
admin-only toggle
source citation requirement
rate limit
approval workflow
clear public-source-only rule
```

Check:

```powershell
make backend-test
make frontend-build
make docs-check
```

Expected result: admin market research RAG is documented, role-gated, and separated from clinical workflows.
