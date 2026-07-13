# Domain Primer: Skin Lesion GRADCAM Classification

This document is required reading before you touch any model code, Grad-CAM implementation, or clinical feature.

---

## What Is HAM10000

HAM10000 (Human Against Machine with 10000 training images) is the dataset behind the ISIC (International Skin Imaging Collaboration) challenge. It contains 10,015 dermoscopic images of skin lesions collected from multiple institutions.

- **Source:** Tschandl et al. (2018), "The HAM10000 Dataset, a Large Collection of Multi-Source Dermoscopic Images of Common Pigmented Skin Lesions"
- **Image size:** 600x450 pixels, RGB
- **Modality:** Dermoscopic (skin surface microscopy with oil immersion)
- **Task:** 7-class classification of pigmented skin lesions

---

## The 7 ISIC Classes

The HAM10000 taxonomy splits lesions into two groups:

### Melanocytic (derived from melanocytes):

| Code | Full name | Clinical concern |
|------|-----------|-----------------|
| MEL | Melanoma | Malignant -- most dangerous skin cancer |
| NV | Dermal Nevus | Benign -- common mole |

### Non-melanocytic:

| Code | Full name | Clinical concern |
|------|-----------|-----------------|
| BCC | Basal Cell Carcinoma | Malignant -- most common, slow-growing |
| AK | Actinic Keratosis | Pre-malignant -- can progress to SCC |
| BKL | Benign Lichenoid Keratosis | Benign |
| DF | Dermatofibroma | Benign |
| VASC | Vascular Lesion | Benign |

---

## Class Distribution

HAM10000 is heavily imbalanced:

| Class | Approx. count | Approx. % |
|-------|--------------|-----------|
| NV (benign) | ~6,700 | ~67% |
| MEL (malignant) | ~1,100 | ~11% |
| BCC (malignant) | ~500 | ~5% |
| BKL (benign) | ~500 | ~5% |
| AK (pre-malignant) | ~300 | ~3% |
| DF (benign) | ~500 | ~5% |
| VASC (benign) | ~400 | ~4% |

The dominance of NV (benign nevi) creates a class imbalance problem: a model that always predicts benign would be ~70% accurate but clinically useless.

---

## Benign vs Malignant Binary Mapping

For the GRADCAM classification project, the 7 classes collapse to a binary task:

```
MALIGNANT:  MEL, BCC, AK  (3 classes, ~19% of data)
BENIGN:    NV, BKL, DF, VASC  (4 classes, ~81% of data)
```

What this mapping block means:

- `MALIGNANT` is the positive-risk group used by this binary classifier.
- `MEL` means melanoma.
- `BCC` means basal cell carcinoma.
- `AK` means actinic keratosis, which is pre-malignant but grouped with higher-risk lesions for this educational binary task.
- `BENIGN` is the lower-risk group used by this binary classifier.
- `NV`, `BKL`, `DF`, and `VASC` are grouped as benign classes for this project.
- The percentages show that the dataset is imbalanced: the benign group is much larger than the malignant/pre-malignant group.

**Clinical note:** This mapping is explicit. AK (actinic keratosis) is pre-malignant. BCC is malignant but rarely fatal. The project frames itself as educational.

---

## Clinical Significance: False Negatives vs False Positives

| Error type | What happens | Clinical consequence |
|-----------|--------------|---------------------|
| False negative (malignant predicted benign) | Patient with melanoma told likely benign | Delayed treatment -- potentially life-threatening |
| False positive (benign predicted malignant) | Patient with nevus told concerning | Unnecessary anxiety, possible unnecessary biopsy |

The project prioritises sensitivity (recall on malignant class) as a primary metric. See product/12.

---

## What Is the Fitzpatrick Scale

The Fitzpatrick scale classifies skin color response to UV exposure:

| Type | Description | Tanning ability |
|------|-------------|-----------------|
| I | Very fair, always burns | Never tans |
| II | Fair, burns easily | Tans with difficulty |
| III | Medium, burns moderately | Tans uniformly |
| IV | Olive, burns minimally | Tans easily |
| V | Brown, rarely burns | Tans very easily |
| VI | Dark, very rarely burns | Deeply pigmented |

**Why it matters:** Most training data (HAM10000) skews toward Type I-III. Models often perform worse on Type V-VI. The project tracks fairness per Fitzpatrick bucket in product/12.

---

## What Is Grad-CAM in Clinical Context

Grad-CAM (Gradient-weighted Class Activation Mapping) produces a heatmap overlay showing which image regions contributed most to the prediction.

**In this project, Grad-CAM is a clinical evidence artifact -- NOT a diagnosis tool.**

The heatmap is what a dermatologist uses to verify the model's reasoning. If the model predicts malignant but the heatmap activates on healthy skin (not the lesion), the prediction is untrustworthy.

See 04_GRADCAM_CLINICAL_INTERPRETATION.md for clinical heatmap interpretation.

---

## The Mental Model: Educational AI-Supported Tool

This platform is an **educational AI-supported tool for monitoring skin lesions**. It is **NOT a diagnostic device**.

The prediction is supporting evidence. The Grad-CAM heatmap is the deliverable that lets a clinician verify the reasoning.

Every design and build decision flows from this framing:
- LLM explanation refuses diagnosis language (product/06)
- UI never says "You have melanoma"
- Confidence is temperature-scaled before display
- Clinical escalation path is defined for high-confidence malignant predictions

---

## Where to Learn More

| Topic | Where |
|-------|-------|
| Research notebooks, RQ1-RQ5 | Skin_Lesion_XAI_research/notebooks/ |
| Grad-CAM implementation | local-dev/06_MODEL_AND_GRADCAM_HANDHOLDING.md |
| Grad-CAM clinical interpretation | 04_GRADCAM_CLINICAL_INTERPRETATION.md |
| Fairness monitoring | product/12_RESEARCH_FAIRNESS_MONITORING_HANDHOLDING.md |
| System design patterns | reference/09_SYSTEM_DESIGN_PATTERNS.md |

---

## Questions You Should Be Able to Answer

1. Why does NV (dermal nevus) dominate ~70% of HAM10000 and why does this affect how we evaluate model accuracy?
2. Why is a false negative malignant prediction more clinically dangerous than a false positive benign prediction?
3. Why might a model trained on HAM10000 perform worse on darker skin tones (Fitzpatrick V-VI)?
4. What does it mean that this platform is "an educational tool, not a diagnostic device"?
5. Why does a dermatologist need the Grad-CAM heatmap in addition to the model prediction?
