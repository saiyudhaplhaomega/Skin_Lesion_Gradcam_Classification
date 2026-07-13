# Research Bridge

This document explains how experiments in `Skin_Lesion_XAI_research/` connect to the production backend pipeline. Read this before promoting any model from notebooks to deployment.

---

## Research Repo Layout

```
Skin_Lesion_XAI_research/
  notebooks/
    RQ1_model_comparison/
      01_resnet50_baseline.ipynb
      02_efficientnet_comparison.ipynb
      03_vit_experiments.ipynb
    RQ2_gradcam_faithfulness/
      01_gradcam_comparison.ipynb
      02_layer_ablation.ipynb
      03_scorecam_experiments.ipynb
    RQ3_fairness/
      01_fitzpatrick_subgroup_analysis.ipynb
      02_class_imbalance_handling.ipynb
    RQ4_cam_disagreement/
      01_multi_cam_ensemble.ipynb
      02_threshold_calibration.ipynb
    RQ5_uncertainty/
      01_mc_dropout.ipynb
      02_deep_ensemble.ipynb
  ml/
    outputs/
      models/
        resnet50_final.pth
        efficientnet_candidate.pth
      configs/
        training_config.yaml
        data_config.yaml
      logs/
        training_runs/
      reports/
        metrics_summary.csv
        calibration_results.json
      visualizations/
        confusion_matrix.png
        calibration_curve.png
        gradcam_samples/
  data/
    ham10000/
    reference_test_set/   <-- frozen, locked, gap #15
```

What this layout block means:

- `Skin_Lesion_XAI_research/` is the research repository.
- `notebooks/` contains experiment notebooks grouped by research question.
- `RQ1_model_comparison/` compares model architectures such as ResNet50, EfficientNet, and ViT.
- `RQ2_gradcam_faithfulness/` evaluates Grad-CAM methods and target layers.
- `RQ3_fairness/` studies subgroup behavior and class imbalance.
- `RQ4_cam_disagreement/` studies disagreement between explanation methods.
- `RQ5_uncertainty/` studies uncertainty methods such as MC dropout and ensembles.
- `ml/outputs/models/` stores trained model checkpoints.
- `ml/outputs/configs/` stores training and data configuration files.
- `ml/outputs/logs/` stores training logs.
- `ml/outputs/reports/` stores metric summaries and calibration outputs.
- `ml/outputs/visualizations/` stores plots and Grad-CAM sample images.
- `data/ham10000/` is the source dataset area.
- `data/reference_test_set/` is the frozen reference set used for repeatable promotion checks.

---

## Research-to-Production Handoff

### Step 1: Notebook Experiment Completes

A research notebook produces a model checkpoint in `ml/outputs/models/`.

### Step 2: Pre-Promotion Checks

Before the model can be promoted to the backend, all these must be true:

| Condition | How to verify | Gap |
|-----------|--------------|-----|
| num_workers >= 4 | Check DataLoader config in notebook | #17 |
| AMP enabled | Check `torch.cuda.amp.autocast()` usage | #18 |
| Trained >= 15 epochs | Check training log epoch count | #19 |
| Calibration fitted | Check `calibration/PHASE_TRANSITION.md` | #9 |
| Fairness metrics logged | Check RQ3 notebooks | #3 |
| Heatmap quality validated | Check RQ2 notebooks on frozen reference set | #15 |
| Model card filled | See template below | #6 |

### Step 3: Copy to Backend

```powershell
# From main repo root
copy-item Skin_Lesion_XAI_research\ml\outputs\models\resnet50_final.pth Skin_Lesion_Classification_backend\models\skin_lesion_classifier.pth
```

What this command does:

- The comment `# From main repo root` means run the command from `Skin_Lesion_GRADCAM_Classification/`.
- `copy-item` is the PowerShell command that copies a file.
- The source path is the research model checkpoint produced by training.
- The destination path is the backend model filename that `ModelService` expects.
- This makes one selected research checkpoint active for local backend inference.

The backend `ModelService` loads from `models/skin_lesion_classifier.pth`. Only one candidate is active at a time.

### Step 4: Integration Test

Run the local-dev guide checks:

```powershell
make backend-test
pytest tests/test_model_service_real.py -v
```

What this command block does:

- `make backend-test` runs the backend test target through the root Makefile.
- `pytest tests/test_model_service_real.py -v` runs the real model-service tests directly with verbose output.
- These checks prove the copied checkpoint can be loaded and used by the backend test path.

### Step 5: Shadow Deployment

Before full promotion, run shadow mode: the candidate model runs in parallel with production, predictions are logged but not shown to patients. Compare shadow outputs against current model on the frozen reference set.

---

## Gap Tracker: Research Items

These gaps are tracked in the research notebooks, not in the build guides.

### Gap #17: num_workers=0

- **What:** DataLoader uses `num_workers=0` (single-threaded loading)
- **Impact:** Training is 3-5x slower than it should be on multi-core machines
- **Where:** All RQ1-RQ5 notebooks
- **Fix:** Set `num_workers=4` (or `os.cpu_count() // 2`)
- **Verification:** Training throughput increases 3x+ on an 8-core machine
- **When fixed:** After resolving

### Gap #18: No AMP (Mixed Precision)

- **What:** Training uses full FP32, no mixed precision
- **Impact:** 2x slower training, 2x more GPU memory, risk of OOM on large batches
- **Where:** All training notebooks
- **Fix:** Wrap forward/backward pass in `torch.cuda.amp.autocast()` and use `GradScaler`
- **Verification:** Training speedup visible, no OOM on batch_size=32 with ResNet50
- **When fixed:** After resolving

### Gap #19: Model Undertrained (2 Epochs)

- **What:** Models have only been trained for 2 epochs
- **Impact:** Accuracy is far below potential; models are essentially random at 2 epochs on HAM10000
- **Where:** All model checkpoints in `ml/outputs/models/`
- **Fix:** Train for minimum 15 epochs with early stopping on validation loss
- **Verification:** Validation accuracy > 80% (vs ~50% at 2 epochs, ~70% at 10 epochs)
- **When fixed:** After resolving

---

## Model Promotion Gate (product/17)

The promotion gate in `product/17_TRAINING_PIPELINE_MODEL_REGISTRY_HANDHOLDING.md` requires ALL of the following before a model can be promoted to production:

| Gate ID | Condition | Pass criteria |
|---------|-----------|---------------|
| G-1 | Accuracy on frozen reference set | > 80% binary accuracy |
| G-2 | Sensitivity (malignant recall) | > 85% recall on MEL+BCC+AK classes |
| G-3 | Specificity (benign recall) | > 75% recall on NV+BKL+DF+VASC classes |
| G-4 | Calibration quality | ECE (Expected Calibration Error) < 0.05 |
| G-5 | Heatmap quality | > 90% of reference set heatmaps pass quality check |
| G-6 | Fairness per Fitzpatrick | No subgroup AUC gap > 0.10 across Types I-VI |
| G-7 | num_workers fix | Verified in training config |
| G-8 | AMP enabled | Verified in training script |
| G-9 | Epochs trained | >= 15 epochs on full training set |
| G-10 | Model card complete | All fields filled, signed off |

If any gate fails, the model is rejected. Do not promote a model that fails any gate.

---

## Model Card Template

For every model promoted from research to backend, fill this card:

```markdown
# Model Card: Skin Lesion Binary Classifier

## Model Identity
- **Name:** ResNet50 Binary (skin lesion)
- **Version:** v1.0.0
- **Date:** [DATE]
- **Researcher:** [NAME]
- **Promotion gate pass:** G-1 through G-10 all pass (Y/N)

## Training Configuration
- **Architecture:** ResNet50 (end-to-end fine-tuned)
- **Input size:** 224x224x3
- **Epochs trained:** [N]
- **Batch size:** [N]
- **Optimizer:** [NAME]
- **Learning rate:** [LR]
- **Mixed precision (AMP):** [YES/NO]
- **DataLoader num_workers:** [N]
- **HAM10000 train/val/test split:** [N]/[N]/[N]

## Performance on Frozen Reference Test Set
| Metric | Value |
|--------|-------|
| Binary accuracy | [X%] |
| Malignant sensitivity | [X%] |
| Benign specificity | [X%] |
| AUC-ROC | [X.XXX] |
| ECE (calibration) | [X.XXX] |
| PPV at 90% sensitivity | [X%] |

## Fairness Metrics (Fitzpatrick Subgroups)
| Subgroup | AUC | Count |
|----------|-----|-------|
| Type I-II | [X.XXX] | [N] |
| Type III-IV | [X.XXX] | [N] |
| Type V-VI | [X.XXX] | [N] |
| Max gap | [X.XXX] | - |

## Heatmap Quality
- Method: GradCAM++ targeting layer4[-1]
- Quality pass rate (frozen reference): [X]%
- Target layer rationale: [REASON]

## Known Issues
- Gap #17 (num_workers): [RESOLVED/OPEN]
- Gap #18 (AMP): [RESOLVED/OPEN]
- Gap #19 (epochs): [RESOLVED/OPEN]
- Other: [LIST]

## Safety & Compliance
- Framing: Educational AI-supported tool, NOT diagnostic device
- Training data: HAM10000 (dermoscopic, mixed Fitzpatrick)
- Geographic coverage: [LIMITED/GLOBAL -- note distribution]
- Not validated for: [specific populations not in HAM10000]

## Artifact Checksums
- Model checkpoint: SHA256=[HASH]
- Training config: SHA256=[HASH]
- Validation results: SHA256=[HASH]

## Sign-off
- Researcher: _________________ Date: _______
- Technical reviewer: _________________ Date: _______
- Clinical reviewer (if applicable): _________________ Date: _______
```

What this model-card template does:

- The `Model Identity` section records name, version, date, researcher, and promotion-gate status.
- `Training Configuration` records architecture, input shape, epochs, optimizer, learning rate, AMP use, worker count, and dataset split.
- `Performance on Frozen Reference Test Set` records repeatable metrics that can be compared across models.
- `Fairness Metrics` records subgroup behavior so one group is not hidden by average performance.
- `Heatmap Quality` records the explanation method and pass rate, not only classification accuracy.
- `Known Issues` keeps gap status visible.
- `Safety & Compliance` records the educational/non-diagnostic framing and data limitations.
- `Artifact Checksums` records hashes so model files and configs can be verified later.
- `Sign-off` makes promotion an explicit review step instead of an accidental file copy.

---

## Calibration Crossing Phase Boundaries

The calibration guide (local-dev/14_CONFIDENCE_CALIBRATION_HANDHOLDING.md) is in the local-dev phase, but calibration is fitted in the research phase and applied in the product phase. The bridge is:

1. **Research (notebooks):** Fit temperature scaling on validation set. Record in `calibration_results.json`. Update model card.
2. **Local-dev:** `ModelService` loads temperature from `models/skin_lesion_classifier.pth` metadata (or a companion `calibration_config.json`). Default temperature = 1.5 if not fitted.
3. **Product:** Temperature is logged in MLflow and can be updated without retraining. Shadow mode validates new temperature before full deployment.
4. **Monitoring:** Calibration is recomputed after every retraining cycle. Drift in ECE triggers retraining alert.

---

## Questions You Should Be Able to Answer

1. What are the 3 gaps tracked in the research notebooks and what are their fixes?
2. What is the promotion gate and how many conditions must a model pass before deployment?
3. Why is it important to validate heatmap quality on the frozen reference set before promoting a model?
4. What is the path for a notebook experiment to become a production model?
5. Why does the calibration temperature need to be tracked in the model card?
