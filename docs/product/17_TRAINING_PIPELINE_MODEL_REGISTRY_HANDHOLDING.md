# Training Pipeline And Model Registry Handholding Guide

Use this after consent, doctor validation, admin approval, training bucket rules, and local model inference work.

The main workspace root has:

```text
run_training.py
```

**What this file is:** an existing notebook-oriented training helper at `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\run_training.py`. It is not inside the research repo. This guide adds versioning, MLflow tracking, and a formal promotion step inside `Skin_Lesion_XAI_research/`.

The former `infra/terraform/modules/s3-training` module was removed after its bucket/prefix ideas were integrated into the staging storage guide. That removed module was not a complete training pipeline.

## Goal

Build this workflow:

```text
approved training cases -> versioned dataset manifest -> training run -> evaluation report -> model artifact -> model registry -> explicit promotion
```

**What this workflow means:** each step is a gate before the next. `approved training cases` means only data with consent, doctor validation, and admin approval is used. `versioned dataset manifest` is a CSV that records exactly which cases were in a training run. `model registry` is MLflow - it links the artifact, the run ID, and the metrics so nothing is lost. `explicit promotion` means a human must run a script to move a model to production - it never happens automatically.

Why: model promotion must be reproducible, reviewable, and tied to approved training data instead of a loose model file.

Do not train on raw uploaded data unless consent, doctor validation, and admin approval are complete.

## Command Location

Start from the repo root:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification
```

**What this does:** moves to the main workspace root so subsequent `cd` commands reference sibling repos correctly.

Research/training code belongs in:

```text
Skin_Lesion_XAI_research
```

**What this means:** training scripts, dataset manifests, model outputs, and MLflow runs live in the research repo. They do not belong in the backend repo.

Backend model-loading contracts belong in:

```text
Skin_Lesion_Classification_backend
```

**What this means:** the backend needs a `ModelService` or equivalent that loads the promoted model from MLflow (or from a local `.pth` file during development). That code lives in the backend repo, not the research repo.

## Repo And File Map

- Main workspace: `C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification`
- Research repo: `Skin_Lesion_XAI_research/`
- Backend repo: `Skin_Lesion_Classification_backend/`
- Create or edit training scripts, manifests, model cards, and experiment outputs under `Skin_Lesion_XAI_research/`.
- Create or edit backend model-loading code only under `Skin_Lesion_Classification_backend/` when the step gives a backend path.

## Parameters You Must Set First

```text
DATASET_VERSION=dataset-v001
MODEL_NAME=skin-lesion-resnet50
MODEL_VERSION=model-v001
TRAINING_BUCKET_PREFIX=approved/
REGISTRY_BACKEND=local-files-first
FUTURE_REGISTRY=MLflow Model Registry
MIN_TEST_AUC=0.85
PROMOTION_APPROVER_ROLE=research_reviewer
```

**What these parameters mean:**

- `DATASET_VERSION=dataset-v001` - a version slug you assign to this specific dataset. Use it to name the manifest CSV file and reference it in training runs.
- `MODEL_NAME=skin-lesion-resnet50` - the MLflow experiment name. All training runs for this model family go under this name.
- `MODEL_VERSION=model-v001` - a version label for this specific training run's output. Used for output directory names and model card metadata.
- `TRAINING_BUCKET_PREFIX=approved/` - the S3 prefix where approved training images live. Training should only read from this prefix, never from raw uploads.
- `REGISTRY_BACKEND=local-files-first` - during development, model artifacts are stored locally. Move to a hosted MLflow instance for staging and production.
- `FUTURE_REGISTRY=MLflow Model Registry` - the destination for model version tracking once the MLflow server is provisioned.
- `MIN_TEST_AUC=0.85` - the minimum AUC on the test set required before a model can be promoted. Below this threshold, the promotion script raises an error.
- `PROMOTION_APPROVER_ROLE=research_reviewer` - only a user with this role is authorised to run the promotion script. The role is enforced at the application level, not the script level.

## Step 1: Create A Dataset Manifest

Create:

```text
Skin_Lesion_XAI_research/manifests/dataset-v001.csv
```

**What this file is:** the versioned record of every image used in this training run. It is a source of truth - if you need to reproduce or audit a training run, this CSV tells you exactly which cases were included and what their approval status was.

Columns:

```text
case_id,image_key,label,consent_version,doctor_validated_at,approved_at,body_region,skin_tone_category_optional
```

**What these columns mean:**

- `case_id` - the backend case record ID. Ties the training row back to the original case for auditing.
- `image_key` - the S3 key for the de-identified image in the training bucket.
- `label` - the ground-truth class label for supervised training.
- `consent_version` - the version of the consent form the patient signed. Required for regulatory audit.
- `doctor_validated_at` - timestamp of when a doctor reviewed and validated the case.
- `approved_at` - timestamp of when an admin approved the case for training use.
- `body_region` - the lesion location. Useful for stratified analysis and fairness checks.
- `skin_tone_category_optional` - the estimated Fitzpatrick skin tone category. Used for fairness analysis across skin tones. Optional because it may not always be available.

Check:

```powershell
cd Skin_Lesion_XAI_research
python -c "import pandas as pd; df=pd.read_csv('manifests/dataset-v001.csv'); print(df.columns.tolist())"
```

**What this does:** reads the manifest CSV with pandas and prints the column names. This confirms the file exists, is valid CSV, and has the expected schema.

Expected result:

```text
Manifest has only approved training cases and no patient names or emails.
```

**What this means:** verify manually that the CSV contains no `patient_name`, `email`, or any other direct identifier. Only pseudonymised IDs and approved case metadata should appear.

## Step 2: Fix Training Loop - AMP + num_workers + Early Stopping

Before writing any new training script, fix the two biggest performance gaps from the research repo.

These fixes apply to any training script in `Skin_Lesion_XAI_research/`.

Current repo note:

```text
train_backbones.py already has OS-aware DataLoader workers, pinned memory, persistent workers, AMP, and early stopping.
train_epoch_checkpoints.py already has OS-aware DataLoader workers, pinned memory, persistent workers, and AMP.
```

**What this means:** preserve these existing implementations. Do not overwrite working training scripts merely to paste the examples below. Apply a fix only where the corresponding optimization is missing.

**Fix 1: num_workers** - change all DataLoader calls from `num_workers=0` to:

File path example:

```text
Skin_Lesion_XAI_research/scripts/train_model.py
```

**What this file is:** the training script where the DataLoader is defined. Apply the `num_workers` fix to every DataLoader in this file.

```python
import os

# On Windows use 0 in notebooks; on Linux (EC2/ECS) use 4
NUM_WORKERS = 0 if os.name == "nt" else 4

train_loader = torch.utils.data.DataLoader(
    train_dataset,
    batch_size=32,
    shuffle=True,
    num_workers=NUM_WORKERS,
    pin_memory=torch.cuda.is_available(),  # faster CPU-to-GPU transfer
    persistent_workers=NUM_WORKERS > 0,
)
```

**What this code does:**

- `NUM_WORKERS = 0 if os.name == "nt" else 4` - Windows does not support forked worker processes for DataLoader, so `num_workers` must be 0 on Windows. On Linux (EC2, ECS, EKS nodes) use 4 workers for parallel data loading.
- `pin_memory=torch.cuda.is_available()` - pins tensors to CPU memory for faster transfer to the GPU. Only useful when a CUDA GPU is present.
- `persistent_workers=NUM_WORKERS > 0` - keeps worker processes alive between epochs instead of spawning new ones each time. Reduces epoch startup time when `num_workers > 0`.

Why: `num_workers=0` means the main process loads every batch synchronously.
On Linux with 4 workers you get 20-40% faster epoch time.

**Fix 2: AMP (Automatic Mixed Precision)** - wrap your training loop:

```python
from torch.cuda.amp import GradScaler, autocast

scaler = GradScaler(enabled=torch.cuda.is_available())

for epoch in range(max_epochs):
    model.train()
    for images, labels in train_loader:
        images = images.to(device)
        labels = labels.to(device).float().unsqueeze(1)

        optimizer.zero_grad()

        with autocast(enabled=torch.cuda.is_available()):  # FP16 forward pass
            logits = model(images)
            loss = criterion(logits, labels)

        scaler.scale(loss).backward()   # scaled backward pass
        scaler.step(optimizer)          # unscale + optimizer step
        scaler.update()
```

**What this code does:**

- `from torch.cuda.amp import GradScaler, autocast` - imports PyTorch's automatic mixed precision tools.
- `GradScaler(enabled=torch.cuda.is_available())` - manages loss scaling to prevent float16 underflow during the backward pass. Disabled automatically on CPU.
- `with autocast(enabled=...)` - runs the forward pass in float16 where safe. PyTorch automatically determines which ops to run in float16 vs float32.
- `scaler.scale(loss).backward()` - scales the loss before the backward pass to prevent gradients from becoming zero in float16.
- `scaler.step(optimizer)` - unscales the gradients before the optimizer step and skips the step if any gradients are inf or NaN.
- `scaler.update()` - updates the scale factor for the next iteration.

Why: AMP halves GPU memory usage and gives 20-30% speedup on RTX 4070.
The scaler handles the float16/float32 conversion transparently.

**Fix 3: Early Stopping** - add this class to your training script:

```python
class EarlyStopping:
    """
    Stop training when val_auc stops improving.
    Saves the best checkpoint automatically.
    """

    def __init__(self, patience: int = 5, min_delta: float = 0.001, checkpoint_path: str = "best_model.pth") -> None:
        self.patience = patience
        self.min_delta = min_delta
        self.checkpoint_path = checkpoint_path
        self.best_score: float = -1.0
        self.counter: int = 0
        self.should_stop: bool = False

    def step(self, val_auc: float, model: torch.nn.Module) -> None:
        if val_auc > self.best_score + self.min_delta:
            self.best_score = val_auc
            self.counter = 0
            torch.save(model.state_dict(), self.checkpoint_path)
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.should_stop = True

# Usage in training loop:
stopper = EarlyStopping(patience=5, checkpoint_path="outputs/model-v001/best.pth")
for epoch in range(20):
    # ... train one epoch ...
    val_auc = evaluate(model, val_loader)
    stopper.step(val_auc, model)
    if stopper.should_stop:
        print(f"Early stopping at epoch {epoch}, best val_auc: {stopper.best_score:.4f}")
        break
```

**What this class does:**

- `patience=5` - how many consecutive epochs without improvement before training stops.
- `min_delta=0.001` - the minimum improvement required to reset the patience counter. Prevents stopping on noise.
- `self.best_score = -1.0` - initialised to a value below any realistic AUC so the first epoch always counts as an improvement.
- `torch.save(model.state_dict(), self.checkpoint_path)` - saves the model weights whenever a new best score is reached. This means the best checkpoint is always on disk, not just the final epoch.
- `self.should_stop = True` - signals the training loop to exit cleanly when patience runs out.

Target: run for 15-20 epochs (not 2). With early stopping, training will halt when the model stops improving. Expected best val_AUC: 0.91-0.93 (vs 0.85 at 2 epochs).

## Step 3: Create The Versioned Training Script

Create `Skin_Lesion_XAI_research/scripts/train_model.py`:

```python
"""
Versioned training wrapper.
Usage:
  python scripts/train_model.py \
    --dataset-manifest manifests/dataset-v001.csv \
    --model-name skin-lesion-resnet50 \
    --model-version model-v001 \
    --output-dir outputs/model-v001 \
    --epochs 20 \
    --mlflow-tracking-uri http://localhost:5000
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import mlflow
import mlflow.pytorch
import torch
import torch.nn as nn
import torchvision.models as tv_models
from sklearn.metrics import roc_auc_score
from torch.cuda.amp import GradScaler, autocast

# -- reuse the dataloader and dataset classes from the research notebooks --
# from notebooks.utils import HAM10000Dataset, get_transforms
# For now, assume these are importable from the research repo.


class EarlyStopping:
    """
    Stop training when val_auc stops improving.
    Saves the best checkpoint automatically.
    """

    def __init__(self, patience: int = 5, min_delta: float = 0.001, checkpoint_path: str = "best_model.pth") -> None:
        self.patience = patience
        self.min_delta = min_delta
        self.checkpoint_path = checkpoint_path
        self.best_score: float = -1.0
        self.counter: int = 0
        self.should_stop: bool = False

    def step(self, val_auc: float, model: torch.nn.Module) -> None:
        if val_auc > self.best_score + self.min_delta:
            self.best_score = val_auc
            self.counter = 0
            torch.save(model.state_dict(), self.checkpoint_path)
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.should_stop = True


def build_model(device: torch.device) -> nn.Module:
    net = tv_models.resnet50(weights=tv_models.ResNet50_Weights.IMAGENET1K_V2)
    net.fc = nn.Linear(net.fc.in_features, 1)
    return net.to(device)


def train_one_epoch(model, loader, optimizer, criterion, scaler, device) -> float:
    model.train()
    total_loss = 0.0
    for images, labels in loader:
        images, labels = images.to(device), labels.to(device).float().unsqueeze(1)
        optimizer.zero_grad()
        with autocast(enabled=device.type == "cuda"):
            loss = criterion(model(images), labels)
        scaler.scale(loss).backward()
        scaler.step(optimizer)
        scaler.update()
        total_loss += loss.item()
    return total_loss / len(loader)


def evaluate(model, loader, device) -> float:
    model.eval()
    all_probs, all_labels = [], []
    with torch.no_grad():
        for images, labels in loader:
            images = images.to(device)
            probs = torch.sigmoid(model(images)).cpu().squeeze().tolist()
            all_probs.extend(probs if isinstance(probs, list) else [probs])
            all_labels.extend(labels.tolist())
    return float(roc_auc_score(all_labels, all_probs))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset-manifest", required=True)
    parser.add_argument("--model-name", required=True)
    parser.add_argument("--model-version", required=True)
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--mlflow-tracking-uri", default="http://localhost:5000")
    args = parser.parse_args()

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    # -- Wire up your dataset here from the manifest CSV --
    # train_loader, val_loader, test_loader = load_from_manifest(args.dataset_manifest)

    mlflow.set_tracking_uri(args.mlflow_tracking_uri)
    mlflow.set_experiment(args.model_name)

    with mlflow.start_run(run_name=args.model_version):
        mlflow.log_param("model_version", args.model_version)
        mlflow.log_param("dataset_manifest", args.dataset_manifest)
        mlflow.log_param("epochs", args.epochs)

        model = build_model(device)
        pos_weight = torch.tensor([5.25]).to(device)   # HAM10000 class imbalance ratio
        criterion = nn.BCEWithLogitsLoss(pos_weight=pos_weight)
        optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4, weight_decay=1e-4)
        scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
        scaler = GradScaler(enabled=device.type == "cuda")
        stopper = EarlyStopping(patience=5, checkpoint_path=str(output_dir / "best.pth"))

        for epoch in range(args.epochs):
            # train_loss = train_one_epoch(model, train_loader, optimizer, criterion, scaler, device)
            # val_auc = evaluate(model, val_loader, device)
            # mlflow.log_metrics({"train_loss": train_loss, "val_auc": val_auc}, step=epoch)
            # stopper.step(val_auc, model)
            # scheduler.step()
            # if stopper.should_stop:
            #     break
            pass  # replace pass with the above when loaders are ready

        # Save final checkpoint and log to MLflow
        final_ckpt = str(output_dir / "model.pth")
        torch.save(model.state_dict(), final_ckpt)
        mlflow.pytorch.log_model(model, artifact_path="model")

        # test_auc = evaluate(model, test_loader, device)
        test_auc = 0.0   # replace when test_loader is wired
        mlflow.log_metric("test_auc", test_auc)

        card = {
            "model_name": args.model_name,
            "model_version": args.model_version,
            "dataset_manifest": args.dataset_manifest,
            "metrics": {"test_auc": test_auc},
            "approved_for_production": False,
        }
        card_path = output_dir / "model-card.json"
        card_path.write_text(json.dumps(card, indent=2))
        mlflow.log_artifact(str(card_path))

        print(f"Training complete. test_auc={test_auc:.4f}")
        print(f"MLflow run ID: {mlflow.active_run().info.run_id}")


if __name__ == "__main__":
    main()
```

**What this script does:**

- `EarlyStopping(...)` - includes the Step 2 class in this file so the wrapper does not reference an undefined name.
- `build_model(device)` - loads ResNet-50 with ImageNet pretrained weights and replaces the final fully-connected layer with a single output for binary classification (malignant vs benign).
- `net.fc = nn.Linear(net.fc.in_features, 1)` - replaces the 1000-class ImageNet head with a single output neuron. Combined with `BCEWithLogitsLoss`, this trains a binary classifier.
- `train_one_epoch(...)` - runs one full pass through the training dataset. Returns average loss per batch.
- `evaluate(...)` - runs inference on the validation or test loader, collects all probabilities and labels, and returns the AUC score.
- `torch.sigmoid(model(images))` - converts raw logits to probabilities in the 0-1 range for AUC calculation.
- `mlflow.start_run(run_name=args.model_version)` - opens an MLflow tracking context. All params, metrics, and artifacts logged inside this block are associated with this run.
- `mlflow.log_param(...)` - records hyperparameters. These appear in the MLflow UI and let you compare runs.
- `pos_weight = torch.tensor([5.25])` - compensates for the class imbalance in HAM10000 where benign cases outnumber malignant by roughly 5:1. Increases the loss contribution from the minority class.
- `CosineAnnealingLR` - a learning rate scheduler that smoothly reduces the learning rate from its initial value down to near zero over the training run. Helps find a better final minimum.
- `mlflow.pytorch.log_model(model, artifact_path="model")` - saves the model weights and the PyTorch model format to the MLflow artifact store, making it loadable later with `mlflow.pytorch.load_model(...)`.
- `approved_for_production: False` - the model card starts with this field as false. It must be changed to true by a reviewer before the promotion script will accept the model.

Check:

```powershell
cd Skin_Lesion_XAI_research
python scripts/train_model.py --help
```

**What this does:** runs the script with `--help` to confirm it parses arguments correctly and all imports resolve without errors. If an import fails (e.g., `mlflow` not installed), the error appears here.

Expected: argument list printed.

## Step 4: MLflow Server + Model Promotion

**Local MLflow server** (before staging - see `docs/staging/21_MLFLOW_SERVER_HANDHOLDING.md` for the full guide):

```powershell
cd Skin_Lesion_XAI_research
.\skin-lesion-env\Scripts\python.exe -m pip install -r requirements.txt
.\skin-lesion-env\Scripts\mlflow.exe server --host 0.0.0.0 --port 5000
# open http://localhost:5000 in a browser
```

**What this does:** installs the tracked research dependencies, including `mlflow==3.12.0`, and starts a local tracking server on port 5000. The server stores run metadata and artifacts in the current directory by default. Open `http://localhost:5000` in a browser to see the MLflow UI with your experiments and runs.

**Register and promote a model after training:**

```python
# Run this after training completes and test_auc >= MIN_TEST_AUC (0.85)
import mlflow
from mlflow.tracking import MlflowClient

TRACKING_URI = "http://localhost:5000"
MODEL_NAME = "skin-lesion-resnet50"
MIN_TEST_AUC = 0.85

mlflow.set_tracking_uri(TRACKING_URI)
client = MlflowClient()

# Find the best run for this model name
runs = mlflow.search_runs(
    experiment_names=[MODEL_NAME],
    order_by=["metrics.test_auc DESC"],
    max_results=1,
)

if runs.empty:
    raise RuntimeError("No runs found. Run train_model.py first.")

best_run = runs.iloc[0]
test_auc = best_run["metrics.test_auc"]
run_id = best_run["run_id"]

print(f"Best run: {run_id}, test_auc: {test_auc:.4f}")

if test_auc < MIN_TEST_AUC:
    raise ValueError(f"test_auc {test_auc:.4f} < minimum {MIN_TEST_AUC}. Do not promote.")

# Register
result = mlflow.register_model(f"runs:/{run_id}/model", MODEL_NAME)
model_version = result.version
print(f"Registered as version {model_version}")

# Assign the production alias (requires human sign-off in a real pipeline)
client.set_registered_model_alias(
    name=MODEL_NAME,
    alias="champion",
    version=model_version,
)
print(f"Assigned {MODEL_NAME} v{model_version} to @champion")
```

**What this script does:**

- `mlflow.search_runs(experiment_names=[MODEL_NAME], order_by=["metrics.test_auc DESC"])` - queries the MLflow tracking server for all runs under this experiment name, sorted by test AUC descending. The first result is the best run.
- `if test_auc < MIN_TEST_AUC: raise ValueError(...)` - the promotion gate. If the best run did not reach the minimum AUC threshold, the script refuses to register the model. This is the automated quality check.
- `mlflow.register_model(f"runs:/{run_id}/model", MODEL_NAME)` - creates a registered model version in the MLflow Model Registry. Links the artifact from the training run to a named, versioned entry.
- `client.set_registered_model_alias(alias="champion", version=model_version)` - points the stable `@champion` alias at the reviewed model version. MLflow stages such as `Production` are deprecated; aliases are the supported replacement. Reassigning `@champion` also provides a simple rollback path.

Save this as `Skin_Lesion_XAI_research/scripts/promote_model.py` and run it only after research_reviewer role approves.

**Load promoted model in the backend:**

```python
# In app/services/model_service.py - alternative to local .pth file
import mlflow.pytorch

def load_from_registry(model_name: str = "skin-lesion-resnet50", alias: str = "champion"):
    mlflow.set_tracking_uri(os.environ["MLFLOW_TRACKING_URI"])
    model = mlflow.pytorch.load_model(f"models:/{model_name}@{alias}")
    model.eval()
    return model
```

**What this function does:** loads the currently promoted model through the MLflow alias `models:/skin-lesion-resnet50@champion`. Reassigning the alias makes the backend load the reviewed version on the next restart. `model.eval()` puts the model in inference mode, which disables dropout and uses running stats for batch norm instead of batch statistics.

## Step 5: Save Model Metadata

Every artifact gets a model card. The training script above creates it automatically.
Verify it was written:

```powershell
cd Skin_Lesion_XAI_research
python -c "import json; card=json.load(open('outputs/model-v001/model-card.json')); print(card['model_version'], card['metrics'])"
```

**What this does:** reads the model card JSON file that the training script wrote and prints the version string and metrics dictionary. This confirms the file exists and was written correctly. If the file is missing or malformed, Python raises a `FileNotFoundError` or `json.JSONDecodeError`.

Expected: version string and metrics dict printed.

## Completion Gate

Training pipeline is complete when:

```text
- dataset manifest is versioned (no patient names/emails)
- training runs for 15-20 epochs with AMP + early stopping
- val_AUC reported per epoch in MLflow
- model artifact has model-card.json with test_auc
- test_auc >= 0.85 before promotion
- promotion is explicit - human runs promote_model.py
- backend ModelService can load by alias="champion"
- rollback = reassign `@champion` to the previous reviewed model version
```

**What this completion gate means:** each bullet is a requirement, not a suggestion. `versioned manifest` means the CSV is committed to the research repo with no patient identifiers. `AMP + early stopping` means the optimisation fixes from Step 2 are in place. `val_AUC per epoch in MLflow` means you can graph the learning curve in the UI. `model-card.json` means the artifact is documented. `promotion is explicit` means the automation never promotes a model without a human running the script. `rollback` means if the new production model performs worse, you reassign `@champion` to the previous reviewed model version.

## Concepts You Just Touched

- [Model Registry (9.1)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#91-model-registry) - version + alias + artifact path as one atomic unit
- [Shadow Deployment (9.4)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#94-shadow-deployment) - design space: test new model on a shadow traffic % before full promotion
- [Calibration (9.3)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#93-calibration) - temperature must be re-fit after every retraining run
- [Drift Detection (9.5)](../reference/09_SYSTEM_DESIGN_PATTERNS.md#95-drift-detection) - compare activation distributions old vs new model before promotion

## Questions You Should Be Able To Answer

1. Why should `@champion` be reassigned only after human review? How does alias reassignment support rollback?
2. What is the minimum test_auc gate set to, and why is 0.85 not good enough for the malignant class specifically?
3. AMP uses float16 for the forward pass. Why do you still use float32 for the loss and parameter updates?
4. Early stopping uses patience=5 with min_delta=0.001. If val_auc plateaus at 0.91 for 5 epochs, training stops. Is that the right behaviour for this project?
5. The training script's loaders are commented out with `# replace`. What three things do you need to implement to make the script fully runnable end to end?

## Cost Pause / Resume

If this guide created or uses cloud resources, pause or shut them down before stopping for the day.

Run from the repo root:

```powershell
make cloud-status ENV=dev
make cloud-pause ENV=dev
make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES
```

**What this command block does:**

- `make cloud-status ENV=dev` reports the current state of all dev cloud resources.
- `make cloud-pause ENV=dev` pauses pausable resources to reduce cost without destroying state.
- `make cloud-shutdown ENV=dev CONFIRM_DESTROY=YES` destroys the dev environment. Requires explicit confirmation flag.

Use `ENV=staging` or `ENV=prod` only when you are intentionally working in that environment.

Before starting the next guide, resume the environment and re-run the guide's check command:

```powershell
make cloud-start ENV=dev
make cloud-status ENV=dev
```

**What this command block does:**

- `make cloud-start ENV=dev` creates or resumes the dev environment.
- `make cloud-status ENV=dev` confirms all resources are healthy before beginning work.

If this guide was local-only, no cloud shutdown is needed.
