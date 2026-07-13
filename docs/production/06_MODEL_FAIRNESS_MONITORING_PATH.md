# Model Fairness And Monitoring Path

This guide covers calibration, fairness evaluation, active learning, and production observability.

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves the terminal into the main workspace root. Run this before any cross-repo make commands so relative paths resolve correctly.

Current repos:

```text
Skin_Lesion_Classification_backend
Skin_Lesion_XAI_research
Skin_Lesion_Classification_frontend
```

**What these repos mean:**

- `Skin_Lesion_Classification_backend` is where model inference, Grad-CAM, and API routes live.
- `Skin_Lesion_XAI_research` is where notebooks, fairness metrics, and calibration experiments live.
- `Skin_Lesion_Classification_frontend` is where dashboards and result viewers live.

## Build

Track:

```text
accuracy
sensitivity
specificity
false positives
false negatives
confidence calibration
performance by skin tone
performance by body region
performance by image quality
performance by device/camera type
```

**What these metrics mean:**

- `accuracy` - the overall correct prediction rate, but this alone is misleading because the dataset is imbalanced.
- `sensitivity` - true positive rate for malignant predictions. Missing a malignant case (false negative) is the more dangerous error, so sensitivity is the priority metric.
- `specificity` - true negative rate for benign predictions. Low specificity means too many false alarms.
- `false positives` - benign lesions incorrectly flagged as malignant. Causes unnecessary patient anxiety.
- `false negatives` - malignant lesions incorrectly classified as benign. The more dangerous failure mode.
- `confidence calibration` - measures whether a 90% confidence prediction actually corresponds to a 90% correct rate on a test set.
- `performance by skin tone` - Fitzpatrick subgroup analysis to detect unfair performance gaps across skin tones.
- `performance by body region` - some body regions are less commonly represented in training data.
- `performance by image quality` - low-quality images may degrade model performance in predictable ways.
- `performance by device/camera type` - dermoscopy vs. smartphone camera capture may produce different performance profiles.

Monitor:

```text
API latency
model inference time
Grad-CAM generation time
failed uploads
poor image quality rate
LLM safety failure rate
doctor review queue size
storage usage
error rates
```

**What these monitoring signals mean:**

- `API latency` - time from request to response. A rising p95 latency is an early warning of overload or regression.
- `model inference time` - isolates the model forward pass from other API latency sources.
- `Grad-CAM generation time` - heatmap generation is separate from inference. Track it independently because it can slow down or fail separately.
- `failed uploads` - image upload failures could indicate frontend issues, network problems, or S3 permission errors.
- `poor image quality rate` - rising rejection rate may mean users are struggling with the upload UI.
- `LLM safety failure rate` - how often the LLM explanation is blocked by refusal patterns. A high rate may mean prompts are being crafted adversarially.
- `doctor review queue size` - a growing queue means cases are arriving faster than doctors can review them.
- `storage usage` - S3 and database size growth to catch runaway data accumulation.
- `error rates` - 4xx and 5xx rates per endpoint, broken out so you can tell user errors from server errors.

## Check

```powershell
make check
```

Expected result: the project can show where the model works well, where it is uncertain, and where human review is needed.

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` checks the dev environment state.
- `make cloud-pause ENV=dev` pauses pausable dev resources to reduce billing.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys dev resources; the flag prevents accidental teardown.

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
