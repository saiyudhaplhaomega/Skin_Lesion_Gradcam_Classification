# LangChain, Google ADK, and Observability Handholding Guide

Use this after `06_SAFE_LLM_EXPLANATION_HANDHOLDING.md` works.

This guide explains how LangChain handles RAG and policy grounding, how Google ADK handles multi-agent XAI orchestration, and how OpenTelemetry connects all traces with privacy-safe observability.

## Architecture Overview

```
POST /api/v1/explain-llm/{analysis_id}
        ↓ FastAPI request trace starts
        ↓ Load AnalysisEvent
        ↓ Build structured facts
        ↓ LangChain / LangGraph RAG chain
          - retrieve safety policy
          - retrieve medical disclaimer rules
          - retrieve explanation templates
          - retrieve app-specific XAI guidance
        ↓ Google ADK XAI agent workflow
          - PredictionExplainerAgent
          - GradCamExplainerAgent
          - ImageQualityExplanationAgent
          - RiskCommunicationAgent
          - SynthesisAgent
          - SafetyValidatorAgent
        ↓ Final safe explanation JSON
        ↓ Persist explanation
        ↓ Return response to frontend
```

What this architecture block means:
- The request starts when the frontend calls `POST /api/v1/explain-llm/{analysis_id}`.
- FastAPI starts a trace so the backend can follow the request through each major step.
- The backend loads the saved analysis event and builds structured facts instead of letting an LLM inspect raw images.
- LangChain or LangGraph retrieves safety policy, disclaimer rules, explanation templates, and XAI guidance.
- Google ADK coordinates specialist agents for prediction wording, Grad-CAM wording, image quality, risk communication, synthesis, and safety validation.
- The final output is structured JSON, then it is saved for audit and returned to the frontend.

## Command Location

Start from the main workspace:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

What this command block does:
- The first `cd` moves into the main project workspace.
- The second `cd` moves into the backend repository, where the Python app, tests, and environment file live.
- All backend file paths in this guide are relative to `Skin_Lesion_Classification_backend`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit every `app/...`, `tests/...`, and backend config path in this guide under `Skin_Lesion_Classification_backend/`.
- Run LangChain, ADK, tracing, and backend test commands from `Skin_Lesion_Classification_backend/` unless a step explicitly names another directory.

## Responsibilities

```text
LangChain / LangGraph  →  retrieval, grounding, prompt templates, policy context
Google ADK             →  multi-agent orchestration, sequential/parallel/loop workflows
OpenTelemetry          →  shared tracing backbone across all components
LangSmith             →  development debugging only, strict redaction in staging/prod
```

What this responsibilities block means:
- LangChain or LangGraph handles retrieval, grounding, and prompt context.
- Google ADK handles multi-agent orchestration and workflow order.
- OpenTelemetry provides the shared tracing standard across components.
- LangSmith is useful during development, but staging and production must use strict redaction.

## Step 1: Add Backend Module Structure

Create these directories:

```text
app/services/
app/agents/prompts/
app/observability/
```

What this directory block does:
- `app/services/` stores reusable backend service classes.
- `app/agents/prompts/` stores prompt templates used by the LLM and agent workflow.
- `app/observability/` stores tracing, redaction, and telemetry setup code.

Then create these files:

```text
app/services/langchain_policy_rag_service.py
app/services/adk_xai_orchestrator_service.py
app/services/llm_safety_validator_service.py
app/services/observability_service.py
app/agents/xai_workflow.py
app/agents/prediction_explainer_agent.py
app/agents/gradcam_explainer_agent.py
app/agents/image_quality_agent.py
app/agents/risk_communication_agent.py
app/agents/synthesis_agent.py
app/agents/safety_validator_agent.py
app/observability/tracing.py
app/observability/redaction.py
app/observability/otel_config.py
app/observability/langsmith_config.py
app/agents/prompts/prediction_explainer.md
app/agents/prompts/gradcam_explainer.md
app/agents/prompts/image_quality_explainer.md
app/agents/prompts/risk_communication.md
app/agents/prompts/synthesis.md
app/agents/prompts/safety_validator.md
```

What this file list means:
- The `app/services/...` files hold orchestration, RAG, safety, and observability service code.
- The `app/agents/...` files separate each agent responsibility into a named module.
- The `app/observability/...` files keep tracing logic separate from clinical explanation logic.
- The `app/agents/prompts/...` files keep prompt text editable without changing Python code.

Fill the agent placeholder files with the exact agent name and prompt path so they are not empty files.

Create `app/agents/xai_workflow.py`:

```python
WORKFLOW_STEPS = [
    "prediction_explainer_agent",
    "gradcam_explainer_agent",
    "image_quality_agent",
    "risk_communication_agent",
    "synthesis_agent",
    "safety_validator_agent",
]
```

Create `app/agents/prediction_explainer_agent.py`:

```python
AGENT_NAME = "PredictionExplainerAgent"
PROMPT_PATH = "app/agents/prompts/prediction_explainer.md"
```

Create `app/agents/gradcam_explainer_agent.py`:

```python
AGENT_NAME = "GradCamExplainerAgent"
PROMPT_PATH = "app/agents/prompts/gradcam_explainer.md"
```

Create `app/agents/image_quality_agent.py`:

```python
AGENT_NAME = "ImageQualityExplanationAgent"
PROMPT_PATH = "app/agents/prompts/image_quality_explainer.md"
```

Create `app/agents/risk_communication_agent.py`:

```python
AGENT_NAME = "RiskCommunicationAgent"
PROMPT_PATH = "app/agents/prompts/risk_communication.md"
```

Create `app/agents/synthesis_agent.py`:

```python
AGENT_NAME = "SynthesisAgent"
PROMPT_PATH = "app/agents/prompts/synthesis.md"
```

Create `app/agents/safety_validator_agent.py`:

```python
AGENT_NAME = "SafetyValidatorAgent"
PROMPT_PATH = "app/agents/prompts/safety_validator.md"
```

Fill the prompt files that were not already created in guide 06.

Create `app/agents/prompts/gradcam_explainer.md`:

```markdown
Explain Grad-CAM as model attention, not proof of disease.

Use only the structured facts provided by the backend.
Mention whether a heatmap is available and which regions were highlighted.
Do not say the highlighted area confirms cancer, melanoma, malignancy, or any diagnosis.
Close by reminding the user that a clinician should interpret the image.
```

Create `app/agents/prompts/image_quality_explainer.md`:

```markdown
Explain image quality limitations in plain language.

Use only blur, lighting, and glare values from structured facts.
If quality is acceptable, say that briefly.
If quality issues exist, explain that they may affect reliability and suggest retaking the image.
Do not diagnose or infer disease from image quality.
```

Create `app/agents/prompts/risk_communication.md`:

```markdown
Communicate risk cautiously and calmly.

Use phrases such as "the model flagged" or "professional review is recommended."
Do not say the patient has a disease.
Do not recommend treatment, medication, or surgery.
Always point the patient to a qualified clinician for interpretation.
```

Create `app/agents/prompts/synthesis.md`:

```markdown
Combine the prediction, Grad-CAM, image quality, body location, and lab-result notes into one safe explanation.

Keep the output educational and concise.
Do not introduce facts that are not present in the structured inputs.
Do not expose image URLs, storage keys, patient identifiers, or raw notes.
End with: "This is not a diagnosis. Please consult a qualified clinician."
```

## Step 2: Add Observability Config Variables

Update `Skin_Lesion_Classification_backend/.env.example`:

```env
# Observability
OBSERVABILITY_ENABLED=true
OTEL_ENABLED=true
OTEL_SERVICE_NAME=skin-lesion-backend
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317
OTEL_EXPORTER_OTLP_HEADERS=

# LangSmith (development only)
LANGSMITH_TRACING=false
LANGSMITH_API_KEY=
LANGSMITH_PROJECT=skin-lesion-xai-dev

# Tracing control
TRACE_PROMPTS=false
TRACE_COMPLETIONS=false
TRACE_REDACTION_ENABLED=true
TRACE_ENV=local
```

What this `.env.example` block does:
- `OBSERVABILITY_ENABLED` is the top-level feature flag for observability.
- `OTEL_ENABLED` controls OpenTelemetry specifically.
- `OTEL_SERVICE_NAME` names this backend in trace dashboards.
- `OTEL_EXPORTER_OTLP_ENDPOINT` points to the OpenTelemetry collector endpoint.
- `OTEL_EXPORTER_OTLP_HEADERS` is reserved for exporter authentication headers.
- `LANGSMITH_TRACING` controls LangSmith tracing and should stay off unless intentionally debugging.
- `LANGSMITH_API_KEY` is intentionally blank because real secrets must not be committed.
- `LANGSMITH_PROJECT` groups local traces under one project name.
- `TRACE_PROMPTS` and `TRACE_COMPLETIONS` decide whether prompts and model outputs can be traced.
- `TRACE_REDACTION_ENABLED` keeps redaction on by default.
- `TRACE_ENV` tells tracing code whether it is running locally, in staging, or in production.

For local dev with fake/demo data only:

```env
TRACE_PROMPTS=true
TRACE_COMPLETIONS=true
TRACE_ENV=local
```

What this local config means:
- Local fake/demo data can enable prompt and completion tracing because it should not contain real patient data.
- `TRACE_ENV=local` tells the tracing code this is a developer environment.
- Do not copy this exact setting to staging or production with real patient data.

For staging:

```env
TRACE_PROMPTS=false
TRACE_COMPLETIONS=false
TRACE_REDACTION_ENABLED=true
TRACE_ENV=staging
```

What this staging config means:
- Staging keeps prompt and completion tracing disabled because staging may use realistic workflows.
- Redaction remains enabled so metadata is cleaned before leaving the app.
- `TRACE_ENV=staging` lets the code apply stricter non-local tracing behavior.

For production:

```env
TRACE_PROMPTS=false
TRACE_COMPLETIONS=false
TRACE_REDACTION_ENABLED=true
TRACE_ENV=production
```

What this production config means:
- Production disables prompt and completion tracing by default.
- Redaction stays enabled because production can contain real patient data.
- `TRACE_ENV=production` makes the safest tracing behavior the normal production path.

Dependency note for this guide:

```text
No new package line is required in requirements.txt for this local scaffold.
```

What this dependency note means:
- This guide creates local placeholder services for policy retrieval, ADK-style orchestration, and observability wiring.
- The local implementation does not import `langchain_core`, `langchain_community`, or Google ADK packages yet because no real vector store or real ADK runner is wired in this step.
- OpenTelemetry API is already present through existing dependencies. The OTLP exporter package is optional here; the code below returns `None` cleanly when exporter packages are not installed.
- Add real LangChain, Google ADK, and OTLP exporter package pins only when a later guide replaces the placeholder services with real external integrations.

## Step 3: Add Redaction Helper

Create:

```text
app/observability/redaction.py
```

What this path block means:
- Create this file inside the backend repository.
- The file will contain helper code that removes sensitive values before trace data is sent anywhere.

Paste:

```python
import re
from typing import Any


class RedactionHelper:
    """Remove sensitive data before tracing."""

    EMAIL_PATTERN = re.compile(r'[\w.+-]+@[\w-]+\.[\w.-]+')
    PHONE_PATTERN = re.compile(r'\+?[\d\s()-]{10,}')
    URL_PATTERN = re.compile(r'https?://[^\s]+')
    S3_KEY_PATTERN = re.compile(r's3://[^\s]+')
    BASE64_PATTERN = re.compile(r'data:[^;]+;base64,[^\s]+')
    TOKEN_PATTERN = re.compile(r'(Bearer|Token|API)[-\s]+[^\s]+', re.IGNORECASE)

    def redact(self, payload: dict[str, Any]) -> dict[str, Any]:
        """
        Return a safe version of the payload for tracing.
        Never mutate the original clinical object.
        """
        result = {}
        for key, value in payload.items():
            if isinstance(value, str):
                result[key] = self._redact_string(value)
            elif isinstance(value, dict):
                result[key] = self.redact(value)
            elif isinstance(value, list):
                result[key] = [self.redact(item) if isinstance(item, dict) else self._redact_string(item) if isinstance(item, str) else item for item in value]
            else:
                result[key] = value
        return result

    def _redact_string(self, text: str) -> str:
        text = self.EMAIL_PATTERN.sub('[email_redacted]', text)
        text = self.PHONE_PATTERN.sub('[phone_redacted]', text)
        text = self.URL_PATTERN.sub('[url_redacted]', text)
        text = self.S3_KEY_PATTERN.sub('[s3_key_redacted]', text)
        text = self.BASE64_PATTERN.sub('[base64_redacted]', text)
        text = self.TOKEN_PATTERN.sub('[token_redacted]', text)
        if len(text) > 500:
            text = text[:500] + '... [truncated]'
        return text


redaction_helper = RedactionHelper()


def redact_trace_payload(payload: dict) -> dict:
    """Convenience wrapper for the module-level helper."""
    return redaction_helper.redact(payload)
```

What this code does:
- `import re` loads Python’s regular expression module, which finds sensitive patterns inside strings.
- `from typing import Any` allows payload values to be typed flexibly.
- `RedactionHelper` groups all redaction patterns and methods into one reusable class.
- The compiled patterns detect emails, phone numbers, URLs, S3 keys, base64 image data, and bearer/API tokens.
- `redact` accepts a dictionary and returns a new safe dictionary.
- The method does not mutate the original clinical object, so the rest of the app still has the original data.
- String values are passed to `_redact_string`.
- Nested dictionaries are redacted recursively.
- Lists are walked item by item so strings and nested dictionaries inside lists are also cleaned.
- `_redact_string` replaces sensitive matches with placeholders such as `[email_redacted]`.
- The length check truncates very long strings so accidental large notes or encoded images do not flood traces.
- `redaction_helper = RedactionHelper()` creates one shared helper instance.
- `redact_trace_payload` is a convenience function other modules can import directly.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.observability.redaction import redact_trace_payload; print(redact_trace_payload({'email': 'patient@example.com', 'url': 'https://s3.amazonaws.com/bucket/img.jpg'}))"
```

What this command does:
- `cd Skin_Lesion_Classification_backend` makes sure Python imports from the backend app.
- `python -c "..."` runs a short Python program directly from PowerShell.
- The import loads the redaction helper.
- The sample dictionary contains an email and URL that should be redacted.
- Printing the result lets you confirm the helper works before wiring it into tracing.

Expected result:

```text
{'email': '[email_redacted]', 'url': '[url_redacted]'}
```

What this expected output means:
- The email was replaced with `[email_redacted]`.
- The URL was replaced with `[url_redacted]`.
- This confirms sensitive values are removed before they are sent to logs or trace systems.

## Step 4: Add OpenTelemetry Config

Create:

```text
app/observability/otel_config.py
```

What this path block means:
- Create this file in the backend app.
- It will contain the setup code that connects the backend to OpenTelemetry tracing.

Paste:

```python
import os

from opentelemetry import trace
from opentelemetry.trace import Tracer

try:
    from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor
except ModuleNotFoundError:
    OTLPSpanExporter = None
    Resource = None
    TracerProvider = None
    BatchSpanProcessor = None


def setup_otel(service_name: str = "skin-lesion-backend") -> Tracer | None:
    """Initialize OpenTelemetry tracing."""
    if not os.getenv("OTEL_ENABLED", "false").lower() == "true":
        return None

    if not all([OTLPSpanExporter, Resource, TracerProvider, BatchSpanProcessor]):
        return None

    endpoint = os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317")

    resource = Resource.create({"service.name": service_name})

    provider = TracerProvider(resource=resource)

    try:
        exporter = OTLPSpanExporter(endpoint=endpoint, insecure=True)
        provider.add_span_processor(BatchSpanProcessor(exporter))
    except Exception:
        pass

    trace.set_tracer_provider(provider)

    return trace.get_tracer(service_name)


def get_tracer() -> Tracer:
    """Get or create the shared tracer."""
    return trace.get_tracer("skin-lesion-backend")
```

What this code does:
- `import os` reads environment variables.
- `from opentelemetry import trace` imports the global tracing API.
- `Tracer` is imported for return type hints.
- The `try/except ModuleNotFoundError` keeps local development working when the optional OTLP exporter package is not installed yet.
- `OTLPSpanExporter` sends spans to an OpenTelemetry collector using the OTLP protocol when the exporter package is available.
- `Resource` attaches service metadata such as the service name to traces.
- `TracerProvider` owns tracer configuration for this process.
- `BatchSpanProcessor` batches spans before exporting them, which is more efficient than sending each span immediately.
- `setup_otel` initializes tracing when `OTEL_ENABLED=true`.
- If OpenTelemetry is disabled, `setup_otel` returns `None` and the app can keep running normally.
- If the OTLP exporter dependencies are missing, `setup_otel` returns `None` and the app keeps running normally.
- `endpoint` reads `OTEL_EXPORTER_OTLP_ENDPOINT` and defaults to a local collector.
- `Resource.create({"service.name": service_name})` labels traces as coming from this backend.
- `OTLPSpanExporter(..., insecure=True)` creates the exporter for a local or internal collector.
- `provider.add_span_processor(BatchSpanProcessor(exporter))` connects the exporter to the provider.
- The `try/except` prevents observability setup errors from breaking the clinical API.
- `trace.set_tracer_provider(provider)` registers the provider globally.
- `get_tracer` returns a tracer named `skin-lesion-backend` for other modules to use.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.observability.otel_config import setup_otel; t = setup_otel(); print('OTel setup ok' if t else 'OTel disabled')"
```

What this command does:
- It imports `setup_otel`, calls it, and prints whether a tracer was created.
- If `OTEL_ENABLED` is not true, `setup_otel` returns `None`, so `OTel disabled` is expected.
- This verifies the module imports cleanly even before a collector is running.

## Step 5: Add LangSmith Config

Create:

```text
app/observability/langsmith_config.py
```

What this path block means:
- Create this file in the backend observability folder.
- It keeps LangSmith-specific configuration checks separate from OpenTelemetry code.

Paste:

```python
import os


def is_langsmith_enabled() -> bool:
    """Check if LangSmith tracing should be active."""
    if os.getenv("LANGSMITH_TRACING", "false").lower() != "true":
        return False
    if not os.getenv("LANGSMITH_API_KEY"):
        return False
    return True


def get_langsmith_project() -> str:
    """Get the LangSmith project name."""
    return os.getenv("LANGSMITH_PROJECT", "skin-lesion-xai-dev")
```

What this code does:
- `import os` reads environment variables.
- `is_langsmith_enabled` returns `False` unless `LANGSMITH_TRACING=true`.
- The API key check prevents LangSmith from being enabled without credentials.
- `get_langsmith_project` reads the project name from `LANGSMITH_PROJECT`.
- The default project name keeps local traces grouped even if the variable is missing.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.observability.langsmith_config import is_langsmith_enabled; print(is_langsmith_enabled())"
```

What this command does:
- It imports `is_langsmith_enabled` and prints the result.
- With no API key and default environment settings, the function should return `False`.

Expected result: `False` without API key.

## Step 6: Add Tracing Service

Create:

```text
app/observability/tracing.py
```

What this path block means:
- Create this file in the backend observability folder.
- This file becomes the shared tracing wrapper used by LangChain and ADK workflow code.

Paste:

```python
from opentelemetry import trace
from opentelemetry.trace import Span, Status, StatusCode
from contextlib import contextmanager
from typing import Iterator
import logging

from app.observability.otel_config import get_tracer
from app.observability.redaction import redact_trace_payload

logger = logging.getLogger(__name__)


class TracingService:
    """Shared tracing across LangChain and ADK."""

    def __init__(self) -> None:
        self._tracer = get_tracer()
        self._trace_env = "local"

    def init(self, trace_env: str = "local") -> None:
        self._trace_env = trace_env

    @contextmanager
    def span(self, name: str, attributes: dict | None = None) -> Iterator[Span]:
        """Create a traced span."""
        if self._tracer is None:
            yield None
            return

        with self._tracer.start_as_current_span(name) as span:
            if attributes:
                for key, value in attributes.items():
                    span.set_attribute(key, value)
            try:
                yield span
            except Exception as e:
                span.set_status(Status(StatusCode.ERROR, str(e)))
                raise

    def trace_event(self, name: str, payload: dict | None = None) -> None:
        """Log a trace event with optional redaction."""
        if payload is None:
            payload = {}
        if self._trace_env != "local":
            payload = redact_trace_payload(payload)
        logger.debug("trace_event: %s %s", name, payload)

    def get_current_trace_id(self) -> str | None:
        """Get the current trace ID for debugging."""
        span = trace.get_current_span()
        if span is None:
            return None
        ctx = span.get_span_context()
        if ctx.trace_id:
            return format(ctx.trace_id, "032x")
        return None


tracing_service = TracingService()
```

What this code does:
- `trace`, `Span`, `Status`, and `StatusCode` come from OpenTelemetry and are used to create spans and mark errors.
- `contextmanager` lets `span(...)` be used with Python’s `with` syntax.
- `Iterator` types the generator used by the context manager.
- `logging` creates a normal Python logger for trace events.
- `get_tracer` loads the app’s shared OpenTelemetry tracer.
- `redact_trace_payload` removes sensitive data before non-local trace events are logged.
- `logger = logging.getLogger(__name__)` names the logger after this module.
- `TracingService.__init__` stores a tracer and defaults the environment to `local`.
- `init` lets startup code change the trace environment to `staging` or `production`.
- `span` creates a named tracing span around a block of code.
- If tracing is unavailable, `span` yields `None` and lets the application continue.
- `span.set_attribute` attaches safe metadata such as triage level or agent name.
- If an exception happens inside the span, the span is marked as an error and the exception is re-raised.
- `trace_event` logs an event payload and redacts it outside local development.
- `get_current_trace_id` returns the current trace ID as a 32-character hex string for debugging.
- `tracing_service = TracingService()` creates one shared tracing object for the backend.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.observability.tracing import tracing_service; print(type(tracing_service))"
```

What this command does:
- It imports the shared `tracing_service` object.
- It prints the Python type so you can confirm the module loads and the object exists.

## Step 7: Add LangChain Policy RAG Service

Create:

```text
app/services/langchain_policy_rag_service.py
```

What this path block means:
- Create this file in the backend service layer.
- The file will hold the policy retrieval and grounding logic for explanation generation.

Paste:

```python
from typing import TypedDict


class PolicyContext(TypedDict):
    safety_policy: str
    medical_disclaimer: str
    explanation_template: str
    xai_guidance: str


class LangChainPolicyRAGService:
    """Use LangChain for policy retrieval and grounding."""

    def __init__(self) -> None:
        self._initialized = False

    def initialize(self) -> None:
        if self._initialized:
            return
        self._initialized = True

    async def retrieve_policy_context(self, triage_level: str, prediction_label: str) -> PolicyContext:
        """
        Retrieve relevant policy context for the given prediction.
        In a real implementation this would query a medical policy vector store.
        """
        return PolicyContext(
            safety_policy=(
                "Do not state a definitive diagnosis. "
                "Always recommend professional medical review. "
                "Do not provide treatment instructions."
            ),
            medical_disclaimer=(
                "This explanation is for informational purposes only "
                "and does not constitute a medical diagnosis."
            ),
            explanation_template="{prediction} with {confidence}% confidence. "
                                  "Please consult a qualified clinician for interpretation.",
            xai_guidance=(
                "Explain Grad-CAM as model attention visualization, not proof of pathology. "
                "Describe which regions influenced the model's output without claiming certainty."
            )
        )

    async def retrieve_safety_policy(self) -> str:
        return (
            "1. Do not diagnose directly. "
            "2. Recommend professional review. "
            "3. Do not give treatment advice. "
            "4. Flag unsafe claims for blocking."
        )

    async def retrieve_disclaimer_rules(self) -> str:
        return (
            "Always include: 'This is not a diagnosis.' "
            "Always include: 'Please consult a qualified clinician.' "
            "Never say: 'The image confirms cancer.' "
            "Never say: 'Treatment should be X.'"
        )

    async def retrieve_templates(self, template_name: str) -> str:
        templates = {
            "prediction": "{label} pattern detected with {confidence}% confidence.",
            "gradcam": "The highlighted regions show areas the model focused on when making this prediction.",
            "quality": "Image quality was assessed as {quality}. Lower quality may affect reliability.",
            "risk": "Based on the analysis, professional review is recommended.",
        }
        return templates.get(template_name, "")

    async def build_rag_chain(self, facts: dict) -> dict:
        """Build structured context from facts + RAG retrieval."""
        triage = facts.get("triage_level", "unknown")
        prediction = facts.get("prediction_label", "unknown")

        context = await self.retrieve_policy_context(triage, prediction)

        return {
            "facts": facts,
            "policy_context": context,
            "rag_sources": ["medical_policy_store", "disclaimer_rules", "xai_templates"],
        }
```

What this code does:
- `TypedDict` defines dictionary shapes with named keys.
- `PolicyContext` declares the policy fields the RAG layer returns.
- `LangChainPolicyRAGService` is the service responsible for policy retrieval and grounding.
- `__init__` starts with `_initialized = False` so setup can run once later.
- `initialize` flips `_initialized` to `True` and avoids repeated setup.
- `retrieve_policy_context` is async because real retrieval will likely call a database, vector store, or external service.
- The current implementation returns hard-coded safety policy, disclaimer, explanation template, and XAI guidance so the rest of the app can be built before a vector store exists.
- `retrieve_safety_policy` returns the core safety rules.
- `retrieve_disclaimer_rules` returns wording rules that should be included or avoided.
- `retrieve_templates` returns a named explanation template from a dictionary.
- `templates.get(template_name, "")` safely returns an empty string if the requested template does not exist.
- `build_rag_chain` receives structured facts, pulls triage and prediction values, retrieves policy context, and returns a combined dictionary.
- `rag_sources` records where the policy context conceptually came from, which helps later audit and debugging.
- The local scaffold intentionally avoids importing LangChain packages until a real vector store or retriever is added. This keeps the guide runnable with the current backend dependencies.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.services.langchain_policy_rag_service import LangChainPolicyRAGService; s = LangChainPolicyRAGService(); print('LangChain RAG service created')"
```

What this command does:
- It imports `LangChainPolicyRAGService`.
- It creates an instance to confirm the class can be constructed.
- It prints a success message if the import and constructor work.

### Learning: when this stub becomes a real vector store

`retrieve_policy_context` returns hard-coded strings today, and the comment says so: "In a real implementation this would query a medical policy vector store." That stub is the correct first move because it lets the rest of the explanation flow be built before any retrieval exists. When you replace it with a real medical policy store, the same retrieval engineering that applies to the market research RAG applies here, scaled down for a small, structured corpus. The full catalog is `reference/09_SYSTEM_DESIGN_PATTERNS.md` Family 13.

- **Chunk by policy clause, not by token count.** The policy corpus is short and structured, so one clause per chunk keeps retrieval precise (Family 13.1).
- **Same embedding model for index and query**, dimension in the 768 to 1536 range (Family 13.2), and store vectors in pgvector (Family 13.3). Note the vector index goes on a pgvector-capable Postgres (Aurora PostgreSQL or RDS), not on Aurora DSQL, which does not support the pgvector extension. Keep this clinical index physically separate from the doctor, customer, research, and admin indexes (`product/13`, and `reference/09` 12.3).
- **Hybrid search helps** when a query names an exact CAM method or Fitzpatrick type that vector search would blur (Family 13.4).
- **Prefer an honest refusal over a weak answer.** If retrieval returns nothing relevant, the explanation should say it does not have enough information rather than guess. That grounding rule lives in the prompts in `product/06` and is the cheapest defense against hallucination (Family 13.11, and `reference/09` 12.2 and 12.6).

On the observability and cost side, this guide already gives you the levers. The tracing service and the safety-specific metrics (Step 6 and Step 16) are exactly the LangSmith-style traceability production RAG needs: the exact prompt sent, the response, token counts, and latency per step. Add the cost levers from Family 13.12 on top: cache repeated query embeddings and retrieved context (ties to `staging/20_ELASTICACHE_REDIS`), enforce a per-request token budget, and keep the embedding dimension modest. Trace token counts per step so you can see where RAG spend actually goes.

## Step 8: Add ADK XAI Orchestrator Service

Create:

```text
app/services/adk_xai_orchestrator_service.py
```

What this path block means:
- Create this file in the backend service layer.
- The file will coordinate the multi-agent XAI workflow.

Paste:

```python
from typing import TypedDict
from app.observability.tracing import tracing_service


class AgentOutput(TypedDict):
    agent_name: str
    content: str
    status: str


class XAIWorkflowResult(TypedDict):
    prediction_explanation: str
    gradcam_explanation: str
    image_quality_note: str
    risk_note: str
    synthesis: str
    safety_status: str
    blocked_claims: list[str]


class ADKXAIOrchestratorService:
    """Google ADK multi-agent XAI orchestration."""

    def __init__(self) -> None:
        self._initialized = False

    def initialize(self) -> None:
        if self._initialized:
            return
        self._initialized = True

    async def run_workflow(self, rag_context: dict, facts: dict) -> XAIWorkflowResult:
        """
        Run Google ADK agent workflow.
        Each agent produces output that feeds into the next.
        """
        with tracing_service.span("adk_xai_workflow", {"triage": facts.get("triage_level", "unknown")}):
            prediction_output = await self._run_prediction_explainer(rag_context, facts)
            gradcam_output = await self._run_gradcam_explainer(rag_context, facts)
            quality_output = await self._run_image_quality_agent(rag_context, facts)
            risk_output = await self._run_risk_communication_agent(rag_context, facts)
            synthesis_output = await self._run_synthesis_agent(
                rag_context, facts,
                prediction_output, gradcam_output, quality_output, risk_output
            )
            safety_result = await self._run_safety_validator(synthesis_output)

            return XAIWorkflowResult(
                prediction_explanation=prediction_output.get("content", ""),
                gradcam_explanation=gradcam_output.get("content", ""),
                image_quality_note=quality_output.get("content", ""),
                risk_note=risk_output.get("content", ""),
                synthesis=synthesis_output.get("content", ""),
                safety_status=safety_result.get("status", "unknown"),
                blocked_claims=safety_result.get("blocked_claims", []),
            )

    async def _run_prediction_explainer(self, context: dict, facts: dict) -> AgentOutput:
        with tracing_service.span("prediction_explainer_agent"):
            return AgentOutput(
                agent_name="PredictionExplainerAgent",
                content=f"Based on the analysis, the model flagged a {facts.get('prediction_label', 'unknown')} pattern. "
                        f"This should be reviewed by a qualified clinician.",
                status="completed"
            )

    async def _run_gradcam_explainer(self, context: dict, facts: dict) -> AgentOutput:
        with tracing_service.span("gradcam_explainer_agent"):
            return AgentOutput(
                agent_name="GradCamExplainerAgent",
                content="The highlighted regions indicate areas the model focused on. "
                        "This is not proof of pathology and should be interpreted cautiously.",
                status="completed"
            )

    async def _run_image_quality_agent(self, context: dict, facts: dict) -> AgentOutput:
        with tracing_service.span("image_quality_agent"):
            return AgentOutput(
                agent_name="ImageQualityExplanationAgent",
                content=f"Image quality was assessed. Results should be verified clinically.",
                status="completed"
            )

    async def _run_risk_communication_agent(self, context: dict, facts: dict) -> AgentOutput:
        with tracing_service.span("risk_communication_agent"):
            return AgentOutput(
                agent_name="RiskCommunicationAgent",
                content="Professional medical review is strongly recommended.",
                status="completed"
            )

    async def _run_synthesis_agent(
        self, context: dict, facts: dict,
        pred: AgentOutput, gradcam: AgentOutput,
        quality: AgentOutput, risk: AgentOutput
    ) -> AgentOutput:
        with tracing_service.span("synthesis_agent"):
            synthesis_text = (
                f"{pred['content']} {gradcam['content']} "
                f"{quality['content']} {risk['content']}"
            )
            return AgentOutput(
                agent_name="SynthesisAgent",
                content=synthesis_text,
                status="completed"
            )

    async def _run_safety_validator(self, synthesis: AgentOutput) -> dict:
        with tracing_service.span("safety_validator_agent"):
            blocked = []
            content = synthesis.get("content", "").lower()
            if "diagnosis" in content and "not a diagnosis" not in content:
                blocked.append("Definitive diagnosis claim")
            if "treatment" in content and ("prescribe" in content or "dosage" in content):
                blocked.append("Treatment advice claim")
            return {
                "status": "pass" if not blocked else "fail",
                "blocked_claims": blocked
            }
```

What this code does:
- `TypedDict` defines dictionary-like return types with expected keys.
- `tracing_service` is imported so each agent step can create trace spans.
- `AgentOutput` describes the standard output from one agent: name, content, and status.
- `XAIWorkflowResult` describes the final combined workflow result returned to the API layer.
- `ADKXAIOrchestratorService` is the coordinator class for the multi-agent explanation flow.
- `__init__` starts with `_initialized = False` for future one-time setup.
- `initialize` marks the service initialized and avoids repeating setup work.
- `run_workflow` is async because real agent calls may involve model calls, tools, or network operations.
- The outer `adk_xai_workflow` span tracks the full multi-agent workflow.
- `_run_prediction_explainer`, `_run_gradcam_explainer`, `_run_image_quality_agent`, and `_run_risk_communication_agent` each create one piece of the explanation.
- `_run_synthesis_agent` combines the separate agent outputs into one coherent explanation.
- `_run_safety_validator` checks the synthesized output for unsafe medical claims.
- Each helper method returns a consistent dictionary so later code can combine outputs safely.
- The current implementation uses placeholder text; later, these methods can call real Google ADK agents.
- The safety validator currently uses simple string checks for diagnosis and treatment risks. This is a starter guard, not a complete medical safety system.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.services.adk_xai_orchestrator_service import ADKXAIOrchestratorService; s = ADKXAIOrchestratorService(); print('ADK orchestrator created')"
```

What this command does:
- It imports the orchestrator service.
- It creates an instance to confirm the file has no syntax or import errors.
- It prints a success message if the constructor works.

## Step 9: Add LLM Safety Validator Service

Create:

```text
app/services/llm_safety_validator_service.py
```

What this path block means:
- Create this file in the backend service layer.
- It will contain a lightweight safety validator that can run before or after LLM generation.

Paste:

```python
from typing import TypedDict


class SafetyValidationResult(TypedDict):
    status: str
    blocked_claims: list[str]
    doctor_review_recommended: bool


BLOCKED_PATTERNS = [
    ("definitive diagnosis", "Diagnosis claim without qualification"),
    ("you have cancer", "Unsafe diagnosis claim"),
    ("treatment should be", "Treatment advice claim"),
    ("prescribe", "Prescription claim"),
    ("ignore your doctor", "Unsafe medical advice"),
]


class LLMSafetyValidatorService:
    """Validate LLM output for unsafe medical claims."""

    def validate(self, text: str) -> SafetyValidationResult:
        blocked = []
        text_lower = text.lower()

        for pattern, reason in BLOCKED_PATTERNS:
            if pattern in text_lower:
                blocked.append(reason)

        doctor_recommended = (
            "consult" in text_lower or
            "professional" in text_lower or
            "clinician" in text_lower or
            "doctor" in text_lower
        )

        return SafetyValidationResult(
            status="fail" if blocked else "pass",
            blocked_claims=blocked,
            doctor_review_recommended=doctor_recommended,
        )
```

What this code does:
- `TypedDict` defines the shape of the validation result dictionary.
- `SafetyValidationResult` requires three fields: `status`, `blocked_claims`, and `doctor_review_recommended`.
- `BLOCKED_PATTERNS` lists unsafe phrases and the reason each one should be blocked.
- `LLMSafetyValidatorService` wraps the validation logic in a reusable class.
- `validate` accepts generated text and returns a structured safety result.
- `blocked = []` starts with no safety violations.
- `text_lower = text.lower()` makes matching case-insensitive.
- The `for` loop checks every blocked pattern against the output text.
- If a pattern appears, the corresponding reason is appended to `blocked`.
- `doctor_recommended` checks whether the text includes language that points the user to professional care.
- The return value uses `status="fail"` when blocked claims exist and `status="pass"` otherwise.
- This is a simple deterministic safety layer. It should complement, not replace, a stronger LLM or policy validator.

Check:

```powershell
cd Skin_Lesion_Classification_backend
python -c "from app.services.llm_safety_validator_service import LLMSafetyValidatorService; v = LLMSafetyValidatorService(); print(v.validate('This is not a diagnosis. Please consult a doctor.'))"
```

What this command does:
- It imports the safety validator.
- It creates the validator class.
- It validates a safe example sentence that includes both “not a diagnosis” and “consult a doctor.”
- Printing the result shows whether the validator returns the expected structured dictionary.

Expected result: `status='pass'`.

## Step 10: Update Explanation Endpoint

Update `app/api/v1/explain.py` to use the new services:

```python
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.observability.redaction import redact_trace_payload
from app.observability.tracing import tracing_service
from app.services.adk_xai_orchestrator_service import ADKXAIOrchestratorService
from app.services.explanation_facts_service import ExplanationFactsService
from app.services.langchain_policy_rag_service import LangChainPolicyRAGService
from app.services.llm_explanation_service import ExplanationResponse, LLMExplanationService

router = APIRouter(prefix="/api/v1")
_llm_service: LLMExplanationService | None = None


def get_llm_service() -> LLMExplanationService:
    global _llm_service
    if _llm_service is None:
        _llm_service = LLMExplanationService()
    return _llm_service


@router.post("/explain-llm/{analysis_id}", response_model=ExplanationResponse)
async def explain_analysis(
    analysis_id: uuid.UUID,
    db: Session = Depends(get_db),
) -> ExplanationResponse:
    with tracing_service.span("explain_llm_request"):
        with tracing_service.span("load_analysis_event"):
            facts_service = ExplanationFactsService(db)
            facts = facts_service.build_facts(analysis_id)
            if facts is None:
                raise HTTPException(status_code=404, detail="Analysis not found")

        with tracing_service.span("build_structured_facts"):
            structured = facts_service.to_structured(facts)

        with tracing_service.span("langchain_policy_rag"):
            rag_service = LangChainPolicyRAGService()
            rag_context = await rag_service.build_rag_chain(structured)

        with tracing_service.span("adk_xai_workflow"):
            orchestrator = ADKXAIOrchestratorService()
            result = await orchestrator.run_workflow(rag_context, structured)

        trace_payload = redact_trace_payload({
            "analysis_id": str(analysis_id),
            "triage_level": structured.get("triage_level"),
            "safety_status": result["safety_status"],
        })
        tracing_service.trace_event("explain_llm_safe_metadata", trace_payload)

        with tracing_service.span("persist_explanation"):
            pass

        with tracing_service.span("return_response"):
            trace_id = tracing_service.get_current_trace_id()

        return ExplanationResponse(
            summary=result["synthesis"],
            prediction_explanation=result["prediction_explanation"],
            gradcam_explanation=result["gradcam_explanation"],
            image_quality_note=result["image_quality_note"],
            body_location_note="Submitted by the patient, not clinically verified.",
            lab_result_note="Lab results available but not yet reviewed by a doctor.",
            risk_note=result["risk_note"],
            safety_note="This is not a diagnosis. Please consult a qualified clinician.",
            blocked_claims=result["blocked_claims"],
            safe=result["safety_status"] == "pass",
            trace_id=trace_id,
        )
```

What this endpoint code does:
- `uuid` lets FastAPI validate the analysis ID before database lookup.
- `APIRouter` creates a FastAPI route group.
- `Depends` is used for the database dependency.
- `HTTPException` returns a clean 404 when the analysis is missing.
- `Session` types the database session.
- `get_db` provides the backend SQLAlchemy session.
- `ExplanationFactsService` loads and structures analysis facts.
- `LangChainPolicyRAGService` retrieves policy and grounding context.
- `ADKXAIOrchestratorService` runs the multi-agent explanation workflow.
- `tracing_service` wraps each major step in named spans.
- `redact_trace_payload` cleans trace metadata before it is logged or exported.
- `ExplanationResponse` keeps the response shape aligned with guide 06.
- `LLMExplanationService` and `get_llm_service` are kept for the Anthropic-backed path, but the ADK scaffold does not instantiate it during normal import.
- `router = APIRouter(prefix="/api/v1")` keeps this route aligned with the existing backend API prefix.
- `@router.post("/explain-llm/{analysis_id}")` defines a POST endpoint with `analysis_id` in the URL.
- `async def explain_analysis` allows the endpoint to await async RAG and ADK scaffold services.
- `explain_llm_request` is the outer trace span for the full request.
- `load_analysis_event` loads the analysis facts.
- `build_structured_facts` converts raw records into safe structured facts.
- `langchain_policy_rag` builds the retrieved policy context.
- `adk_xai_workflow` runs the agent workflow and returns structured output.
- `trace_payload` keeps only safe metadata: analysis ID, triage level, and safety status.
- `persist_explanation` is a placeholder span where database saving should be implemented.
- `return_response` captures the trace ID before returning.
- The returned `ExplanationResponse` is the patient-facing response shape with summary, explanations, safety note, blocked claims, and trace ID.

Also update `app/services/explanation_facts_service.py` with this helper method inside `ExplanationFactsService`:

```python
    def to_structured(self, facts: ExplanationFacts) -> dict:
        """Convert safe explanation facts into the dict expected by the RAG/agent workflow."""
        confidence_bucket = "high" if facts.confidence >= 0.8 else "medium" if facts.confidence >= 0.5 else "low"
        triage_level = "review" if facts.prediction == "malignant" else "routine"
        return {
            "analysis_id": str(facts.analysis_id),
            "triage_level": triage_level,
            "prediction_label": facts.prediction,
            "confidence": facts.confidence,
            "confidence_bucket": confidence_bucket,
            "patient_label": facts.patient_label,
            "model_version": facts.model_version,
            "gradcam_regions": facts.gradcam.highlighted_regions,
            "heatmap_available": facts.gradcam.heatmap_available,
            "image_quality": facts.image_quality.model_dump(),
            "body_location_status": facts.body_location.verification_status,
            "lab_result_status": facts.lab_results.doctor_review_status,
        }
```

Update `app/services/llm_explanation_service.py` so `ExplanationResponse` has the extra fields returned by the traced ADK path:

```python
    risk_note: str | None = None
    trace_id: str | None = None
```

## Step 11: Add Trace Model

The complete trace hierarchy for one explanation request:

```text
Trace: explain_llm_request
  Span: load_analysis_event
  Span: build_structured_facts
  Span: langchain_policy_rag
  Span: adk_xai_workflow
    Span: prediction_explainer_agent
    Span: gradcam_explainer_agent
    Span: image_quality_agent
    Span: risk_communication_agent
    Span: synthesis_agent
    Span: safety_validator_agent
  Span: persist_explanation
  Span: return_response
```

What this trace model means:
- A trace is the full request journey.
- A span is one timed operation inside that journey.
- `explain_llm_request` is the parent span for the endpoint.
- `load_analysis_event`, `build_structured_facts`, and `langchain_policy_rag` show the preparation steps.
- `adk_xai_workflow` contains child spans for each agent.
- Agent spans let you see which agent was slow or failed.
- `persist_explanation` tracks the save step.
- `return_response` tracks the final response-building step.

## Step 12: Environment-Specific Observability Plan

### Local / Dev

```text
LangChain / LangGraph  →  LangSmith native tracing
Google ADK             →  manual LangSmith wrapper or OpenTelemetry-to-LangSmith
Goal                  →  debug prompts, agent steps, safety validator, blocked claims
```

What this local plan means:
- Local development can use LangSmith for detailed debugging.
- Google ADK can be wrapped manually or routed through OpenTelemetry-to-LangSmith.
- The goal is to debug prompts, agent steps, safety checks, and blocked claims before using real patient data.

### Staging

```text
LangChain + ADK        →  OpenTelemetry Collector
Collector             →  LangSmith + Google Cloud Trace or MLflow
Goal                  →  validate full distributed traces before production
```

What this staging plan means:
- Staging sends LangChain and ADK traces to an OpenTelemetry Collector.
- The collector can forward traces to LangSmith, Google Cloud Trace, or MLflow.
- The goal is to validate distributed tracing before production while keeping redaction on.

### Production

```text
LangChain + ADK        →  OpenTelemetry Collector
Collector             →  Google Cloud Trace / MLflow / Datadog / SigNoz
LangSmith             →  optional only with strict redaction
Goal                  →  reliability, latency, cost, errors, safety failures, model/tool performance
```

What this production plan means:
- Production should use OpenTelemetry as the main tracing path.
- The collector can send traces to the chosen production observability vendor.
- LangSmith is optional and only acceptable with strict redaction.
- Production metrics focus on reliability, latency, cost, errors, safety failures, and model/tool performance.

Production should prioritize OpenTelemetry-based observability over full prompt debugging.

## Step 13: Privacy and Redaction Rules

Do not send these to LangSmith, Google Trace, MLflow, Datadog, SigNoz, or any external observability system:

```text
raw lesion images
image URLs
Grad-CAM image URLs
segmentation mask URLs
lab report PDFs
lab report image URLs
patient name
patient email
address
exact birth date
full patient notes
full doctor notes
raw free-text medical history
```

What this privacy block means:
- These values are too sensitive to send to external tracing, logging, or observability systems.
- Raw images, URLs, reports, identifiers, dates, and free-text notes can expose patient information.
- If a value is needed for debugging, use a hash, status, bucket, or redacted placeholder instead.

Only trace safe metadata:

File path for this example policy:

```text
Skin_Lesion_Classification_backend/app/observability/tracing.py
```

What this path block means:
- This is the backend file where the safe metadata policy should be enforced.
- Keeping this policy near tracing code makes it harder to accidentally trace sensitive values.

```python
safe_metadata = {
    "analysis_id": "ana_123",
    "lesion_id_hash": "hash_456",
    "triage_level": "monitor",
    "prediction_label": "higher_risk_pattern",
    "confidence_bucket": "medium",
    "image_quality": "acceptable",
    "body_location_status": "patient_submitted",
    "lab_result_status": "uploaded_not_doctor_reviewed",
    "model_version": "efficientnet_v1",
    "safety_status": "passed",
}
```

What this metadata code does:
- `safe_metadata` is a dictionary of values considered safer to trace.
- `analysis_id` is included for request correlation; in stricter environments this can also be hashed.
- `lesion_id_hash` uses a hash instead of a raw lesion ID.
- `triage_level`, `prediction_label`, `confidence_bucket`, and `image_quality` describe broad categories instead of raw medical details.
- `body_location_status` records verification state without exposing the body location text.
- `lab_result_status` records review state without exposing lab contents.
- `model_version` helps debug model behavior across releases.
- `safety_status` records whether the explanation passed safety checks.

## Step 14: LangSmith Usage Rules

LangSmith is used mainly for:

```text
local debugging
prompt testing
agent flow inspection
safety validator debugging
evaluation datasets with fake or de-identified examples
```

What this LangSmith usage block means:
- LangSmith is mainly for local debugging and prompt/agent inspection.
- Safety validator debugging is acceptable when using fake or de-identified examples.
- Evaluation datasets should not contain raw patient data.

LangSmith should not be the default production store for full medical prompts and completions.

If LangSmith is enabled in staging or production, it must use:

```text
redacted metadata
no raw images
no URLs
no lab reports
no patient identifiers
no full doctor or patient notes
```

What this production LangSmith block means:
- If LangSmith is used outside local development, it must receive only redacted metadata.
- It must not receive raw images, URLs, lab reports, patient identifiers, or full notes.
- This keeps debugging tools from becoming a second medical-record store.

## Step 15: OpenTelemetry Collector Path

```
FastAPI + LangChain + Google ADK
        ↓ OTLPOpenTelemetry Collector
        ↓
Google Cloud Trace / MLflow / Datadog / SigNoz / optional LangSmith
```

What this collector diagram means:
- FastAPI, LangChain, and Google ADK all emit OpenTelemetry traces.
- The OpenTelemetry Collector receives those traces in one standard format.
- The collector forwards traces to whichever backend you choose, such as Google Cloud Trace, MLflow, Datadog, SigNoz, or redacted LangSmith.
- This design lets you change observability vendors later without rewriting application tracing code.

This keeps one instrumentation standard while allowing vendor changes later.

## Step 16: Safety-Specific Metrics

Track these metrics:

```text
llm_explanation_requested
llm_explanation_completed
llm_explanation_failed
safety_validator_passed
safety_validator_failed
blocked_claim_count
unsafe_diagnosis_claim_blocked
treatment_advice_blocked
doctor_review_recommended_count
adk_agent_latency_ms
langchain_rag_latency_ms
llm_total_latency_ms
llm_token_usage
llm_cost_estimate
```

What this metrics block means:
- These counters and timings measure the safety and performance of LLM explanations.
- Request, completion, and failure metrics show reliability.
- Safety validator metrics show how often unsafe claims are blocked.
- Latency metrics show which part of the pipeline is slow.
- Token and cost metrics help control LLM spending.

Safe labels only:

```text
environment
model_version
triage_level
agent_name
safety_status
error_type
```

What this label block means:
- Labels are dimensions used to group metrics.
- These labels are safe because they describe environment, model version, triage category, agent name, safety state, or error type.
- Do not add patient identifiers, image URLs, free-text notes, or exact body locations as labels.

## Step 17: Observability Failure Rule

Important:

```text
If LangSmith, OpenTelemetry, or the collector fails, the user-facing explanation endpoint must still work.
Observability must not become a hard dependency for patient response generation.
```

What this rule block means:
- The product must still return an explanation if tracing tools are down.
- Observability is important for debugging and monitoring, but it should not block patient-facing functionality.
- Code should catch or isolate telemetry failures so clinical response generation continues.

## Completion Gate

LangChain, ADK, and observability are ready only when:

```text
LangChain RAG returns policy context
ADK workflow produces all expected agent outputs
Safety validator blocks definitive diagnosis
Safety validator blocks treatment advice
Tracing works in local dev
Tracing redaction removes image URLs and patient identifiers
Production config disables prompt/completion tracing
Trace IDs are not exposed to normal patient users
Observability failure does not break the clinical response
```

What this completion gate means:
- The guide is complete only when policy retrieval works, the ADK workflow returns every expected output, and safety checks block dangerous medical claims.
- Tracing must work locally and redaction must remove image URLs and patient identifiers.
- Production config must disable prompt and completion tracing.
- Trace IDs should not be exposed to normal patient users unless there is a deliberate support workflow.
- The response endpoint must continue working even if observability fails.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

What these commands do:
- `make cloud-status ENV=dev` checks whether development cloud resources are running.
- `make cloud-pause ENV=dev` pauses supported resources to reduce cost.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` intentionally shuts down or destroys development resources.
- `CONFIRM_DESTROY=YES` is a safety confirmation for destructive shutdown behavior.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

What these commands do:
- `make cloud-start ENV=dev` starts the development cloud environment again.
- `make cloud-status ENV=dev` confirms the environment is available before continuing.

If this guide was local-only, no cloud shutdown is needed.
