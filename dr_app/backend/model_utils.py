"""
Core ML utilities used by the FastAPI backend.

Pipeline:
- image quality check
- aspect-ratio preserving resize + padding
- CLAHE enhancement
- EfficientNet-B0 inference for DR grading
- Grad-CAM heatmap generation
"""

import cv2
import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import transforms
from torchvision.models import efficientnet_b0
from PIL import Image
from pathlib import Path

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

IMG_SIZE = 224
NUM_CLASSES = 5
REFERABLE_THRESHOLD = 2

BASE_DIR = Path(__file__).resolve().parent
CHECKPOINT_PATH = BASE_DIR / "best_model.pt"

DEVICE = torch.device(
    "cuda" if torch.cuda.is_available() else "cpu"
)

GRADE_LABELS = {
    0: "No DR",
    1: "Mild",
    2: "Moderate",
    3: "Severe",
    4: "Proliferative DR",
}

BLUR_THRESHOLD = 100.0
DARK_MEAN_THRESHOLD = 25.0
BRIGHT_MEAN_THRESHOLD = 230.0


# Same normalization used during Colab training
eval_transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225]
    ),
])


# ---------------------------------------------------------------------------
# Quality check
# ---------------------------------------------------------------------------

def check_quality(img_gray: np.ndarray) -> dict:
    """
    Basic image quality check using:
    - Laplacian variance for blur
    - mean intensity for exposure
    """

    blur_score = cv2.Laplacian(
        img_gray,
        cv2.CV_64F
    ).var()

    mean_intensity = img_gray.mean()

    is_blurry = blur_score < BLUR_THRESHOLD
    is_too_dark = mean_intensity < DARK_MEAN_THRESHOLD
    is_overexposed = mean_intensity > BRIGHT_MEAN_THRESHOLD

    return {
        "blur_score": float(blur_score),
        "mean_intensity": float(mean_intensity),
        "acceptable": not (
            is_blurry or
            is_too_dark or
            is_overexposed
        ),
        "reason": (
            "blurry" if is_blurry else
            "too_dark" if is_too_dark else
            "overexposed" if is_overexposed else
            "ok"
        ),
    }


# ---------------------------------------------------------------------------
# Preprocessing
# ---------------------------------------------------------------------------

def preprocess_image(img_bgr: np.ndarray) -> np.ndarray:
    """
    Same core preprocessing used during Colab training.

    1. BGR -> RGB
    2. Preserve aspect ratio
    3. Resize to fit inside 224x224
    4. Pad with black pixels
    5. Apply CLAHE to LAB lightness channel

    Returns RGB uint8 image.
    """

    image = cv2.cvtColor(
        img_bgr,
        cv2.COLOR_BGR2RGB
    )

    h, w = image.shape[:2]

    scale = min(
        IMG_SIZE / w,
        IMG_SIZE / h
    )

    new_w = int(w * scale)
    new_h = int(h * scale)

    image = cv2.resize(
        image,
        (new_w, new_h),
        interpolation=cv2.INTER_AREA
    )

    canvas = np.zeros(
        (IMG_SIZE, IMG_SIZE, 3),
        dtype=np.uint8
    )

    x_offset = (IMG_SIZE - new_w) // 2
    y_offset = (IMG_SIZE - new_h) // 2

    canvas[
        y_offset:y_offset + new_h,
        x_offset:x_offset + new_w
    ] = image

    # CLAHE
    lab = cv2.cvtColor(
        canvas,
        cv2.COLOR_RGB2LAB
    )

    l, a, b = cv2.split(lab)

    clahe = cv2.createCLAHE(
        clipLimit=2.0,
        tileGridSize=(8, 8)
    )

    l = clahe.apply(l)

    lab = cv2.merge(
        (l, a, b)
    )

    processed = cv2.cvtColor(
        lab,
        cv2.COLOR_LAB2RGB
    )

    return processed


# ---------------------------------------------------------------------------
# Model loading
# ---------------------------------------------------------------------------

_model = None
_target_layer = None


def load_model():
    """
    Load EfficientNet-B0 checkpoint once.
    """

    global _model, _target_layer

    if _model is not None:
        return _model

    model = efficientnet_b0(
        weights=None
    )

    in_features = model.classifier[1].in_features

    model.classifier[1] = nn.Linear(
        in_features,
        NUM_CLASSES
    )

    state_dict = torch.load(
        CHECKPOINT_PATH,
        map_location=DEVICE
    )

    model.load_state_dict(
        state_dict
    )

    model.to(DEVICE)
    model.eval()

    _model = model

    # Last convolutional feature layer
    _target_layer = model.features[-1]

    return _model


# ---------------------------------------------------------------------------
# Grad-CAM
# ---------------------------------------------------------------------------

class GradCAM:

    def __init__(
        self,
        model,
        target_layer
    ):
        self.model = model
        self.gradients = None
        self.activations = None

        target_layer.register_forward_hook(
            self._save_activation
        )

        target_layer.register_full_backward_hook(
            self._save_gradient
        )

    def _save_activation(
        self,
        module,
        input,
        output
    ):
        self.activations = output.detach()

    def _save_gradient(
        self,
        module,
        grad_input,
        grad_output
    ):
        self.gradients = grad_output[0].detach()

    def generate(
        self,
        input_tensor,
        class_idx
    ):

        output = self.model(
            input_tensor
        )

        self.model.zero_grad()

        score = output[
            0,
            class_idx
        ]

        score.backward()

        weights = self.gradients.mean(
            dim=(2, 3),
            keepdim=True
        )

        cam = (
            weights *
            self.activations
        ).sum(
            dim=1,
            keepdim=True
        )

        cam = F.relu(cam)

        cam = F.interpolate(
            cam,
            size=(IMG_SIZE, IMG_SIZE),
            mode="bilinear",
            align_corners=False
        )

        cam = cam.squeeze().cpu().numpy()

        cam = (
            cam - cam.min()
        ) / (
            cam.max() -
            cam.min() +
            1e-8
        )

        return cam, output


# ---------------------------------------------------------------------------
# Heatmap overlay
# ---------------------------------------------------------------------------

def overlay_heatmap(
    original_bgr: np.ndarray,
    cam: np.ndarray
) -> np.ndarray:

    heatmap = cv2.applyColorMap(
        (cam * 255).astype(np.uint8),
        cv2.COLORMAP_JET
    )

    overlay = cv2.addWeighted(
        original_bgr,
        0.6,
        heatmap,
        0.4,
        0
    )

    return overlay


# ---------------------------------------------------------------------------
# End-to-end inference
# ---------------------------------------------------------------------------

def run_inference(
    img_bgr: np.ndarray
):
    """
    Complete screening pipeline.

    Returns:
    - quality information
    - predicted DR grade
    - confidence
    - class probabilities
    - referable flag
    - Grad-CAM overlay
    """

    # -------------------------------------------------------
    # 1. Quality check
    # -------------------------------------------------------

    gray = cv2.cvtColor(
        img_bgr,
        cv2.COLOR_BGR2GRAY
    )

    quality = check_quality(
        gray
    )

    if not quality["acceptable"]:

        return {
            "quality": quality,
            "grade": None,
            "grade_label": None,
            "confidence": None,
            "referable": None,
            "class_probabilities": None,
            "overlay": None,
        }

    # -------------------------------------------------------
    # 2. Preprocess
    # -------------------------------------------------------

    enhanced_rgb = preprocess_image(
        img_bgr
    )

    # Convert to PIL
    pil_img = Image.fromarray(
        enhanced_rgb
    )

    # Normalize
    input_tensor = eval_transform(
        pil_img
    ).unsqueeze(0).to(DEVICE)

    # -------------------------------------------------------
    # 3. Load model
    # -------------------------------------------------------

    model = load_model()

    # -------------------------------------------------------
    # 4. Prediction
    # -------------------------------------------------------

    with torch.no_grad():

        logits = model(
            input_tensor
        )

        probs = torch.softmax(
            logits,
            dim=1
        ).squeeze().cpu().numpy()

    pred_class = int(
        np.argmax(probs)
    )

    confidence = float(
        probs[pred_class]
    )

    # -------------------------------------------------------
    # 5. Grad-CAM
    # -------------------------------------------------------

    cam_engine = GradCAM(
        model,
        _target_layer
    )

    input_tensor.requires_grad_(True)

    cam, _ = cam_engine.generate(
        input_tensor,
        pred_class
    )

    # Create 224x224 BGR image for overlay
    enhanced_bgr = cv2.cvtColor(
        enhanced_rgb,
        cv2.COLOR_RGB2BGR
    )

    overlay = overlay_heatmap(
        enhanced_bgr,
        cam
    )

    # -------------------------------------------------------
    # 6. Referable DR
    # -------------------------------------------------------

    referable = (
        pred_class >= REFERABLE_THRESHOLD
    )

    return {
        "quality": quality,
        "grade": pred_class,
        "grade_label": GRADE_LABELS[pred_class],
        "confidence": confidence,
        "referable": referable,
        "class_probabilities": probs.tolist(),
        "overlay": overlay,
    }