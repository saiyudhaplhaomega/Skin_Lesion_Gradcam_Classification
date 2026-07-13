# Agentic XAI ADK-Style Path

This is the advanced implementation path for sequential, parallel, and loop-based XAI explanation workflows.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
cd Skin_Lesion_Classification_backend
```

**What this does:** moves first to the main workspace root, then into the backend repository where agentic XAI orchestration code lives.

Current repo:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the agentic XAI orchestration code lives in the backend, not a separate service.

## Sequential Workflow

```text
ImageQualityNarratorAgent
PredictionExplainerAgent
GradCamExplainerAgent
MedicalSafetyAgent
FinalResponseAgent
```

**What this sequential agent chain does:**

- `ImageQualityNarratorAgent` - receives the quality assessment result and narrates what the image quality means for the analysis reliability.
- `PredictionExplainerAgent` - takes the model output (label + confidence) and generates a structured explanation of the classification result.
- `GradCamExplainerAgent` - receives the heatmap region summary and explains which parts of the image the model attended to.
- `MedicalSafetyAgent` - reviews all previous agent outputs and checks for diagnosis language, overconfidence, or other safety violations. Blocks unsafe content.
- `FinalResponseAgent` - assembles the safe outputs from earlier agents into the final patient-facing explanation.

## Parallel Workflow

```text
FactsBuilderTool
ParallelAgent:
  PredictionExplanationAgent -> prediction_report
  GradCamExplanationAgent -> gradcam_report
  ImageQualityExplanationAgent -> quality_report
  RiskCommunicationAgent -> risk_report
SynthesisAgent
SafetyValidatorAgent
FinalResponseAgent
```

**What this parallel agent workflow does:**

- `FactsBuilderTool` - prepares structured facts (model output, heatmap regions, image quality score) as shared input for all parallel agents.
- `ParallelAgent` - runs the four explanation agents simultaneously, each producing a separate report. This reduces total latency compared to running them sequentially.
- The four parallel agents produce independent reports: prediction explanation, Grad-CAM explanation, image quality narrative, and risk communication.
- `SynthesisAgent` - combines the four parallel reports into a unified, coherent explanation.
- `SafetyValidatorAgent` - checks the synthesized explanation for safety violations before the final response is assembled.
- `FinalResponseAgent` - produces the final patient-facing text from the validated synthesis.

## Loop Workflow

```text
DraftExplanationAgent
SafetyCriticAgent
RevisionAgent
```

**What this loop workflow does:**

- `DraftExplanationAgent` - generates an initial draft explanation.
- `SafetyCriticAgent` - evaluates the draft for safety violations (diagnosis language, overconfidence, ABCDE phrasing).
- `RevisionAgent` - rewrites the draft based on the safety critic's feedback.

The loop repeats with the revised draft until the safety critic approves it.

Stop when:

```text
safety_status == "pass"
```

**What this stop condition means:** `safety_status` is a field set by `SafetyCriticAgent` on each evaluation pass. When it equals `"pass"`, the safety check succeeded and the loop exits. Without this condition, the loop would run indefinitely.

or after the configured maximum iterations.

## Check

```powershell
make test
```

Expected result: unsafe claims are blocked or rewritten before the frontend receives the explanation.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the dev environment state.
- `make cloud-pause ENV=dev` pauses pausable resources.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources with explicit confirmation.

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
