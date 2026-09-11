"""
Drishti ML preprocessing
Shared preprocessing used for APTOS training/inference.

Training pipeline:
BGR/RGB image -> aspect-ratio resize + 224x224 padding -> CLAHE -> RGB
"""

from pathlib import Path
import cv2
import numpy as np

IMG_SIZE = 224


def preprocess_image(image_path):
    """Load and preprocess an image from a file path. Returns RGB uint8 [224,224,3]."""
    image = cv2.imread(str(image_path))
    if image is None:
        raise FileNotFoundError(f"Could not read image: {image_path}")

    image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

    h, w = image.shape[:2]
    scale = min(IMG_SIZE / w, IMG_SIZE / h)

    new_w = int(w * scale)
    new_h = int(h * scale)

    image = cv2.resize(
        image,
        (new_w, new_h),
        interpolation=cv2.INTER_AREA,
    )

    canvas = np.zeros(
        (IMG_SIZE, IMG_SIZE, 3),
        dtype=np.uint8,
    )

    x_offset = (IMG_SIZE - new_w) // 2
    y_offset = (IMG_SIZE - new_h) // 2

    canvas[
        y_offset:y_offset + new_h,
        x_offset:x_offset + new_w
    ] = image

    lab = cv2.cvtColor(canvas, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)

    clahe = cv2.createCLAHE(
        clipLimit=2.0,
        tileGridSize=(8, 8),
    )

    l = clahe.apply(l)

    lab = cv2.merge((l, a, b))
    processed = cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)

    return processed


def preprocess_bgr_image(image_bgr):
    """Preprocess an already-loaded OpenCV BGR image. Returns RGB uint8."""
    if image_bgr is None:
        raise ValueError("Input image is None.")

    image = cv2.cvtColor(image_bgr, cv2.COLOR_BGR2RGB)

    h, w = image.shape[:2]
    scale = min(IMG_SIZE / w, IMG_SIZE / h)

    new_w = int(w * scale)
    new_h = int(h * scale)

    image = cv2.resize(
        image,
        (new_w, new_h),
        interpolation=cv2.INTER_AREA,
    )

    canvas = np.zeros(
        (IMG_SIZE, IMG_SIZE, 3),
        dtype=np.uint8,
    )

    x_offset = (IMG_SIZE - new_w) // 2
    y_offset = (IMG_SIZE - new_h) // 2

    canvas[
        y_offset:y_offset + new_h,
        x_offset:x_offset + new_w
    ] = image

    lab = cv2.cvtColor(canvas, cv2.COLOR_RGB2LAB)
    l, a, b = cv2.split(lab)

    clahe = cv2.createCLAHE(
        clipLimit=2.0,
        tileGridSize=(8, 8),
    )

    l = clahe.apply(l)

    lab = cv2.merge((l, a, b))
    return cv2.cvtColor(lab, cv2.COLOR_LAB2RGB)
