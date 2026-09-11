"""
Drishti - evaluation script for the saved EfficientNet-B0 checkpoint.

This script reports:
- accuracy
- macro F1
- classification report
- confusion matrix

It uses the exact same preprocessing and train/validation split as training.
"""

from pathlib import Path

import numpy as np
import pandas as pd
import torch
import torch.nn as nn
from torch.utils.data import DataLoader

from torchvision.models import efficientnet_b0

from sklearn.metrics import (
    accuracy_score,
    f1_score,
    classification_report,
    confusion_matrix,
)

from train_model import (
    APTOSDataset,
    DATA_ROOT,
    CSV_PATH,
    IMAGE_DIR,
    BATCH_SIZE,
    NUM_CLASSES,
    SEED,
    device,
)


CHECKPOINT_PATH = Path("/content/best_dr_model.pth")


def main():
    if not CHECKPOINT_PATH.exists():
        raise FileNotFoundError(
            f"Checkpoint not found: {CHECKPOINT_PATH}"
        )

    df = pd.read_csv(CSV_PATH)

    from sklearn.model_selection import train_test_split

    _, val_df = train_test_split(
        df,
        test_size=0.20,
        random_state=SEED,
        stratify=df["diagnosis"],
    )

    val_dataset = APTOSDataset(val_df)

    val_loader = DataLoader(
        val_dataset,
        batch_size=BATCH_SIZE,
        shuffle=False,
        num_workers=2,
        pin_memory=torch.cuda.is_available(),
    )

    model = efficientnet_b0(weights=None)
    model.classifier[1] = nn.Linear(
        model.classifier[1].in_features,
        NUM_CLASSES,
    )

    state_dict = torch.load(
        CHECKPOINT_PATH,
        map_location=device,
    )

    model.load_state_dict(state_dict)
    model = model.to(device)
    model.eval()

    y_true = []
    y_pred = []

    with torch.no_grad():
        for images, labels in val_loader:
            images = images.to(device)
            outputs = model(images)

            predictions = outputs.argmax(dim=1)

            y_true.extend(labels.numpy())
            y_pred.extend(
                predictions.cpu().numpy()
            )

    accuracy = accuracy_score(y_true, y_pred)
    macro_f1 = f1_score(
        y_true,
        y_pred,
        average="macro",
    )

    print("\n==============================")
    print("Drishti Model Evaluation")
    print("==============================")
    print(f"Validation Accuracy : {accuracy:.4f}")
    print(f"Validation Macro F1 : {macro_f1:.4f}")

    print("\nClassification Report:")
    print(
        classification_report(
            y_true,
            y_pred,
            target_names=[
                "No DR",
                "Mild",
                "Moderate",
                "Severe",
                "Proliferative DR",
            ],
            digits=4,
            zero_division=0,
        )
    )

    print("Confusion Matrix:")
    print(confusion_matrix(y_true, y_pred))


if __name__ == "__main__":
    main()
