# Confidence Calibration Handholding Guide

Use this after real model inference works (after `docs/local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md`).

This closes High Priority Gap: "Confidence not calibrated - raw softmax is overconfident for medical use."

## Goal

Fit a temperature scaling parameter on the validation set so the model's confidence scores match observed accuracy. Then integrate calibrated confidence into the backend and explain it to the patient correctly.

## Why This Matters

A well-calibrated model says 0.7 when it is right about 70% of the time. ResNet50 trained on HAM10000 says 0.97 on many images - and is still wrong 20% of the time at that level. Showing 97% to a patient is actively misleading.

Temperature scaling is 5 lines of math and the most reliable calibration method for neural networks.

Pattern reference: `docs/reference/09_SYSTEM_DESIGN_PATTERNS.md` section 9.3 (Calibration).

## Command Location

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
```

What this does: moves your terminal into the research repo, where calibration scripts and validation data belong.

All calibration scripts run in the research repo. The fitted temperature value is then hardcoded into the backend `ModelService`.

## Environment Setup

Run calibration commands with the research repo Python environment, not the system `python`.

From PowerShell:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\Activate.ps1
python -c "import sys; print(sys.executable); import torch; print(torch.__version__)"
```

What this does:

- Moves into the research repo.
- Activates the research virtual environment at `Skin_Lesion_XAI_research/skin-lesion-env`.
- Confirms the active Python can import `torch`.

Expected result:

```text
...\Skin_Lesion_XAI_research\skin-lesion-env\Scripts\python.exe
2.6.0...
```

If you see this error:

```text
ModuleNotFoundError: No module named 'torch'
```

you are not running the research environment Python. Use either the activated environment command above or call the environment Python directly:

```powershell
.\skin-lesion-env\Scripts\python.exe scripts\fit_temperature.py --logits calibration_data\logits.npz
```

Do not fix this by installing Torch into a random global Python. This project already has Torch in the research environment.

If `skin-lesion-env` does not exist, create it from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
python -m venv skin-lesion-env
.\skin-lesion-env\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -c "import torch; print(torch.__version__)"
```

Expected result: Torch imports successfully from `skin-lesion-env`.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Research repo: `Skin_Lesion_XAI_research/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create calibration scripts, reports, and fitted temperature artifacts under `Skin_Lesion_XAI_research/`.
- Update backend confidence usage only in the exact `Skin_Lesion_Classification_backend/...` file named by the step.

## Step 1: Understand Temperature Scaling

Temperature scaling divides the logit by a scalar T before the sigmoid:

```text
calibrated_prob = sigmoid(logit / T)
```

What this formula does: divides the raw model logit by the fitted temperature before converting it to a probability.

- T = 1.0: no change (raw sigmoid)
- T > 1.0: flattens the distribution (lowers overconfident predictions)
- T < 1.0: sharpens the distribution (not useful for overconfident models)

The scalar T is the only learnable parameter. You fit it on the validation set.

## Step 2: Verify The Calibration Scripts Compile

Files used in this step:

- `Skin_Lesion_XAI_research/scripts/make_calibration_smoke_data.py`
- `Skin_Lesion_XAI_research/scripts/collect_calibration_logits.py`
- `Skin_Lesion_XAI_research/scripts/fit_temperature.py`

Run from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe -m py_compile scripts\fit_temperature.py scripts\collect_calibration_logits.py scripts\make_calibration_smoke_data.py
```

Expected result: no output and no error.

What this does: proves Python can parse the scripts before you spend time running model inference.

## Step 3: Run A Smoke Test First

Run from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe scripts\make_calibration_smoke_data.py --output calibration_data\smoke_logits.npz
.\skin-lesion-env\Scripts\python.exe scripts\fit_temperature.py --logits calibration_data\smoke_logits.npz --output-json calibration_data\smoke_temperature_report.json
```

Expected result:

```text
Saved smoke logits: calibration_data\smoke_logits.npz
Examples: 12
ECE before calibration: ...
NLL before calibration: ...
Optimal temperature T = ...
ECE after calibration: ...
NLL after calibration: ...
Saved report: calibration_data\smoke_temperature_report.json
```

What this does: checks the temperature-fitting code with fake deterministic logits. This only proves the script works. Do not paste the smoke-test temperature into the backend.

## Step 4: Collect Real Validation Logits

File this command reads:

```text
Skin_Lesion_Classification_backend/ml/data/processed/metadata_with_paths.csv
```

Checkpoint this command reads:

```text
Skin_Lesion_Classification_backend/ml/outputs/models/ham10000_resnet50_binary_best.pth
```

File this command creates:

```text
Skin_Lesion_XAI_research/calibration_data/logits.npz
```

Run from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe scripts\collect_calibration_logits.py --checkpoint ..\Skin_Lesion_Classification_backend\ml\outputs\models\ham10000_resnet50_binary_best.pth --output calibration_data\logits.npz --batch-size 32 --trust-local-checkpoint
```

Expected result from the verified local run:

```text
Saved logits: calibration_data\logits.npz
Examples: 1486
Positive rate: 0.1622
```

What this does: loads the local trained ResNet50 checkpoint, recreates the validation split from `metadata_with_paths.csv`, runs inference on the validation images, and saves raw logits plus labels for calibration.

Why `--trust-local-checkpoint` is needed: this checkpoint was created locally by this project. PyTorch 2.6 blocks some older checkpoint metadata in `weights_only=True` mode. Only use this flag for checkpoints you created locally and trust. Do not use it for downloaded or unknown model files.

Quick check command:

```powershell
.\skin-lesion-env\Scripts\python.exe -c "import numpy as np; d=np.load('calibration_data\\logits.npz'); print(d['logits'].shape, d['labels'].shape, round(float(d['labels'].mean()), 4))"
```

Expected result:

```text
(1486,) (1486,) 0.1622
```

## Step 5: Fit The Temperature Parameter

Run from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe scripts\fit_temperature.py --logits calibration_data\logits.npz --output-json calibration_data\temperature_report.json
```

Expected result from the verified local run on 2026-05-24:

```text
ECE before calibration: 0.2125
NLL before calibration: 0.5124
Optimal temperature T = 1.5382
ECE after calibration:  0.2272
NLL after calibration:  0.4853
WARNING: ECE increased after temperature scaling. Do not paste this temperature into the backend until you confirm the checkpoint, preprocessing transform, and validation split match production inference.
Saved report: calibration_data\temperature_report.json

Candidate backend line after investigation:
_TEMPERATURE = 1.5382   # fitted on validation set, refit after every retraining run
```

What this does: fits temperature by minimizing validation negative log likelihood, prints ECE and NLL before and after calibration, and saves a JSON report.

Important: in the verified run above, NLL improved but ECE got worse. Because the goal of this guide is safer confidence, do not update the backend with `1.5382` yet. First investigate whether the checkpoint, preprocessing transform, and validation split match the backend inference path exactly.

## Step 6: Update Backend Only If Calibration Improves

File to edit after calibration improves:

```text
Skin_Lesion_Classification_backend/app/services/model_service.py
```

Find this constructor default:

```python
temperature: float = 1.5,
```

Only replace `1.5` when the calibration report shows ECE is the same or lower and NLL is lower. For example:

```python
temperature: float = 1.5382,  # fitted on validation set; refit after every retraining run
```

Do not make this edit for the verified 2026-05-24 run yet, because ECE increased from `0.2125` to `0.2272`.

Check command after a backend edit:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_Classification_backend
.\.venv\Scripts\python.exe -m pytest tests\test_calibration.py -v
```

Expected result: the calibration tests pass.

What this does: pins backend inference to the fitted temperature for the exact checkpoint and validation split you verified. Refit this value every time you retrain the model.

## Step 7: Explain Confidence To The Patient

Never show raw confidence as a percentage. Use a tiered word map:

```python
def confidence_to_patient_label(confidence: float) -> str:
    """
    Map calibrated confidence to patient-safe language.
    Never say "97% chance of cancer".
    """
    if confidence < 0.40:
        return "The model found patterns more consistent with benign lesions."
    elif confidence < 0.55:
        return "The model's result is uncertain. Professional review is recommended."
    elif confidence < 0.75:
        return "The model found some patterns that warrant follow-up with a clinician."
    else:
        return "The model found patterns that recommend professional clinical review."
```

What this function does:

- Converts calibrated confidence into patient-safe language.
- Avoids saying a patient has a percentage chance of cancer.
- Escalates uncertain or higher-risk outputs toward professional review.

Add this to `app/services/explanation_facts_service.py` and include `patient_label` in `ExplanationFacts`.

## Step 8: Test Calibration Makes Sense

Create `tests/test_calibration.py`:

```python
import math
import pytest
from app.services.model_service import _apply_temperature


@pytest.mark.parametrize("logit,expected_range", [
    (-5.0, (0.0, 0.2)),    # strongly benign
    (0.0,  (0.4, 0.6)),    # uncertain
    (5.0,  (0.8, 1.0)),    # leans malignant
])
def test_temperature_scaling_in_range(logit: float, expected_range: tuple) -> None:
    prob = _apply_temperature(logit, temperature=1.5)
    lo, hi = expected_range
    assert lo <= prob <= hi, f"logit={logit} gave prob={prob}, expected [{lo}, {hi}]"


def test_temperature_reduces_extreme_confidence() -> None:
    raw = 1.0 / (1.0 + math.exp(-8.0))      # ~0.9997 raw sigmoid
    calibrated = _apply_temperature(8.0, temperature=1.5)
    assert calibrated < raw, "Temperature scaling should reduce extreme confidence"
    assert raw - calibrated > 0.004, "Temperature scaling should lower extreme confidence noticeably"
```

What these tests do:

- Check that calibrated probabilities stay in reasonable ranges for negative, neutral, and positive logits.
- Prove temperature scaling reduces extreme overconfidence compared with raw sigmoid.

Run:

```powershell
cd ..\Skin_Lesion_Classification_backend
pytest tests/test_calibration.py -v
```

What this does: switches from the research repo to the backend repo and runs only the calibration unit tests.

## Concepts You Just Touched

- [Calibration (9.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#93-calibration) - ECE, reliability diagrams, temperature scaling
- [Safe AI Communication (11.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#111-safe-ai-communication) - why raw probability is dangerous for patient-facing UI

## Questions You Should Be Able To Answer

1. A model reports 0.97 confidence on a malignant prediction and is wrong 20% of the time at that level. What is its ECE for that bin?
2. Temperature scaling has one learnable parameter. Why is this an advantage over more complex calibration methods like Platt scaling or histogram binning?
3. After retraining the model on new data, you must refit T. Why can't you reuse the T from the previous training run?
4. The patient_label function maps confidence below 0.40 to "more consistent with benign". Is 0.40 the right threshold, or should it depend on the model's sensitivity/specificity trade-off?
5. ECE measures average calibration. What could a model with low ECE still get badly wrong for a specific patient demographic?
