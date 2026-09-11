# Drishti — Explainable AI for Diabetic Retinopathy Screening

*Clear sight, caught early.*

Drishti is a full-stack, explainable AI system that screens fundus images for diabetic retinopathy (DR), grades severity, and shows a Grad-CAM heatmap of exactly what the model saw — built to support any care setting, urban or rural, where a specialist isn't immediately on hand to review every scan and early diagnosis is what prevents avoidable blindness.

---

## Table of contents

- [The problem](#the-problem)
- [What Drishti does](#what-drishti-does)
- [Architecture](#architecture)
- [Tech stack](#tech-stack)
- [Project structure](#project-structure)
- [Getting started](#getting-started)
- [API reference](#api-reference)
- [Model performance](#model-performance)
- [Honest scope — what's real vs. future work](#honest-scope--whats-real-vs-future-work)
- [Roadmap](#roadmap)

---

## The problem

India has one of the world's largest diabetic populations, and diabetic retinopathy is one of the leading causes of preventable blindness. Ophthalmologist time is a limited resource everywhere it's needed — in busy urban hospitals with long patient queues just as much as in under-resourced rural centres — and by the time a case is manually reviewed, early-stage damage can already have progressed.

Drishti puts a first-pass, explainable screening layer in front of that bottleneck, wherever it occurs: a fundus photo goes in, and within seconds a grade, a confidence score, and a visual heatmap of the exact retinal regions driving that grade come out — helping any care team, at any facility, prioritize which patients need urgent specialist review.

## What Drishti does

- **Quality check** — flags blurry, too-dark, or overexposed fundus images before they ever reach the model, and asks for a recapture instead of returning a guess on bad data.
- **Enhancement** — crops to the retina, applies CLAHE contrast correction and light denoising, consistent with how the model was trained.
- **DR grading** — a fine-tuned EfficientNet-B3 classifies each image into one of five clinical grades (No DR → Proliferative DR) and collapses this into a referable / non-referable flag.
- **Explainability** — Grad-CAM overlays a heatmap on the fundus image, showing the ophthalmologist *why* the model made its call, not just what it decided.
- **Human-in-the-loop by design** — every result is presented as a decision-support flag for a clinician to confirm, not an autonomous diagnosis.
- **Screening history** — every result is logged to a database and viewable in a portal, so any clinic or hospital can track patients screened over time.
- **WiFi-reachable portal** — the backend runs on a local machine and is reachable from any phone/tablet on the same network, so the fundus-camera operator can transfer and screen an image without extra hardware integration — equally useful in a metro hospital's ophthalmology wing or a single-room clinic.

## Architecture

```
 Fundus camera
       │  (image transferred over local WiFi)
       ▼
 ┌─────────────────┐     ┌───────────────┐     ┌────────────────────┐
 │  Quality check   │ ──▶ │  Enhancement   │ ──▶ │  EfficientNet-B3    │
 │ (blur/exposure)  │     │ (CLAHE+denoise)│     │  DR grading (L0-L4) │
 └─────────────────┘     └───────────────┘     └──────────┬─────────┘
                                                            ▼
                                                 ┌────────────────────┐
                                                 │   Grad-CAM overlay  │
                                                 │   (explainability)  │
                                                 └──────────┬─────────┘
                                                            ▼
                                    ┌───────────────────────────────────┐
                                    │  Portal result screen              │
                                    │  grade · confidence · heatmap ·    │
                                    │  referral flag                     │
                                    └──────────────┬──────────────────┘
                                                    ▼
                                        Logged to database (history)
```

## Tech stack

| Layer | Choice |
|---|---|
| Model | EfficientNet-B3 (transfer learning), Grad-CAM |
| ML framework | PyTorch, torchvision |
| Image processing | OpenCV |
| Backend | FastAPI (Python) |
| Database | SQLite |
| Frontend | HTML/CSS/JS single-page app (no build step) |
| Datasets | APTOS 2019, IDRiD |

## Project structure

```
dr_app/
├── preprocess.py          # quality check, enhancement, train/val/test split
├── train_model.py         # EfficientNet-B3 fine-tuning + evaluation
├── backend/
│   ├── main.py             # FastAPI app: /screen, /screening/{id}, /history
│   ├── model_utils.py       # quality check, enhancement, inference, Grad-CAM
│   ├── database.py           # SQLite schema + helpers
│   ├── requirements.txt
│   └── best_model.pt          # trained checkpoint (generated, not committed)
├── frontend/
│   └── index.html               # upload UI, result view, history table
└── README.md
```

## Getting started

### 1. Set up the environment
```bash
python -m venv venv
source venv/bin/activate       # Windows: venv\Scripts\activate
cd dr_app/backend
pip install -r requirements.txt
```

### 2. Get the data
Download [APTOS 2019 Blindness Detection](https://www.kaggle.com/c/aptos2019-blindness-detection) from Kaggle. Place `train.csv` and `train_images/` under `data/` at the project root.

### 3. Preprocess and train
```bash
python preprocess.py      # -> data/processed/{train,val,test}
python train_model.py     # -> best_model.pt, training_log.csv, test_metrics.json
```
Training runs ~1.5–3 hours on a free-tier Colab GPU. Move `best_model.pt` into `dr_app/backend/` once done.

### 4. Run the backend
```bash
cd dr_app/backend
uvicorn main:app --host 0.0.0.0 --port 8000
```
Check `http://localhost:8000/health` returns `{"status": "ok"}`.

### 5. Open the frontend
Open `dr_app/frontend/index.html` in a browser. To use it from a phone/tablet on the same WiFi network — a fundus-camera station in any clinic or hospital ward — find your machine's local IP (`ipconfig` / `ifconfig`) and update `API_BASE` in `index.html` accordingly.

## API reference

| Endpoint | Method | Description |
|---|---|---|
| `/health` | GET | Server health check |
| `/screen` | POST | Upload a fundus image (`file`, optional `patient_id`) → quality result, grade, confidence, referral flag, heatmap URL |
| `/screening/{id}` | GET | Fetch a single past screening record |
| `/history` | GET | List recent screenings (`?limit=`) |

## What's implemented

**Implemented and tested:**
- Real quality-check heuristics and CLAHE/denoise enhancement
- Real EfficientNet-B3 inference trained on public DR datasets
- Real Grad-CAM explainability
- Real persistence (SQLite) and history view
- Reachable over a local WiFi network from a second device