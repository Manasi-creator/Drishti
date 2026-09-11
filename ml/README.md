# Drishti ML

ML training/evaluation files for the Drishti diabetic retinopathy screening MVP.

## Files

- `preprocessing.py` — 224x224 resize/padding + CLAHE preprocessing.
- `train_model.py` — EfficientNet-B0 training on APTOS 2019.
- `evaluate.py` — evaluates the saved checkpoint.

## Google Colab

1. Enable GPU: Runtime → Change runtime type → T4 GPU.
2. Download/extract the APTOS 2019 dataset.
3. Ensure:
   - `/content/aptos2019-blindness-detection/train.csv`
   - `/content/aptos2019-blindness-detection/train_images/`
4. Upload the three `.py` files to `/content/ml/`.
5. Run:

```python
!pip install -q opencv-python scikit-learn pandas
!python /content/ml/train_model.py
```

The best checkpoint is saved to:

```text
/content/best_dr_model.pth
```

The training script selects the checkpoint with the highest validation macro-F1.

## Current Drishti MVP result

Using the current training run:

- Best validation Macro-F1: 0.6630 at Epoch 6
- Validation accuracy at Epoch 8: 0.8076

For deployment, use the saved **best Macro-F1 checkpoint**, not necessarily the final epoch.

## Important

This is a research/hackathon screening prototype. The model is not clinically validated and should not be presented as an autonomous diagnostic system.
