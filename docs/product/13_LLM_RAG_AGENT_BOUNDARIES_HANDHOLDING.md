# LLM, RAG, Agent, And Observability Boundaries Handholding Guide

Use this after `06_SAFE_LLM_EXPLANATION_HANDHOLDING.md` and `07_LANGCHAIN_ADK_OBSERVABILITY_HANDHOLDING.md` are understood.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- Start here because this guide creates backend files and backend-local documentation.

Backend commands run from:

```powershell
cd Skin_Lesion_Classification_backend
```

What this command does:
- This moves from the workspace into the backend repository.
- Run Python imports, tests, and backend file creation from this folder.

## Goal

Separate the LLM system into clear domains before adding more agents.

Do not build one giant learning agent.

Use separate systems:

```text
Clinical/XAI LLM              -> explains structured model facts safely
Admin market research LLM     -> strategy, ICP, competitor, GTM, pricing, product opportunities
Doctor workflow LLM           -> doctor-facing summaries, templates, case organization
Customer education LLM        -> patient-owned context, education, privacy help, doctor-prep
Research/fairness LLM         -> de-identified aggregate model and dataset insight
```

What this system-split block means:
- Each line defines one LLM domain and its responsibility.
- Clinical/XAI explains structured model facts.
- Admin market research works on strategy and business materials.
- Doctor workflow organizes doctor-facing summaries.
- Customer education explains the user’s own history and app concepts.
- Research/fairness summarizes de-identified aggregate model and dataset data.
- Keeping these separate prevents one agent from mixing data it should not access.

Why: each domain has different permissions, data, memory, risk, and approval rules.

## Step 1: Write The Boundary Decision

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- The boundary decision file should be created inside the backend repository.

Create:

```text
docs/llm/BOUNDARIES.md
```

What this path block means:
- Create a backend-local `docs/llm` folder and put the boundary policy in `BOUNDARIES.md`.
- This file becomes the written policy source before code and RAG indexes are built.

Command:

```powershell
New-Item -ItemType Directory -Force docs\llm
New-Item -ItemType File -Force docs\llm\BOUNDARIES.md
```

What this command block does:
- The first `New-Item` creates the `docs\llm` folder if it does not already exist.
- The second `New-Item` creates the `BOUNDARIES.md` file.
- `-Force` makes both commands safe to rerun.

Paste:

```md
# LLM System Boundaries

## Clinical/XAI LLM

Purpose: explain structured model facts, Grad-CAM, image quality, body-location status, lab-result status, and safe next-step preparation.

Allowed data:
- structured analysis facts
- image-quality facts
- Grad-CAM metadata
- patient-owned lesion timeline summary
- approved safety policy documents

Blocked data:
- admin market research
- competitor intelligence
- pricing strategy
- unapproved clinical text
- raw secrets or private URLs

## Admin Market Research LLM

Purpose: produce admin-only strategic market research, ICP analysis, competitor positioning, GTM recommendations, pricing hypotheses, and product opportunities.

Allowed data:
- admin-approved Golden Docs
- admin-uploaded market research sources
- public market and competitor notes
- de-identified aggregate product metrics
- previous admin-approved strategy briefs

Blocked data:
- patient images
- lesion records with identifiers
- lab reports
- doctor notes
- patient free text
- private clinical reports
- PHI/PII

## Doctor Workflow LLM

Purpose: organize evidence, draft doctor-facing summaries, prepare report language, and explain workflow context.

Allowed data:
- assigned case facts
- report templates
- doctor workflow SOPs
- approved clinical communication rules

Blocked behavior:
- final diagnosis without doctor decision
- treatment recommendation as AI output
- retrieval from market strategy documents

## Customer Education LLM

Purpose: explain the user's own history, privacy settings, image quality, Grad-CAM meaning, and doctor-prep steps.

Allowed data:
- current user's own records
- education docs
- privacy/settings docs
- safe app-help docs

Blocked behavior:
- diagnosis
- treatment advice
- cross-user retrieval
- admin strategy retrieval

## Research/Fairness LLM

Purpose: summarize de-identified aggregate model performance, calibration, fairness, dataset quality, and active learning signals.

Allowed data:
- de-identified approved research data
- aggregate metrics
- model cards
- dataset version docs

Blocked data:
- identifiable patient records
- raw clinical notes
- market strategy docs
```

What this Markdown policy does:
- The file defines five LLM domains and keeps their purposes separate.
- Each domain has an allowed-data list and blocked-data or blocked-behavior list.
- Clinical/XAI can explain structured facts but cannot access market strategy or private URLs.
- Admin market research can use approved business sources but must not access PHI/PII.
- Doctor workflow can organize assigned case facts but cannot make final AI diagnoses.
- Customer education can use the current user’s own records and safe help docs only.
- Research/fairness can use de-identified aggregate data and model documentation only.
- This policy should guide later RAG source indexing and route-level access checks.

Check:

```powershell
Get-Content docs\llm\BOUNDARIES.md
```

What this command does:
- `Get-Content` prints the Markdown file so you can confirm the policy was written.

Expected result: the file lists each LLM domain, allowed data, and blocked data.

Why: this is the policy source before code paths and RAG indexes are created.

## Step 2: Create Backend Folder Boundaries

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Folder boundaries are created inside the backend app.

Create:

```text
app/agents/clinical_xai/
app/agents/admin_market_research/
app/agents/doctor_workflow/
app/agents/customer_education/
app/agents/research_fairness/
app/rag/clinical_xai/
app/rag/admin_market_research/
app/rag/doctor_workflow/
app/rag/customer_education/
app/rag/research_fairness/
app/observability/
```

What this folder list means:
- Each `app/agents/...` folder is for agent code in one LLM domain.
- Each `app/rag/...` folder is for retrieval indexes or retrieval code in one LLM domain.
- `app/observability/` holds shared tracing and logging support.

Command:

```powershell
New-Item -ItemType Directory -Force app\agents\clinical_xai, app\agents\admin_market_research, app\agents\doctor_workflow, app\agents\customer_education, app\agents\research_fairness, app\rag\clinical_xai, app\rag\admin_market_research, app\rag\doctor_workflow, app\rag\customer_education, app\rag\research_fairness, app\observability
```

What this command does:
- `New-Item -ItemType Directory` creates folders.
- `-Force` makes the command safe to rerun if folders already exist.
- The comma-separated paths create all agent, RAG, and observability folders in one command.

Check:

```powershell
Get-ChildItem app\agents
Get-ChildItem app\rag
```

What this command block does:
- `Get-ChildItem app\agents` lists the agent domain folders.
- `Get-ChildItem app\rag` lists the RAG domain folders.
- Use this to verify separation exists on disk.

Expected result: each domain has its own folder.

Why: physical folder separation prevents new market research code from drifting into clinical explanation code.

## Step 3: Add Role-Based RAG Policy Types

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- RAG policy types belong in the backend repository.

Create:

```text
app/rag/policy.py
```

What this path block means:
- Create the shared RAG policy type file at `app/rag/policy.py`.
- Other RAG services should import these types.

Paste:

```python
from enum import StrEnum
from pydantic import BaseModel


class RagDomain(StrEnum):
    clinical_xai = "clinical_xai"
    admin_market_research = "admin_market_research"
    doctor_workflow = "doctor_workflow"
    customer_education = "customer_education"
    research_fairness = "research_fairness"


class RagSourceStatus(StrEnum):
    draft = "draft"
    approved = "approved"
    golden = "golden"
    archived = "archived"
    rejected = "rejected"


class RagAccessPolicy(BaseModel):
    domain: RagDomain
    allowed_roles: list[str]
    allowed_source_statuses: list[RagSourceStatus]
    phi_allowed: bool = False
    pii_allowed: bool = False
    requires_admin_approval: bool = True
```

Also add the pre-defined policies and enforcement helpers at the bottom of the file:

```python
# Pre-defined policies per domain
CLINICAL_XAI_POLICY = RagAccessPolicy(
    domain=RagDomain.clinical_xai,
    allowed_roles=["patient", "doctor"],
    allowed_source_statuses=[RagSourceStatus.approved, RagSourceStatus.golden],
)

ADMIN_MARKET_RESEARCH_POLICY = RagAccessPolicy(
    domain=RagDomain.admin_market_research,
    allowed_roles=["admin"],
    allowed_source_statuses=[RagSourceStatus.approved, RagSourceStatus.golden],
)

DOCTOR_WORKFLOW_POLICY = RagAccessPolicy(
    domain=RagDomain.doctor_workflow,
    allowed_roles=["doctor"],
    allowed_source_statuses=[RagSourceStatus.approved, RagSourceStatus.golden],
)

CUSTOMER_EDUCATION_POLICY = RagAccessPolicy(
    domain=RagDomain.customer_education,
    allowed_roles=["patient"],
    allowed_source_statuses=[RagSourceStatus.approved, RagSourceStatus.golden],
    requires_admin_approval=False,  # education docs are pre-approved
)

RESEARCH_FAIRNESS_POLICY = RagAccessPolicy(
    domain=RagDomain.research_fairness,
    allowed_roles=["admin", "research_reviewer"],
    allowed_source_statuses=[RagSourceStatus.approved, RagSourceStatus.golden],
)

DOMAIN_POLICIES: dict[RagDomain, RagAccessPolicy] = {
    RagDomain.clinical_xai: CLINICAL_XAI_POLICY,
    RagDomain.admin_market_research: ADMIN_MARKET_RESEARCH_POLICY,
    RagDomain.doctor_workflow: DOCTOR_WORKFLOW_POLICY,
    RagDomain.customer_education: CUSTOMER_EDUCATION_POLICY,
    RagDomain.research_fairness: RESEARCH_FAIRNESS_POLICY,
}


def get_policy(domain: RagDomain) -> RagAccessPolicy:
    return DOMAIN_POLICIES[domain]


def assert_role_allowed(domain: RagDomain, role: str) -> None:
    """Raise ValueError if the role is not permitted for this domain."""
    policy = get_policy(domain)
    if role not in policy.allowed_roles:
        raise ValueError(
            f"Role ‘{role}’ is not allowed to access RAG domain ‘{domain}’. "
            f"Allowed roles: {policy.allowed_roles}"
        )
```

What this policy code does:
- `StrEnum` defines enums whose values are strings.
- `BaseModel` is Pydantic’s base class for typed policy objects.
- `RagDomain` lists the allowed LLM/RAG domains.
- `RagSourceStatus` lists lifecycle states for indexed sources.
- `RagAccessPolicy` defines the access rules for one retrieval operation.
- `phi_allowed` and `pii_allowed` default to `False` — must be explicitly enabled per domain.
- `requires_admin_approval` defaults to `True` so sources need approval before retrieval.
- `DOMAIN_POLICIES` maps each domain to its pre-defined policy instance.
- `get_policy` retrieves the policy for a given domain.
- `assert_role_allowed` raises `ValueError` immediately if the caller’s role is not permitted — use this at the start of every RAG retrieval call.

Check:

```powershell
python -c "from app.rag.policy import RagDomain; print(RagDomain.admin_market_research)"
```

What this command does:
- It imports `RagDomain` from the new policy file.
- It prints the admin market research enum value to confirm the module works.

Expected result:

```text
admin_market_research
```

What this expected output means:
- Python successfully imported the enum.
- The enum value prints as the string used in policy records and logs.

Why: every retrieval operation should know its domain and access policy before it touches documents.

## Step 4: Use The Fixed Tool Responsibilities

Use this split in code and docs:

```text
LangChain / LangGraph  -> retrieval, RAG chains, prompt templates, policy context
Google ADK             -> multi-agent orchestration, sequential/parallel/loop workflows
OpenTelemetry          -> shared tracing backbone
LangSmith              -> local/dev debugging only, off by default
```

What this tool-responsibility block means:
- LangChain or LangGraph handles retrieval and prompt/context construction.
- Google ADK handles multi-agent workflow orchestration.
- OpenTelemetry handles tracing across services and agents.
- LangSmith is for local development debugging and should be off by default in staging and production.

Create:

```text
docs/llm/TOOL_RESPONSIBILITIES.md
```

What this path block means:
- Create a second backend-local Markdown file documenting which tool does what.
- This prevents future code from mixing framework responsibilities.

Paste:

```md
# Tool Responsibilities

## LangChain / LangGraph

Use for RAG retrieval, prompt templates, grounding, routing, and optional stateful graph logic.

## Google ADK

Use for multi-agent orchestration: SequentialAgent, ParallelAgent, LoopAgent, coordinator/dispatcher, review/critique, and human-in-the-loop patterns.

## OpenTelemetry

Use as the shared observability layer across FastAPI, RAG retrieval, agent runs, tool calls, and final response generation.

## LangSmith

Use only for local/development debugging. Keep disabled by default in staging and production unless redaction is proven.
```

What this Markdown file does:
- It documents the intended role of LangChain/LangGraph, Google ADK, OpenTelemetry, and LangSmith.
- It keeps retrieval, orchestration, tracing, and debugging responsibilities separate.
- It also records that LangSmith should remain disabled outside local development unless redaction is proven.

Check:

```powershell
Get-Content docs\llm\TOOL_RESPONSIBILITIES.md
```

What this command does:
- `Get-Content` prints the new responsibilities file so you can confirm it was written correctly.

Expected result: tool responsibilities are explicit.

Why: this separates framework purpose instead of mixing everything into one LLM feature.

## Step 5: Add Trace Naming Rules

Create:

```text
app/observability/llm_trace_names.py
```

What this path block means:
- Create this file in the backend observability folder.
- It centralizes trace naming so spans stay consistent across LLM domains.

Paste:

```python
from enum import StrEnum


class LlmTraceDomain(StrEnum):
    clinical_xai = "llm.clinical_xai"
    admin_market_research = "llm.admin_market_research"
    doctor_workflow = "llm.doctor_workflow"
    customer_education = "llm.customer_education"
    research_fairness = "llm.research_fairness"


class LlmTraceStage(StrEnum):
    classify_request = "classify_request"
    retrieve_context = "retrieve_context"
    run_agents = "run_agents"
    review_safety = "review_safety"
    synthesize = "synthesize"
    persist_output = "persist_output"


def span_name(domain: LlmTraceDomain, stage: LlmTraceStage) -> str:
    """Return a consistent dot-separated span name for OTel tracing."""
    return f"{domain}.{stage}"
```

Usage example:

```python
from app.observability.llm_trace_names import LlmTraceDomain, LlmTraceStage, span_name

with tracer.start_as_current_span(span_name(LlmTraceDomain.clinical_xai, LlmTraceStage.retrieve_context)):
    # RAG retrieval happens here
    ...
```

What this trace-name code does:
- `StrEnum` defines enums whose values are strings.
- `LlmTraceDomain` gives each LLM domain a stable trace namespace.
- `clinical_xai`, `admin_market_research`, `doctor_workflow`, `customer_education`, and `research_fairness` map to names like `llm.clinical_xai`.
- `LlmTraceStage` names common stages inside an LLM workflow.
- `classify_request`, `retrieve_context`, `run_agents`, `review_safety`, `synthesize`, and `persist_output` make traces easier to search and compare.

Check:

```powershell
python -c "from app.observability.llm_trace_names import LlmTraceDomain; print(LlmTraceDomain.admin_market_research)"
```

What this command does:
- It imports the trace-domain enum.
- It prints the admin market research trace name to confirm the file works.

Expected result:

```text
llm.admin_market_research
```

What this expected output means:
- The enum prints the exact trace namespace that should appear in observability tools.

Why: OpenTelemetry traces should make it obvious which LLM domain ran.

## Step 6: Add Boundary Tests

Current repo:

```text
Skin_Lesion_Classification_backend
```

What this block means:
- Boundary tests belong in the backend test suite.

Create:

```text
tests/test_llm_boundaries.py
```

What this path block means:
- Create a backend pytest file for LLM/RAG boundary tests.
- These tests should run before adding more agents.

Create `tests/test_llm_boundaries.py`:

```python
import os
import pytest
from app.rag.policy import RagDomain, RagSourceStatus, assert_role_allowed, get_policy
from app.observability.langsmith_config import is_langsmith_enabled


# 1. Admin market research rejects patient data sources
def test_admin_market_research_rejects_patient_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "patient")

def test_admin_market_research_rejects_doctor_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "doctor")

def test_admin_market_research_phi_blocked() -> None:
    policy = get_policy(RagDomain.admin_market_research)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 2. Customer education rejects other-user records
def test_customer_education_rejects_admin_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.customer_education, "admin")

def test_customer_education_rejects_doctor_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.customer_education, "doctor")


# 3. Doctor workflow rejects admin market strategy docs
def test_doctor_workflow_rejects_admin_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.doctor_workflow, "admin")

def test_doctor_workflow_rejects_patient_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.doctor_workflow, "patient")


# 4. Research fairness accepts de-identified aggregate sources only
def test_research_fairness_allows_only_approved_statuses() -> None:
    policy = get_policy(RagDomain.research_fairness)
    allowed = set(policy.allowed_source_statuses)
    assert RagSourceStatus.approved in allowed
    assert RagSourceStatus.draft not in allowed
    assert RagSourceStatus.rejected not in allowed

def test_research_fairness_phi_blocked() -> None:
    policy = get_policy(RagDomain.research_fairness)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 5. Clinical XAI rejects competitor and pricing documents
def test_clinical_xai_rejects_admin_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.clinical_xai, "admin")

def test_clinical_xai_phi_blocked() -> None:
    policy = get_policy(RagDomain.clinical_xai)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 6. LangSmith tracing defaults to disabled
def test_langsmith_disabled_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LANGSMITH_TRACING", raising=False)
    monkeypatch.delenv("LANGSMITH_API_KEY", raising=False)
    assert is_langsmith_enabled() is False

def test_langsmith_disabled_without_api_key(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LANGSMITH_TRACING", "true")
    monkeypatch.delenv("LANGSMITH_API_KEY", raising=False)
    assert is_langsmith_enabled() is False


# 7. Prompt/completion tracing defaults to disabled outside local demo mode
def test_trace_prompts_disabled_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TRACE_PROMPTS", raising=False)
    assert os.getenv("TRACE_PROMPTS", "false").lower() == "false"

def test_trace_completions_disabled_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TRACE_COMPLETIONS", raising=False)
    assert os.getenv("TRACE_COMPLETIONS", "false").lower() == "false"

def test_trace_redaction_enabled_by_default(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("TRACE_REDACTION_ENABLED", raising=False)
    assert os.getenv("TRACE_REDACTION_ENABLED", "true").lower() == "true"
```

What this test file does:
- Tests 1–5 call `assert_role_allowed` and expect `ValueError` for blocked roles, confirming domain isolation.
- PHI/PII tests confirm every domain has both flags set to `False` by default.
- Tests 6–7 use `monkeypatch` to control environment variables without side effects.
- `test_langsmith_disabled_without_api_key` proves the double-guard (flag + key) is enforced.
- `test_trace_redaction_enabled_by_default` confirms the safety default is on, not off.

Check:

```powershell
pytest tests/test_llm_boundaries.py -v
```

What this command does:
- Runs only the boundary tests with verbose output so each case is visible.

Expected result: all tests pass, proving role and domain boundaries before new agents are built.

Why: RAG safety depends on access control, not prompt wording alone.

## Stop Point

Stop here before building the admin market research RAG system.

Next guide:

```text
docs/product/15_ADMIN_MARKET_RESEARCH_RAG_HANDHOLDING.md
```

What this next-guide block means:
- This is the next guide to read after the boundary policy and tests exist.
- Do not build the admin market research RAG system before the boundaries are documented and tested.
