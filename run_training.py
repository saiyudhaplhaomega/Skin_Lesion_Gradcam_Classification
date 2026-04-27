"""
Run all cells from 00_setup_and_sanity.ipynb programmatically.
"""
import os, sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parent
NOTEBOOK_DIR = ROOT_DIR / "Skin_Lesion_XAI_research" / "notebooks"
BACKEND_DIR = Path(os.environ.get("SKIN_LESION_BACKEND_DIR", ROOT_DIR / "Skin_Lesion_Classification_backend"))
ML_DIR = BACKEND_DIR / "ml"

sys.path.insert(0, str(ML_DIR))

# Cell 1: Environment setup
print("=" * 50)
print("CELL 1: Environment Setup")
print("=" * 50)
METADATA_PATH = ML_DIR / "data" / "processed" / "metadata_with_paths.csv"
MODEL_PATH = ML_DIR / "outputs" / "models" / "resnet50_best.pth"
print(f"[OK] Backend dir:    {BACKEND_DIR.exists()}")
print(f"[OK] Metadata:       {METADATA_PATH.exists()}")
print(f"[OK] Model weights:  {MODEL_PATH.exists()}")

# Cell 3: Environment sanity check
print("\n" + "=" * 50)
print("CELL 3: Environment Sanity Check")
print("=" * 50)
import torch
print(f"torch           [OK] {torch.__version__}")
print(f"CUDA available:  {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU:            {torch.cuda.get_device_name(0)}")
    print(f"VRAM:           {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f} GB")

import timm, numpy as np, pandas as pd, matplotlib, sklearn, cv2, albumentations
print(f"timm            [OK] {timm.__version__}")
print(f"numpy           [OK] {np.__version__}")
print(f"pandas          [OK] {pd.__version__}")
print(f"matplotlib      [OK] {matplotlib.__version__}")
print(f"sklearn          [OK] {sklearn.__version__}")
print(f"cv2              [OK] {cv2.__version__}")
print(f"albumentations   [OK] {albumentations.__version__}")

# Cell 5: Data sanity check
print("\n" + "=" * 50)
print("CELL 5: Data Sanity Check")
print("=" * 50)
DATA_DIR = ML_DIR / "data" / "processed"
METADATA_PATH = DATA_DIR / "metadata_with_paths.csv"
df = pd.read_csv(METADATA_PATH)
print(f"[OK] Metadata loaded: {METADATA_PATH}")
print(f"Total images:      {len(df)}")
print(f"Unique patients:   {df['patient_id'].nunique()}")
print(f"Unique lesion types: {df['dx'].nunique()}")
print(f"\nClass distribution:")
print(df['dx'].value_counts())
print(f"\nBinary label distribution:")
print(df['label_name'].value_counts())
missing = df[df['filepath'].isna()] if 'filepath' in df.columns else pd.DataFrame()
print(f"Missing image files: {len(missing)}")

# Cell 7: Training setup
print("\n" + "=" * 50)
print("CELL 7: Training Setup")
print("=" * 50)
import torchvision.transforms as T
from torch.utils.data import Dataset, DataLoader
from PIL import Image

# Patient-level split
np.random.seed(42)
patients = df['patient_id'].unique()
np.random.shuffle(patients)
n_pts = len(patients)
train_pts = set(patients[:int(n_pts * 0.65)])
val_pts   = set(patients[int(n_pts * 0.65):int(n_pts * 0.80)])
test_pts  = set(patients[int(n_pts * 0.80):])

df['_split'] = df['patient_id'].apply(
    lambda p: 'train' if p in train_pts else ('val' if p in val_pts else 'test')
)
train_df = df[df['_split'] == 'train']
val_df   = df[df['_split'] == 'val']
test_df  = df[df['_split'] == 'test']

print(f"Train: {len(train_df)} images | Val: {len(val_df)} | Test: {len(test_df)}")

class HAM10000Dataset(Dataset):
    def __init__(self, split_df, img_size=224, augment=False):
        self.df = split_df.dropna(subset=['filepath']).reset_index(drop=True)
        self.augment = augment
        if augment:
            self.transform = T.Compose([
                T.RandomHorizontalFlip(),
                T.RandomVerticalFlip(),
                T.RandomRotation(30),
                T.ColorJitter(brightness=0.2, contrast=0.2),
                T.Resize((img_size, img_size)),
                T.ToTensor(),
                T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ])
        else:
            self.transform = T.Compose([
                T.Resize((img_size, img_size)),
                T.ToTensor(),
                T.Normalize([0.485, 0.456, 0.406], [0.229, 0.224, 0.225]),
            ])

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]
        img = Image.open(row['filepath']).convert('RGB')
        img = self.transform(img)
        return img, torch.tensor(row['label'], dtype=torch.float32)

IMG_SIZE = 224
BATCH_SIZE = 32

train_ds = HAM10000Dataset(train_df, img_size=IMG_SIZE, augment=True)
val_ds   = HAM10000Dataset(val_df,   img_size=IMG_SIZE, augment=False)
test_ds  = HAM10000Dataset(test_df,  img_size=IMG_SIZE, augment=False)

train_loader = DataLoader(train_ds, batch_size=BATCH_SIZE, shuffle=True,  num_workers=0)
val_loader   = DataLoader(val_ds,   batch_size=BATCH_SIZE, shuffle=False, num_workers=0)
test_loader  = DataLoader(test_ds,  batch_size=BATCH_SIZE, shuffle=False, num_workers=0)

print(f"DataLoaders ready. Train batches: {len(train_loader)}")

DEVICE = torch.device('cuda' if torch.cuda.is_available() else 'cpu')
model = timm.create_model('resnet50', pretrained=True, num_classes=1)
model = model.to(DEVICE)

pos_weight = torch.tensor([train_df['label'].value_counts()[0] / train_df['label'].value_counts()[1]]).to(DEVICE)
criterion = torch.nn.BCEWithLogitsLoss(pos_weight=pos_weight)
optimizer = torch.optim.AdamW(model.parameters(), lr=1e-4, weight_decay=1e-5)
scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=10)

print(f"Model: ResNet50 (pretrained)")
print(f"Loss: BCEWithLogitsLoss (pos_weight={pos_weight.item():.2f})")
print(f"Optimizer: AdamW (lr=1e-4, weight_decay=1e-5)")
device_name = torch.cuda.get_device_name(0) if torch.cuda.is_available() else "CPU"
print(f"Device: {DEVICE} - {device_name}")

# Cell 8: Training loop
print("\n" + "=" * 50)
print("CELL 8: Training Loop (10 epochs)")
print("=" * 50)
from tqdm import tqdm
import copy
from sklearn.metrics import roc_auc_score

EPOCHS = 10
best_val_auc = 0
best_model_state = None

for epoch in range(EPOCHS):
    model.train()
    train_loss = 0
    pbar = tqdm(train_loader, desc=f"Epoch {epoch+1}/{EPOCHS} [Train]")
    for images, labels in pbar:
        images = images.to(DEVICE)
        labels = labels.to(DEVICE).unsqueeze(1)
        optimizer.zero_grad()
        logits = model(images)
        loss = criterion(logits, labels)
        loss.backward()
        optimizer.step()
        train_loss += loss.item()
        pbar.set_postfix({'loss': f'{loss.item():.4f}'})

    train_loss /= len(train_loader)

    model.eval()
    val_loss = 0
    all_logits, all_labels = [], []
    with torch.no_grad():
        for images, labels in tqdm(val_loader, desc=f"Epoch {epoch+1}/{EPOCHS} [Val]"):
            images = images.to(DEVICE)
            labels = labels.to(DEVICE).unsqueeze(1)
            logits = model(images)
            loss = criterion(logits, labels)
            val_loss += loss.item()
            all_logits.append(logits.cpu())
            all_labels.append(labels.cpu())

    val_loss /= len(val_loader)
    all_logits = torch.cat(all_logits)
    all_labels = torch.cat(all_labels)
    val_auc = roc_auc_score(all_labels.numpy(), torch.sigmoid(all_logits).numpy())
    scheduler.step()

    print(f"Epoch {epoch+1}: train_loss={train_loss:.4f} | val_loss={val_loss:.4f} | val_auc={val_auc:.4f}")

    if val_auc > best_val_auc:
        best_val_auc = val_auc
        best_model_state = copy.deepcopy(model.state_dict())
        print(f"  -> New best model (val_auc={val_auc:.4f})")

print(f"\nTraining done. Best val_auc: {best_val_auc:.4f}")

# Cell 9: Evaluate and save
print("\n" + "=" * 50)
print("CELL 9: Evaluate on Test Set and Save Model")
print("=" * 50)
model.load_state_dict(best_model_state)
model.eval()

all_preds, all_labels = [], []
with torch.no_grad():
    for images, labels in tqdm(test_loader, desc="Evaluating test set"):
        images = images.to(DEVICE)
        logits = model(images)
        probs = torch.sigmoid(logits).cpu().numpy().flatten()
        all_preds.extend(probs)
        all_labels.extend(labels.numpy())

from sklearn.metrics import roc_auc_score, accuracy_score, classification_report
test_auc = roc_auc_score(np.array(all_labels).astype(int), np.array(all_preds))
test_acc = accuracy_score(np.array(all_labels).astype(int), (np.array(all_preds) > 0.5).astype(int))

print(f"\n=== Test Set Results ===")
print(f"AUC: {test_auc:.4f}")
print(f"Accuracy: {test_acc:.4f}")
print(classification_report(np.array(all_labels).astype(int), (np.array(all_preds) > 0.5).astype(int),
                            target_names=['Benign', 'Malignant']))

MODEL_DIR = ML_DIR / "outputs" / "models"
MODEL_DIR.mkdir(parents=True, exist_ok=True)
MODEL_PATH = MODEL_DIR / "resnet50_best.pth"
torch.save({
    'model_state_dict': best_model_state,
    'val_auc': best_val_auc,
    'test_auc': test_auc,
    'test_acc': test_acc,
    'epochs': EPOCHS,
    'pos_weight': pos_weight.item(),
}, MODEL_PATH)
print(f"\nModel saved to: {MODEL_PATH}")
print(f"File size: {MODEL_PATH.stat().st_size / 1e6:.1f} MB")
