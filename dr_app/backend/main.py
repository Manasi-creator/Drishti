from pathlib import Path
import json
import shutil
import uuid
import cv2
import numpy as np

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.database import (
    init_db,
    insert_patient,
    get_patient,
    list_patients,
    insert_screening,
    get_screening,
    list_screenings,
    list_patient_screenings,
)

from backend.model_utils import run_inference

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent

UPLOAD_DIR = BASE_DIR / "uploads"
HEATMAP_DIR = BASE_DIR / "heatmaps"

UPLOAD_DIR.mkdir(exist_ok=True)
HEATMAP_DIR.mkdir(exist_ok=True)


# ---------------------------------------------------------------------------
# FastAPI application
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Drishti API",
    description=(
        "AI-assisted diabetic retinopathy screening API "
        "for clinician-supported screening."
    ),
    version="1.0.0",
)


# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Static files
# ---------------------------------------------------------------------------

app.mount(
    "/uploads",
    StaticFiles(directory=UPLOAD_DIR),
    name="uploads",
)

app.mount(
    "/heatmaps",
    StaticFiles(directory=HEATMAP_DIR),
    name="heatmaps",
)


# ---------------------------------------------------------------------------
# Startup
# ---------------------------------------------------------------------------

@app.on_event("startup")
def startup_event():
    init_db()


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/")
def root():
    return {
        "message": "Drishti API is running",
        "status": "ok",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "Drishti API",
    }


# ---------------------------------------------------------------------------
# Patient APIs
# ---------------------------------------------------------------------------

@app.post("/patients")
def create_patient(
    name: str = Form(...),
    date_of_birth: str | None = Form(None),
    gender: str | None = Form(None),
    phone: str | None = Form(None),
    blood_group: str | None = Form(None),
):
    """
    Create a new patient and generate a Drishti patient ID.
    """

    if not name.strip():
        raise HTTPException(
            status_code=400,
            detail="Patient name is required.",
        )

    patient_id = insert_patient({
        "name": name.strip(),
        "date_of_birth": date_of_birth,
        "gender": gender,
        "phone": phone,
        "blood_group": blood_group,
    })

    return {
        "status": "success",
        "patient_id": patient_id,
        "message": "Patient created successfully.",
    }


@app.get("/patients")
def get_patients(limit: int = 100):
    """
    Return the list of patients.
    """

    if limit < 1 or limit > 500:
        raise HTTPException(
            status_code=400,
            detail="Limit must be between 1 and 500.",
        )

    patients = list_patients(limit)

    return {
        "count": len(patients),
        "patients": patients,
    }


@app.get("/patients/{patient_id}")
def get_patient_details(patient_id: str):
    """
    Return one patient's profile.
    """

    patient = get_patient(patient_id)

    if patient is None:
        raise HTTPException(
            status_code=404,
            detail="Patient not found.",
        )

    screenings = list_patient_screenings(patient_id)

    for screening in screenings:
        if screening.get("class_probabilities"):
            screening["class_probabilities"] = json.loads(
                screening["class_probabilities"]
            )

    return {
        "patient": patient,
        "screenings": screenings,
    }


@app.get("/patients/{patient_id}/screenings")
def get_patient_screenings(patient_id: str, limit: int = 100):
    """
    Return screening history for one patient.
    """

    if limit < 1 or limit > 500:
        raise HTTPException(
            status_code=400,
            detail="Limit must be between 1 and 500.",
        )

    patient = get_patient(patient_id)

    if patient is None:
        raise HTTPException(
            status_code=404,
            detail="Patient not found.",
        )

    screenings = list_patient_screenings(patient_id, limit)

    for screening in screenings:
        if screening.get("class_probabilities"):
            screening["class_probabilities"] = json.loads(
                screening["class_probabilities"]
            )

    return {
        "patient_id": patient_id,
        "count": len(screenings),
        "screenings": screenings,
    }


# ---------------------------------------------------------------------------
# Analyze fundus image
# ---------------------------------------------------------------------------

@app.post("/screening/analyze")
async def analyze_screening(
    file: UploadFile = File(...),
    patient_id: str | None = Form(None),
):
    """
    Upload a fundus image and perform AI-assisted DR screening.
    """

    # -------------------------------------------------------
    # Validate file
    # -------------------------------------------------------

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Please upload a valid image file.",
        )

    # -------------------------------------------------------
    # Generate unique filename
    # -------------------------------------------------------

    extension = Path(file.filename or "").suffix.lower()

    if extension not in [".jpg", ".jpeg", ".png"]:
        extension = ".jpg"

    unique_name = f"{uuid.uuid4().hex}{extension}"

    stored_path = UPLOAD_DIR / unique_name

    # -------------------------------------------------------
    # Save uploaded image
    # -------------------------------------------------------

    with stored_path.open("wb") as buffer:
        shutil.copyfileobj(
            file.file,
            buffer,
        )

    # -------------------------------------------------------
    # Read image using OpenCV
    # -------------------------------------------------------

    image = cv2.imread(
        str(stored_path)
    )

    if image is None:
        stored_path.unlink(missing_ok=True)

        raise HTTPException(
            status_code=400,
            detail="Unable to read the uploaded image.",
        )

    # -------------------------------------------------------
    # Run AI pipeline
    # -------------------------------------------------------

    try:
        result = run_inference(image)

    except FileNotFoundError:
        raise HTTPException(
            status_code=503,
            detail=(
                "AI model checkpoint is not available yet. "
                "Please add best_model.pt to the backend directory."
            ),
        )

    except RuntimeError as exc:
        raise HTTPException(
            status_code=500,
            detail=f"Model inference failed: {str(exc)}",
        )

    # -------------------------------------------------------
    # Quality failed
    # -------------------------------------------------------

    if result["grade"] is None:

        screening_id = insert_screening({
            "patient_id": patient_id,
            "original_filename": file.filename or "unknown",
            "stored_filename": unique_name,
            "heatmap_filename": None,
            "quality_acceptable": False,
            "quality_reason": result["quality"]["reason"],
            "dr_grade": None,
            "dr_grade_label": None,
            "confidence": None,
            "referable": None,
            "class_probabilities": None,
        })

        return {
            "screening_id": screening_id,
            "status": "quality_failed",
            "patient_id": patient_id,
            "quality": result["quality"],
            "message": (
                "Image quality is insufficient for screening. "
                "Please capture another fundus image."
            ),
        }

    # -------------------------------------------------------
    # Save Grad-CAM heatmap
    # -------------------------------------------------------

    heatmap_name = f"{uuid.uuid4().hex}_heatmap.jpg"

    heatmap_path = HEATMAP_DIR / heatmap_name

    cv2.imwrite(
        str(heatmap_path),
        result["overlay"],
    )

    # -------------------------------------------------------
    # Save screening result
    # -------------------------------------------------------

    screening_id = insert_screening({
        "patient_id": patient_id,
        "original_filename": file.filename or "unknown",
        "stored_filename": unique_name,
        "heatmap_filename": heatmap_name,
        "quality_acceptable": True,
        "quality_reason": result["quality"]["reason"],
        "dr_grade": result["grade"],
        "dr_grade_label": result["grade_label"],
        "confidence": result["confidence"],
        "referable": int(result["referable"]),
        "class_probabilities": json.dumps(
            result["class_probabilities"]
        ),
    })

    # -------------------------------------------------------
    # API response
    # -------------------------------------------------------

    return {
        "screening_id": screening_id,
        "status": "success",

        "patient_id": patient_id,

        "quality": result["quality"],

        "prediction": {
            "grade": result["grade"],
            "label": result["grade_label"],
            "confidence": result["confidence"],
            "referable": result["referable"],
            "class_probabilities": result[
                "class_probabilities"
            ],
        },

        "files": {
            "original_image": f"/uploads/{unique_name}",
            "heatmap": f"/heatmaps/{heatmap_name}",
        },

        "clinical_note": (
            "This result is AI-assisted screening information "
            "and should be reviewed by a qualified clinician. "
            "It is not a standalone diagnosis."
        ),
    }


# ---------------------------------------------------------------------------
# Get one screening
# ---------------------------------------------------------------------------

@app.get("/screening/{screening_id}")
def get_screening_result(
    screening_id: int,
):

    screening = get_screening(
        screening_id
    )

    if screening is None:
        raise HTTPException(
            status_code=404,
            detail="Screening not found.",
        )

    if screening.get("class_probabilities"):
        screening["class_probabilities"] = json.loads(
            screening["class_probabilities"]
        )

    return screening


# ---------------------------------------------------------------------------
# List screenings
# ---------------------------------------------------------------------------

@app.get("/screenings")
def get_screenings(
    limit: int = 100,
):

    if limit < 1 or limit > 500:
        raise HTTPException(
            status_code=400,
            detail="Limit must be between 1 and 500.",
        )

    screenings = list_screenings(
        limit
    )

    for screening in screenings:

        if screening.get("class_probabilities"):
            screening["class_probabilities"] = json.loads(
                screening["class_probabilities"]
            )

    return {
        "count": len(screenings),
        "screenings": screenings,
    }