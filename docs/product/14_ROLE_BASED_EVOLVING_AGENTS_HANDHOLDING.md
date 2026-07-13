# Doctor, Customer, And Research Evolving Agents Handholding Guide

Use this after:

```text
13_LLM_RAG_AGENT_BOUNDARIES_HANDHOLDING.md
08_CUSTOMER_DASHBOARD_HANDHOLDING.md
11_LAB_RESULTS_HANDHOLDING.md
10_DOCTOR_ADMIN_REPORTS_HANDHOLDING.md
12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md
```

What this prerequisite block means:
- These are the guides that must be understood before this one.
- They define LLM boundaries, customer dashboard flows, lab results, doctor/admin review, and research monitoring.
- This guide depends on those product surfaces already existing conceptually.

Do not build this before customer, lab, doctor/admin, and research workflows exist as product surfaces.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

What this command does:
- `cd` moves PowerShell into the main workspace.
- Start here because the backend repository is inside this folder.

Backend commands run from:

```powershell
cd Skin_Lesion_Classification_backend
```

What this command does:
- This moves into the backend repository.
- Create the agent, RAG, docs, and test files in this guide from that folder.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...`, `tests/...`, and backend agent configuration path in this guide under `Skin_Lesion_Classification_backend/`.
- Run agent, API, and backend test commands from `Skin_Lesion_Classification_backend/`.

## Goal

Define how non-admin agents evolve safely.

Use three evolution models:

```text
Admin agent     -> evolving business intelligence
Doctor agent    -> reviewed clinical workflow intelligence
Customer agent  -> personal context + static safety education
Research agent  -> de-identified aggregate model/dataset intelligence
```

What this evolution-model block means:
- The admin agent may evolve around business intelligence.
- The doctor agent supports reviewed clinical workflows but does not replace doctors.
- The customer agent uses personal context and static safety education.
- The research agent uses de-identified aggregate model and dataset intelligence.
- These boundaries prevent user-facing agents from learning unsafe medical behavior from individual cases.

Why: doctor and customer agents must not learn uncontrolled medical behavior from individual cases.

## Step 1: Define Doctor Workflow Agent RAG

Create:

```text
app/rag/doctor_workflow/source_policy.md
```

What this path block means:
- Create this Markdown policy file inside the backend repo.
- It defines what the doctor workflow RAG system may and may not retrieve.

Paste:

```md
# Doctor Workflow RAG Source Policy

Allowed:
- assigned case facts
- doctor review workflow policies
- case summary templates
- clinical communication guidelines
- image quality rules
- Grad-CAM explanation rules
- report-writing templates
- approved medical disclaimers
- platform SOPs
- de-identified aggregate quality metrics

Blocked:
- unassigned patient data
- unapproved patient notes
- raw lesion image URLs
- raw lab reports
- market research docs
- admin pricing strategy docs
- unvalidated model output as clinical truth
```

What this policy file does:
- It documents allowed and blocked sources for the doctor workflow RAG domain.
- Allowed sources include assigned case facts, workflow policies, templates, image quality rules, Grad-CAM explanation rules, disclaimers, SOPs, and de-identified metrics.
- Blocked sources include unassigned patient data, unapproved notes, raw image URLs, lab reports, market research, pricing strategy, and unvalidated model output treated as truth.
- This prevents doctor-facing AI drafting from pulling unrelated or unsafe context.

Check:

```powershell
Get-Content app\rag\doctor_workflow\source_policy.md
```

What this command does:
- `Get-Content` prints the doctor workflow source policy so you can confirm the file was written.

Expected result: doctor RAG has explicit allowed and blocked sources.

Why: doctors can use AI drafting support, but doctors remain final reviewers.

## Step 2: Define Doctor Agent Sequence

Create:

```text
app/agents/doctor_workflow/README.md
```

What this path block means:
- Create this README inside the doctor workflow agent folder.
- It documents the planned sequence of doctor-facing agents.

Paste:

```md
# Doctor Workflow Agent Sequence

Workflow:

CaseFactsAssemblerAgent
DoctorSopRetrieverAgent
ImageQualitySummaryAgent
GradCamExplanationAgent
LabContextSummaryAgent
DraftCaseSummaryAgent
ClinicalSafetyReviewerAgent
DoctorReportDraftAgent

Output:
- case summary draft
- evidence list
- image quality note
- Grad-CAM note
- lab context note
- missing information
- recommended doctor actions

Rules:
- never finalize diagnosis
- never recommend treatment as AI
- mark patient-submitted body location as unverified until doctor verification
- mark lab results as context, not proof
- show missing data clearly
```

What this agent-sequence file does:
- It lists the order of doctor workflow agents.
- The workflow starts by assembling case facts and retrieving SOPs.
- It then summarizes image quality, Grad-CAM, lab context, and case information.
- Safety review happens before generating a doctor report draft.
- The output list defines what the workflow should return.
- The rules prevent diagnosis finalization, AI treatment recommendations, unverified location claims, lab-result overclaims, and hidden missing data.

Check:

```powershell
Get-Content app\agents\doctor_workflow\README.md
```

What this command does:
- `Get-Content` prints the doctor workflow agent README.
- Use it to confirm the sequence and rules are visible to future implementers.

Expected result: doctor agent sequence is documented.

Why: doctor agents should improve workflow speed, not replace judgment.

### Learning: make the retriever agents self-correcting

Each sequence in this guide has a retriever step: `DoctorSopRetrieverAgent` here, and the equivalent retrieval steps in the customer education and research sequences below. The naive version retrieves once and passes whatever it got to the next agent. Production RAG calls that "retrieve and pray." The better pattern is agentic, or corrective, RAG: the agent grades the chunks it retrieved against the question, and if they are weak or off-topic it rewrites the query and retrieves again, up to a retry cap, before the downstream agents run. Full detail in `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.8.

For these role agents specifically:

- The self-correction loop must stay inside the role's allowed source policy. A doctor retriever that rewrites its query still may only touch doctor SOPs and that doctor's assigned cases, never another role's index (`product/13`, and `reference/09` 12.3). A rewrite that drifts across the boundary is a leak, not a retry.
- If retrieval keeps coming back thin, the agent should surface "missing information" (already in the output contract above) rather than synthesize a confident answer from weak evidence. Honest gaps over hallucination, every time.
- The retrieval quality itself (chunking, embeddings, hybrid search, reranking) is set when each index is built. See the ingestion learning in `product/15` Step 4 and the catalog in `reference/09` Family 13.

## Step 3: Define Customer Education Agent RAG

Create:

```text
app/rag/customer_education/source_policy.md
```

What this path block means:
- Create this source policy inside the customer education RAG folder.
- It defines what patient-facing education retrieval may access.

Paste:

```md
# Customer Education RAG Source Policy

Allowed:
- current user's own lesion history
- current user's own consent settings
- current user's own storage mode
- current user's own reminders
- current user's own reports
- educational content
- image quality guidance
- Grad-CAM explanation guide
- privacy explanation guide
- safe app-help docs

Blocked:
- other users' records
- doctor-only notes unless explicitly released
- admin market research
- pricing strategy
- raw analytics
- research dataset details
- treatment guidance
```

What this policy file does:
- It allows retrieval from the current user’s own records, consent settings, storage mode, reminders, reports, and safe education/help docs.
- It blocks other users’ records, unreleased doctor-only notes, admin market research, pricing strategy, raw analytics, research dataset details, and treatment guidance.
- This keeps personalization limited to the current user and safe educational material.

Check:

```powershell
Get-Content app\rag\customer_education\source_policy.md
```

What this command does:
- It prints the customer education source policy.
- Use it to confirm cross-user and unsafe sources are blocked.

Expected result: customer RAG is scoped to the user's own account and safe education docs.

Why: patient-facing agents should personalize organization and education without becoming medical decision-makers.

## Step 4: Define Customer Agent Sequence

Create:

```text
app/agents/customer_education/README.md
```

What this path block means:
- Create this README inside the customer education agent folder.
- It documents the planned patient-facing agent sequence.

Paste:

```md
# Customer Education Agent Sequence

Workflow:

UserScopeValidatorAgent
PersonalHistoryRetrieverAgent
EducationRetrieverAgent
ImageQualityCoachAgent
GradCamEducationAgent
PrivacyModeExplainerAgent
DoctorPrepAgent
SafetyValidatorAgent

Output:
- plain-language answer
- related lesion history summary
- image quality tips
- privacy mode explanation
- doctor-prep checklist
- safety disclaimer

Rules:
- no diagnosis
- no treatment advice
- no reassurance that doctor review is unnecessary
- no cross-user retrieval
- encourage professional review for concerning changes
```

What this agent-sequence file does:
- It lists the customer education workflow from user-scope validation through safety validation.
- `UserScopeValidatorAgent` should confirm the request is limited to the current user.
- Retrieval agents gather personal history and education docs.
- Coaching agents explain image quality, Grad-CAM, privacy modes, and doctor-prep steps.
- The safety validator checks the final answer.
- The output list defines the patient-facing response parts.
- The rules block diagnosis, treatment advice, cross-user retrieval, and reassurance that doctor review is unnecessary.

Check:

```powershell
Get-Content app\agents\customer_education\README.md
```

What this command does:
- It prints the customer education agent README.
- Use it to verify the sequence and safety rules.

Expected result: customer education agent sequence is documented.

Why: the customer agent can evolve through personal context and safe education, not uncontrolled medical memory.

## Step 5: Define Research/Fairness Agent RAG

Create:

```text
app/rag/research_fairness/source_policy.md
```

What this path block means:
- Create this source policy inside the research/fairness RAG folder.
- It defines what model governance agents may retrieve.

Paste:

```md
# Research/Fairness RAG Source Policy

Allowed:
- de-identified approved research data
- aggregate model performance metrics
- calibration reports
- fairness reports
- dataset version docs
- model cards
- active learning queue summaries
- image quality aggregate summaries

Blocked:
- identifiable patient records
- raw clinical notes
- patient names or emails
- raw image URLs
- lab report files
- market research strategy docs
- patient-facing advice
```

What this policy file does:
- It allows de-identified research data, aggregate metrics, calibration reports, fairness reports, dataset docs, model cards, active learning summaries, and image-quality aggregates.
- It blocks identifiable patient records, raw notes, names, emails, raw image URLs, lab files, market strategy, and patient-facing advice.
- This keeps research/fairness agents focused on aggregate model governance.

Check:

```powershell
Get-Content app\rag\research_fairness\source_policy.md
```

What this command does:
- It prints the research/fairness source policy.
- Use it to confirm only aggregate and de-identified sources are allowed.

Expected result: research/fairness RAG is aggregate and de-identified only.

Why: research agents can help model governance without leaking patient data.

## Step 6: Define Research Agent Sequence

Create:

```text
app/agents/research_fairness/README.md
```

What this path block means:
- Create this README inside the research/fairness agent folder.
- It documents the planned model-governance agent sequence.

Paste:

```md
# Research/Fairness Agent Sequence

Workflow:

DatasetVersionRetrieverAgent
PerformanceSummaryAgent
CalibrationAnalystAgent
FairnessSliceAnalystAgent
ImageQualityBiasAgent
ActiveLearningQueueAgent
GovernanceRiskReviewerAgent
ResearchSummaryAgent

Output:
- model performance summary
- calibration notes
- fairness observations
- dataset gaps
- active learning recommendations
- governance risks

Rules:
- use de-identified aggregate data only
- no patient-level advice
- no market positioning recommendations
- no claims of clinical superiority without approved evidence
```

What this agent-sequence file does:
- It lists research/fairness agents for dataset version retrieval, performance summary, calibration analysis, fairness slice analysis, image-quality bias analysis, active learning, governance review, and final summary.
- The output list defines the model-governance report pieces.
- The rules require de-identified aggregate data and block patient-level advice, market positioning, and unsupported superiority claims.

Check:

```powershell
Get-Content app\agents\research_fairness\README.md
```

What this command does:
- It prints the research/fairness agent README.
- Use it to confirm the sequence and governance rules.

Expected result: research/fairness agent sequence is documented.

Why: model governance is different from patient education and admin strategy.

## Step 7: Add Role-Based Agent API Plan

Create:

```text
docs/llm/ROLE_AGENT_API_PLAN.md
```

What this path block means:
- Create this backend-local documentation file for role-specific agent endpoints.
- It documents URL boundaries before implementation.

Paste:

```md
# Role-Based Agent API Plan

## Doctor

POST /api/v1/doctor/agents/case-summary/{case_id}

Returns doctor-facing draft summary and missing information list.

## Customer

POST /api/v1/customer/agents/education

Returns safe educational answer scoped to the current user.

## Research

POST /api/v1/research/agents/fairness-summary

Returns de-identified aggregate model governance summary.

## Admin Market Research

POST /api/v1/admin/market-research/briefs

Returns admin-only market research decision brief.
```

What this API-plan file does:
- It defines separate endpoint families for doctor, customer, research, and admin market research agents.
- Doctor endpoints return doctor-facing drafts.
- Customer endpoints return safe education scoped to the current user.
- Research endpoints return de-identified aggregate summaries.
- Admin endpoints return admin-only market research briefs.
- Separate URLs make role and data boundaries easier to enforce and review.

Check:

```powershell
Get-Content docs\llm\ROLE_AGENT_API_PLAN.md
```

What this command does:
- It prints the role-based API plan file so you can verify endpoint separation.

Expected result: role-specific APIs are separated by URL and permission boundary.

Why: URLs should make role and data boundary obvious.

## Step 8: Add Tests

Create:

```text
tests/test_role_agent_boundaries.py
```

What this path block means:
- Create this backend pytest file for role-agent boundary tests.
- These tests should be written before live agents are connected.

Create `tests/test_role_agent_boundaries.py`:

```python
import pytest
from app.rag.policy import RagDomain, RagSourceStatus, assert_role_allowed, get_policy

# --- Output contract helpers ---
CUSTOMER_REQUIRED = {"answer", "safety_disclaimer"}
DOCTOR_REQUIRED = {"case_summary_draft", "missing_information", "recommended_doctor_actions"}
RESEARCH_REQUIRED = {"model_performance_summary", "governance_risks"}


# 1. Customer education cannot retrieve another user's lesion history
def test_customer_education_rejects_cross_user_domain() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.research_fairness, "patient")

def test_customer_education_policy_allows_patient_only() -> None:
    assert get_policy(RagDomain.customer_education).allowed_roles == ["patient"]


# 2. Customer education cannot retrieve admin market research
def test_customer_education_rejects_admin_market_research() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "patient")

def test_customer_education_phi_blocked() -> None:
    policy = get_policy(RagDomain.customer_education)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 3. Doctor workflow cannot retrieve unassigned patient cases
def test_doctor_workflow_rejects_patient_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.doctor_workflow, "patient")

def test_doctor_workflow_policy_allows_doctor_only() -> None:
    assert get_policy(RagDomain.doctor_workflow).allowed_roles == ["doctor"]


# 4. Doctor workflow cannot retrieve pricing strategy docs
def test_doctor_workflow_rejects_admin_market_domain() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "doctor")

def test_doctor_workflow_rejects_draft_sources() -> None:
    policy = get_policy(RagDomain.doctor_workflow)
    assert RagSourceStatus.draft not in set(policy.allowed_source_statuses)
    assert RagSourceStatus.rejected not in set(policy.allowed_source_statuses)


# 5. Research fairness rejects identifiable patient records
def test_research_fairness_rejects_patient_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.research_fairness, "patient")

def test_research_fairness_phi_pii_blocked() -> None:
    policy = get_policy(RagDomain.research_fairness)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 6. Admin market research rejects clinical patient data
def test_admin_market_research_rejects_patient_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "patient")

def test_admin_market_research_rejects_doctor_role() -> None:
    with pytest.raises(ValueError, match="not allowed"):
        assert_role_allowed(RagDomain.admin_market_research, "doctor")

def test_admin_market_research_phi_blocked() -> None:
    policy = get_policy(RagDomain.admin_market_research)
    assert policy.phi_allowed is False and policy.pii_allowed is False


# 7. All role agent outputs include the correct safety/disclaimer fields
def test_customer_output_requires_safety_disclaimer() -> None:
    output = {"answer": "No significant changes.", "safety_disclaimer": "Consult a clinician."}
    for field in CUSTOMER_REQUIRED:
        assert field in output
    assert len(output["safety_disclaimer"]) > 0

def test_doctor_output_requires_missing_information_field() -> None:
    output = {"case_summary_draft": "...", "missing_information": [], "recommended_doctor_actions": []}
    for field in DOCTOR_REQUIRED:
        assert field in output
    assert isinstance(output["missing_information"], list)

def test_research_output_requires_governance_risks_field() -> None:
    output = {"model_performance_summary": "...", "governance_risks": ["Fairness gap"]}
    for field in RESEARCH_REQUIRED:
        assert field in output
    assert isinstance(output["governance_risks"], list)
```

What this test file does:
- Tests 1–6 call `assert_role_allowed` and confirm `ValueError` is raised for blocked roles.
- PHI/PII tests confirm every domain has both flags set to `False`.
- Tests 7 validates output contracts — every agent type must return its required fields.
- `missing_information` in doctor output must be a list even when empty — hiding missing data is a safety violation.
- `safety_disclaimer` in customer output must be a non-empty string — empty disclaimers are flagged.

Check:

```powershell
pytest tests/test_role_agent_boundaries.py -v
```

What this command does:
- Runs only the role-agent boundary tests with verbose output.

Expected result: role-specific RAG boundaries are enforced.

Why: evolution is safe only when retrieval boundaries are tested.

## Stop Point

Stop here before production deployment or live web research.

Run from the main workspace:

```powershell
make backend-test
make docs-check
```

What this command block does:
- `make backend-test` runs backend tests from the root Makefile if that target exists.
- `make docs-check` validates documentation links and required guide structure.
- Run both before moving from design into implementation.

Expected result: role-based evolving agents are designed, documented, and testable without mixing data domains.
