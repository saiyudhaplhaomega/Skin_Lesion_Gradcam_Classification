# Grad-CAM Clinical Interpretation Guide

Use this alongside local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md when you want to understand what the heatmap actually tells a clinician.

---

## What Is Grad-CAM++

Grad-CAM++ is an improved version of vanilla Grad-CAM. It produces better localisation for multiple occurrences of the same class and is more faithful to the model's actual reasoning.

| Method | When to use |
|--------|-------------|
| GradCAM | Baseline, general purpose |
| GradCAM++ | **This project** -- better for multiple-instance localisation |
| ScoreCAM | Activation-free, but slower and less faithful |
| AblationCAM | High fidelity, but requires model surgery |

The project uses GradCAM++ targeting `layer4[-1]` on ResNet50 (the final convolutional block). This target layer was validated in the RQ1 research notebooks.

---

## What the Heatmap Shows

The heatmap overlays a colour gradient on the input image:
- **Red/yellow zones:** Regions that contributed most to the prediction
- **Blue/green zones:** Regions that contributed negatively (or were ignored)

For a correct prediction, the red zone should overlap with the lesion itself, not surrounding healthy skin.

---

## What a Good Heatmap Looks Like

A clinically useful heatmap has these properties:

1. **Lesion-overlapping activations** -- The red zone covers the pigmented lesion, especially its most atypical-appearing region (e.g., asymmetric border, colour variation)
2. **Sharp boundaries** -- Activations follow the lesion's shape, not diffuse or scattered
3. **No background activation** -- Healthy skin around the lesion shows no warm colours
4. **Consistent across runs** -- The same image produces similar heatmaps (no random noise pattern)

---

## What a Bad (Noisy) Heatmap Looks Like

A noisy heatmap activates on:
- Image edges or corners
- Background skin (not the lesion)
- Artefacts (ruler marks, gel bubbles, hair)
- Random diffuse patterns across the whole image

**Why noisy heatmaps are a patient safety signal, not just a quality metric:**

If the Grad-CAM heatmap shows activation on healthy skin rather than the lesion, the model is "looking at the wrong thing." The prediction is untrustworthy -- even if the label happens to be correct, you cannot explain to a clinician WHY it is correct.

---

## Clinical Workflow: Heatmap + Prediction

The Grad-CAM heatmap is not shown in isolation. The clinical review workflow is:

```
Patient uploads image
         |
         v
Model predicts: MALIGNANT (0.97 confidence)
         |
         v
Grad-CAM heatmap generated
         |
         +--> Heatmap is CLEAN (activations on lesion)
         |    --> Clinician uses heatmap to verify reasoning
         |    --> If consistent with clinical exam, use in decision support
         |
         +--> Heatmap is NOISY (activations on healthy skin)
              --> Clinician DISREGARDS the prediction
              --> Escalate: clinical exam + dermoscopy recommended
              --> Flag case for retraining pipeline
```

What this workflow block means:

- `Patient uploads image` is the starting point: the user provides a lesion image.
- `Model predicts: MALIGNANT (0.97 confidence)` shows the model output, but this confidence must be calibrated before patient display.
- `Grad-CAM heatmap generated` adds the visual explanation layer.
- `Heatmap is CLEAN` means the warm activation region overlaps the lesion itself.
- When the heatmap is clean, the clinician may use it as decision-support evidence alongside clinical examination.
- `Heatmap is NOISY` means activation is on background, artefacts, or healthy skin.
- When the heatmap is noisy, the prediction should not be trusted as an explanation, even if the label appears plausible.
- `Flag case for retraining pipeline` means the case becomes useful evidence for model quality improvement after consent and review rules are satisfied.

---

## Target Layer Choice

For ResNet50, the project targets `layer4[-1]` (the final residual block):

```python
def get_target_layer(self) -> nn.Module:
    return self.model.layer4[-1]
```

What this code does:

- `def get_target_layer(self) -> nn.Module:` defines a method on the model wrapper that returns the neural-network layer Grad-CAM should inspect.
- `self` refers to the current model wrapper instance.
- `-> nn.Module` is a Python type hint saying this method returns a PyTorch module/layer.
- `self.model` is the wrapped ResNet50 model.
- `layer4` is ResNet50's final group of convolutional blocks.
- `[-1]` selects the last block inside `layer4`.
- Returning `self.model.layer4[-1]` tells Grad-CAM to use the final high-level convolutional features when producing the heatmap.

Why this layer:
- Deeper layers capture more semantic, class-discriminative features
- `layer4[-1]` output spatial resolution is 7x7 on a 224x224 input
- Shallower layers (e.g., `layer2`) produce more localisation detail but less semantic specificity
- The choice was validated in RQ1 research notebooks comparing faithfulness scores across layers

---

## Validating on the Frozen Reference Test Set

Gap #15: The frozen HAM10000 reference test set must be used to validate heatmap quality before any model promotion.

Run this validation after each retraining cycle:
1. Generate heatmaps for all 2,000+ reference test images
2. Compute CAM quality score (e.g., how much activation overlaps with lesion bounding box)
3. Reject the candidate model if >10% of heatmaps are classified as "noisy" on clean reference images
4. Log the validation result in MLflow before promotion gates can pass

See product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md for the full validation protocol.

---

## Connection to LLM Explanation

Both Grad-CAM and the LLM explanation must agree. The LLM explanation is generated from structured facts (see product/06_SAFE_LLM_EXPLANATION_HANDHOLDING.md), which include the Grad-CAM regions.

**Example consistency check:**
- Grad-CAM shows activation on the colour-variation region of the lesion
- LLM explanation says: "The model focused on irregular colour distribution in the central region"
- These agree -- this is a valid explanation

- Grad-CAM shows activation on background skin
- LLM explanation cites lesion features
- These disagree -- the explanation is unreliable; flag for human review

---

## Common Failure Modes

| Symptom | Cause | Clinical implication |
|---------|-------|---------------------|
| Activation on image edges | Ruler mark, gel bubble artefact | Artefact is not lesion feature |
| Diffuse activation everywhere | Undertrained model (gap #19) | Model has not learned discriminative features |
| Activation on wrong lesion (multiple lesions) | Model looking at background | Prediction is unreliable |
| Good prediction, bad heatmap | Clever hacking / shortcut learning | Model is correct for wrong reasons |
| Different heatmaps on same image | Non-deterministic inference | Check GPU vs CPU precision |

---

## Socratic Questions

1. If the model predicts malignant with 0.97 confidence but the Grad-CAM heatmap is noise, what does that tell you about the model's reliability and what should the system do?

2. Why does a dermatologist need both the prediction AND the heatmap, not just the prediction alone?

3. What does activation on healthy surrounding skin (not the lesion) indicate about the model's training or the image quality?

4. How does image quality (blur, lighting variation, different camera angles) affect heatmap reliability?

5. What is the clinical escalation path when the heatmap quality is low on a high-confidence malignant prediction?

---

## Questions You Should Be Able to Answer

1. Why is `layer4[-1]` the right target layer for ResNet50 Grad-CAM, rather than `layer2`?
2. What is the difference between Grad-CAM activations that overlap the lesion vs activations on healthy skin?
3. Who decides whether a heatmap is "good enough" and what criteria do they use?
4. Why does the model promotion gate include heatmap quality checks, not just prediction accuracy?
5. If a doctor sees a confident malignant prediction with a noisy heatmap, what should they do?

---

## Cost Pause / Resume

This guide does not create cloud resources. No pause needed.
