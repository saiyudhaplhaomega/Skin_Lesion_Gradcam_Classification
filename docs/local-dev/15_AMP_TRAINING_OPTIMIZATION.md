# AMP Training Optimization Handholding Guide

Use this before long research training runs.

This guide is now implemented in code and smoke-tested locally. It is not just a paste reference.

## Goal

Add three training optimizations to the research training scripts:

1. Platform-aware `DataLoader` workers.
2. AMP training with `GradScaler` and `autocast`.
3. Early stopping for backbone training.

Implemented files:

```text
Skin_Lesion_XAI_research/train_backbones.py
Skin_Lesion_XAI_research/train_epoch_checkpoints.py
Skin_Lesion_XAI_research/scripts/benchmark_dataloader.py
```

Generated smoke outputs are ignored by Git:

```text
Skin_Lesion_XAI_research/outputs/smoke-models/
Skin_Lesion_XAI_research/outputs/smoke-checkpoints/
```

## Command Location

Run all commands in this guide from the research repo:

```powershell
cd C:\Users\saiyu\Desktop\projects\KI_projects\Skin_Lesion_GRADCAM_Classification\Skin_Lesion_XAI_research
```

What this does: moves your terminal into the repo that owns the training scripts and the `skin-lesion-env` Python environment.

## Step 1: Confirm The Research Python Works

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe -c "import sys, torch; print(sys.executable); print(torch.__version__); print(torch.cuda.is_available())"
```

Expected result on this machine:

```text
...\Skin_Lesion_XAI_research\skin-lesion-env\Scripts\python.exe
2.6.0+cu124
True
```

What this does: proves you are using the research virtual environment, not global Python.

## Step 2: Compile The Training Scripts

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe -m py_compile train_backbones.py train_epoch_checkpoints.py scripts\benchmark_dataloader.py
```

Expected result: no output and no error.

What this does: catches syntax/import mistakes before starting a training run.

## Step 3: Benchmark DataLoader Workers

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe scripts\benchmark_dataloader.py --dataset-size 64 --workers 0 2
```

Verified result on Windows:

```text
os.name=nt
num_workers=0: 0.33s for 64 fake images
num_workers=2: 7.62s for 64 fake images
```

What this means: on this Windows machine, `num_workers=0` is faster for local smoke runs. The scripts default to:

```python
DEFAULT_NUM_WORKERS = 0 if os.name == "nt" else 4
```

Why this choice was made: Windows worker process startup is expensive. Linux/EC2 should usually use `4` workers for better throughput.

## Step 4: Check The New CLI Flags

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe train_backbones.py --help
.\skin-lesion-env\Scripts\python.exe train_epoch_checkpoints.py --help
```

Expected result: `train_backbones.py` shows these flags:

```text
--patience
--min-delta
--num-workers
--no-amp
--no-pretrained
--force
--limit-samples
--output-dir
```

Expected result: `train_epoch_checkpoints.py` shows these flags:

```text
--num-workers
--no-amp
--no-pretrained
--limit-samples
--checkpoint-dir
```

What this does: confirms the optimization code is exposed through commands you can actually run.

## Step 5: Smoke-Test AMP Backbone Training

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe train_backbones.py --models resnet50 --epochs 1 --limit-samples 4 --no-pretrained --force --output-dir outputs\smoke-models --num-workers 0
```

Verified result:

```text
Device: cuda
Models to train: ['resnet50']
Epochs: 1
Split: train=8 val=8 test=8
AMP enabled: True
DataLoader workers: 0
Epoch  1: train_loss=...  val_auc=... *
Saved: outputs\smoke-models\resnet50_best.pth
All done. Models saved to: outputs\smoke-models
```

What this does:

- Uses a tiny balanced sample so the command finishes quickly.
- Uses `--no-pretrained` so it does not download weights.
- Uses `outputs\smoke-models` so it does not overwrite real checkpoints.
- Exercises AMP, gradient scaling, gradient clipping, validation AUC, early stopping state, and checkpoint saving.

## Step 6: Smoke-Test Epoch Checkpoint Training

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe train_epoch_checkpoints.py --epochs 1 --limit-samples 4 --no-pretrained --force --checkpoint-dir outputs\smoke-checkpoints --num-workers 0
```

Verified result:

```text
Device: cuda
AMP enabled: True
DataLoader workers: 0
Saving 1 epoch checkpoints to outputs\smoke-checkpoints
Train: 8  Val: 8
pos_weight: 1.00
Epoch  1: train_loss=...  val_auc=...  -> saved resnet50_epoch01.pth
Done. 1 checkpoints saved to outputs\smoke-checkpoints
```

What this does: verifies the RQ5 checkpoint script still saves one checkpoint per epoch while using the AMP and DataLoader improvements.

## Step 7: Run Real Backbone Training

Run this only when you are ready for a real training job:

```powershell
.\skin-lesion-env\Scripts\python.exe train_backbones.py --models efficientnet_b2 mobilenetv2_100 --epochs 20 --patience 5 --min-delta 0.001 --num-workers 0
```

Use this on Linux or EC2 instead:

```bash
python train_backbones.py --models efficientnet_b2 mobilenetv2_100 --epochs 20 --patience 5 --min-delta 0.001 --num-workers 4
```

Expected result:

```text
AMP enabled: True
DataLoader workers: 0      # Windows
DataLoader workers: 4      # Linux/EC2
Epoch  1: train_loss=... val_auc=...
...
Early stopping triggered after ...
Saved: ...\ml\outputs\models\efficientnet_b2_best.pth
```

What this does: trains each backbone with AMP, tuned workers, gradient clipping, validation AUC tracking, and early stopping.

## Step 8: Run Real RQ5 Epoch Checkpoints

Run:

```powershell
.\skin-lesion-env\Scripts\python.exe train_epoch_checkpoints.py --epochs 10 --num-workers 0
```

Linux or EC2:

```bash
python train_epoch_checkpoints.py --epochs 10 --num-workers 4
```

Expected result:

```text
AMP enabled: True
Saving 10 epoch checkpoints to ...\ml\outputs\models\checkpoints
Epoch  1: ... -> saved resnet50_epoch01.pth
...
Done. 10 checkpoints saved to ...
```

What this does: keeps the RQ5 behavior of saving every epoch, while improving the training loop.

## Verify During A Long Run

In a second terminal during training, run:

```powershell
nvidia-smi --query-gpu=memory.used,memory.free --format=csv --loop=5
```

Expected result: GPU memory should stay stable. AMP should use less memory than full FP32 for the same batch size.

## What Changed In Code

`train_backbones.py` now has:

- `DEFAULT_NUM_WORKERS = 0 if os.name == "nt" else 4`
- DataLoader `pin_memory`, `persistent_workers`, and `prefetch_factor`
- `torch.amp.GradScaler`
- `torch.amp.autocast`
- `optimizer.zero_grad(set_to_none=True)`
- gradient clipping
- `EarlyStopping`
- smoke-safe `--limit-samples`, `--no-pretrained`, and `--output-dir`

`train_epoch_checkpoints.py` now has:

- platform-aware workers
- AMP training
- gradient clipping
- smoke-safe `--limit-samples`, `--no-pretrained`, and `--checkpoint-dir`

## Questions You Should Be Able To Answer

1. Why is `num_workers=0` correct on this Windows smoke run but `num_workers=4` usually better on Linux?
2. Why does AMP need `GradScaler`?
3. Why does the guide use `--no-pretrained` for smoke testing?
4. Why does `train_epoch_checkpoints.py` not use early stopping by default?
5. Why should smoke outputs stay in ignored folders?
