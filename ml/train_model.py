"""
Drishti - EfficientNet-B0 training script for APTOS 2019.

Run in Google Colab after downloading/extracting the APTOS 2019 dataset.

Expected dataset:
    /content/aptos2019-blindness-detection/train.csv
    /content/aptos2019-blindness-detection/train_images/

The script reproduces the training setup used for the current Drishti MVP:
- 224x224 input
- aspect-ratio preserving resize + black padding
- CLAHE
- EfficientNet-B0 ImageNet initialization
- 5 DR classes
- stratified 80/20 train/validation split
- class-weighted CrossEntropyLoss
- AdamW
- ReduceLROnPlateau
- 8 epochs
- best checkpoint selected by validation macro-F1

The output checkpoint is:
    /content/best_dr_model.pth
"""

from pathlib import Path
import time
import random

import cv2
import numpy as np
import pandas as pd
from PIL import Image

import torch
import torch.nn as nn
from torch.optim import AdamW
from torch.utils.data import Dataset, DataLoader
from torchvision.models import efficientnet_b0, EfficientNet_B0_Weights

from sklearn.model_selection import train_test_split
from sklearn.metrics import f1_score, accuracy_score

from preprocessing import preprocess_image, IMG_SIZE


# ============================================================
# Configuration
# ============================================================

SEED = 42
NUM_CLASSES = 5
BATCH_SIZE = 32
NUM_EPOCHS = 8
LEARNING_RATE = 1e-4
WEIGHT_DECAY = 1e-4

DATA_ROOT = Path("/content/aptos2019-blindness-detection")
CSV_PATH = DATA_ROOT / "train.csv"
IMAGE_DIR = DATA_ROOT / "train_images"

CHECKPOINT_PATH = Path("/content/best_dr_model.pth")

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")


# EfficientNet ImageNet normalization.
# This is required because the model starts from ImageNet pretrained weights.
MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float32)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float32)


# ============================================================
# Reproducibility
# ============================================================

def set_seed(seed=SEED):
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)

    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


# ============================================================
# Dataset
# ============================================================

class APTOSDataset(Dataset):
    def __init__(self, dataframe):
        self.df = dataframe.reset_index(drop=True)

    def __len__(self):
        return len(self.df)

    def __getitem__(self, idx):
        row = self.df.iloc[idx]

        image_path = IMAGE_DIR / f"{row['id_code']}.png"
        image = preprocess_image(image_path)

        image = image.astype(np.float32) / 255.0
        image = (image - MEAN) / STD

        # HWC -> CHW
        image = torch.from_numpy(image).permute(2, 0, 1).float()

        label = int(row["diagnosis"])
        label = torch.tensor(label, dtype=torch.long)

        return image, label


# ============================================================
# Main training
# ============================================================

def main():
    set_seed()

    print("PyTorch:", torch.__version__)
    print("Device:", device)

    if torch.cuda.is_available():
        print("GPU:", torch.cuda.get_device_name(0))

    if not CSV_PATH.exists():
        raise FileNotFoundError(f"CSV not found: {CSV_PATH}")

    if not IMAGE_DIR.exists():
        raise FileNotFoundError(f"Image directory not found: {IMAGE_DIR}")

    df = pd.read_csv(CSV_PATH)

    required_columns = {"id_code", "diagnosis"}
    missing = required_columns - set(df.columns)

    if missing:
        raise ValueError(f"Missing CSV columns: {missing}")

    print("\nDataset size:", len(df))
    print("\nClass distribution:")
    print(df["diagnosis"].value_counts().sort_index())

    # --------------------------------------------------------
    # Stratified 80/20 split
    # --------------------------------------------------------

    train_df, val_df = train_test_split(
        df,
        test_size=0.20,
        random_state=SEED,
        stratify=df["diagnosis"],
    )

    print("\nTrain size:", len(train_df))
    print("Validation size:", len(val_df))

    print("\nTrain distribution:")
    print(train_df["diagnosis"].value_counts().sort_index())

    print("\nValidation distribution:")
    print(val_df["diagnosis"].value_counts().sort_index())

    train_dataset = APTOSDataset(train_df)
    val_dataset = APTOSDataset(val_df)

    train_loader = DataLoader(
        train_dataset,
        batch_size=BATCH_SIZE,
        shuffle=True,
        num_workers=2,
        pin_memory=torch.cuda.is_available(),
    )

    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=2,
        pin_memory=torch.cuda.is_available(),
    )

    # --------------------------------------------------------
    # EfficientNet-B0
    # --------------------------------------------------------

    weights = EfficientNet_B0_Weights.DEFAULT

    model = efficientnet_b0(weights=weights)
    model.classifier[1] = nn.Linear(
        model.classifier[1].in_features,
        NUM_CLASSES,
    )

    model = model.to(device)

    # --------------------------------------------------------
    # Class weights
    # --------------------------------------------------------

    class_counts = (
        train_df["diagnosis"]
        .value_counts()
        .sort_index()
        .values
        .astype(np.float32)
    )

    class_weights = len(train_df) / (
        NUM_CLASSES * class_counts
    )

    class_weights = torch.tensor(
        class_weights,
        dtype=torch.float32,
        device=device,
    )

    print("\nClass weights:")
    print(class_weights)

    criterion = nn.CrossEntropyLoss(
        weight=class_weights
    )

    optimizer = AdamW(
        model.parameters(),
        lr=LEARNING_RATE,
        weight_decay=WEIGHT_DECAY,
    )

    scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
        optimizer,
        mode="max",
        factor=0.5,
        patience=1,
    )

    # --------------------------------------------------------
    # Training loop
    # --------------------------------------------------------

    best_val_f1 = -1.0

    for epoch in range(NUM_EPOCHS):
        start_time = time.time()

        # ---------------------------
        # Training
        # ---------------------------
        model.train()

        train_losses = []
        train_true = []
        train_pred = []

        for images, labels in train_loader:
            images = images.to(device, non_blocking=True)
            labels = labels.to(device, non_blocking=True)

            optimizer.zero_grad()

            outputs = model(images)
            loss = criterion(outputs, labels)

            loss.backward()
            optimizer.step()

            train_losses.append(loss.item())

            predictions = outputs.argmax(dim=1)

            train_true.extend(labels.detach().cpu().numpy())
            train_pred.extend(predictions.detach().cpu().numpy())

        train_loss = float(np.mean(train_losses))

        train_f1 = f1_score(
            train_true,
            train_pred,
            average="macro",
        )

        # ---------------------------
        # Validation
        # ---------------------------
        model.eval()

        val_losses = []
        val_true = []
        val_pred = []

        with torch.no_grad():
            for images, labels in val_loader:
                images = images.to(device, non_blocking=True)
                labels = labels.to(device, non_blocking=True)

                outputs = model(images)
                loss = criterion(outputs, labels)

                val_losses.append(loss.item())

                predictions = outputs.argmax(dim=1)

                val_true.extend(labels.detach().cpu().numpy())
                val_pred.extend(predictions.detach().cpu().numpy())

        val_loss = float(np.mean(val_losses))

        val_f1 = f1_score(
            val_true,
            val_pred,
            average="macro",
        )

        val_acc = accuracy_score(
            val_true,
            val_pred,
        )

        scheduler.step(val_f1)

        elapsed = time.time() - start_time

        is_best = val_f1 > best_val_f1

        if is_best:
            best_val_f1 = val_f1

            torch.save(
                model.state_dict(),
                CHECKPOINT_PATH,
            )

        marker = " ⭐ BEST" if is_best else ""

        print(
            f"Epoch {epoch + 1}/{NUM_EPOCHS} | "
            f"Train Loss: {train_loss:.4f} | "
            f"Val Loss: {val_loss:.4f} | "
            f"Train F1: {train_f1:.4f} | "
            f"Val F1: {val_f1:.4f} | "
            f"Val Acc: {val_acc:.4f} | "
            f"{elapsed:.1f}s"
            f"{marker}"
        )

    print("\nTraining complete.")
    print("Best validation Macro-F1:", round(best_val_f1, 4))
    print("Best checkpoint:", CHECKPOINT_PATH)

    # Optional: automatically trigger the Colab download dialog.
    try:
        from google.colab import files
        print("\nStarting checkpoint download...")
        files.download(str(CHECKPOINT_PATH))
    except ImportError:
        print("\nNot running inside Colab; checkpoint remains at:")
        print(CHECKPOINT_PATH)


if __name__ == "__main__":
    main()
