"""
SQLite database layer for the Drishti screening portal.

MVP database:
- patients
- screenings

SQLite is used for local development/demo.
Can be migrated to PostgreSQL later.
"""

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

from backend.auth import hash_password


BASE_DIR = Path(__file__).resolve().parent
DB_PATH = str(BASE_DIR / "screenings.db")


# ---------------------------------------------------------------------------
# Database initialization
# ---------------------------------------------------------------------------

def init_db():
    with get_conn() as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS doctors (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                doctor_id TEXT NOT NULL UNIQUE,
                name TEXT NOT NULL,
                email TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                role TEXT NOT NULL DEFAULT 'doctor',
                is_active INTEGER NOT NULL DEFAULT 1,
                created_at TEXT
            )
        """)

        # Patients
        conn.execute("""
            CREATE TABLE IF NOT EXISTS patients (
                patient_id TEXT PRIMARY KEY,
                name TEXT NOT NULL,
                date_of_birth TEXT,
                gender TEXT,
                phone TEXT,
                blood_group TEXT,
                created_at TEXT
            )
        """)

        # Screenings
        conn.execute("""
            CREATE TABLE IF NOT EXISTS screenings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                patient_id TEXT,
                original_filename TEXT,
                stored_filename TEXT,
                heatmap_filename TEXT,
                quality_acceptable INTEGER,
                quality_reason TEXT,
                dr_grade INTEGER,
                dr_grade_label TEXT,
                confidence REAL,
                referable INTEGER,
                class_probabilities TEXT,
                created_at TEXT
            )
        """)

        conn.commit()

    seed_default_doctors()


def seed_default_doctors():
    default_doctors = [
        {
            "doctor_id": "DOC-001",
            "name": "Dr. Ananya Sharma",
            "email": "ananya.sharma@drishti.local",
            "password": "Drishti@123",
        },
        {
            "doctor_id": "DOC-002",
            "name": "Dr. Rohan Mehta",
            "email": "rohan.mehta@drishti.local",
            "password": "Drishti@123",
        },
        {
            "doctor_id": "DOC-003",
            "name": "Dr. Priya Kulkarni",
            "email": "priya.kulkarni@drishti.local",
            "password": "Drishti@123",
        },
    ]

    for doctor in default_doctors:
        with get_conn() as conn:
            existing = conn.execute(
                "SELECT id FROM doctors WHERE doctor_id = ? OR email = ?",
                (doctor["doctor_id"], doctor["email"]),
            ).fetchone()

            if existing is not None:
                continue

            conn.execute(
                """
                INSERT INTO doctors (
                    doctor_id,
                    name,
                    email,
                    password_hash,
                    role,
                    is_active,
                    created_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    doctor["doctor_id"],
                    doctor["name"],
                    doctor["email"],
                    hash_password(doctor["password"]),
                    "doctor",
                    1,
                    datetime.now(timezone.utc).isoformat(),
                ),
            )
            conn.commit()


def get_doctor_by_id(doctor_id: str):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM doctors WHERE doctor_id = ?",
            (doctor_id,),
        ).fetchone()
        return dict(row) if row else None


def get_doctor_by_identifier(identifier: str):
    with get_conn() as conn:
        row = conn.execute(
            """
            SELECT *
            FROM doctors
            WHERE doctor_id = ? OR email = ?
            LIMIT 1
            """,
            (identifier, identifier),
        ).fetchone()
        return dict(row) if row else None


# ---------------------------------------------------------------------------
# Connection
# ---------------------------------------------------------------------------

@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    try:
        yield conn
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Patient operations
# ---------------------------------------------------------------------------

def generate_patient_id() -> str:
    with get_conn() as conn:
        row = conn.execute("""
            SELECT patient_id
            FROM patients
            WHERE patient_id LIKE 'DRISHTI-%'
            ORDER BY CAST(SUBSTR(patient_id, 9) AS INTEGER) DESC
            LIMIT 1
        """).fetchone()

        if row is None:
            number = 1
        else:
            number = int(row["patient_id"].split("-")[1]) + 1

        return f"DRISHTI-{number:04d}"


def insert_patient(record: dict) -> str:
    patient_id = record.get("patient_id") or generate_patient_id()

    with get_conn() as conn:
        conn.execute("""
            INSERT INTO patients (
                patient_id,
                name,
                date_of_birth,
                gender,
                phone,
                blood_group,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (
            patient_id,
            record["name"],
            record.get("date_of_birth"),
            record.get("gender"),
            record.get("phone"),
            record.get("blood_group"),
            datetime.now(timezone.utc).isoformat(),
        ))

        conn.commit()

    return patient_id


def get_patient(patient_id: str):
    with get_conn() as conn:
        row = conn.execute(
            "SELECT * FROM patients WHERE patient_id = ?",
            (patient_id,)
        ).fetchone()

        return dict(row) if row else None


def list_patients(limit: int = 100):
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT *
            FROM patients
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (limit,)
        ).fetchall()

        return [dict(row) for row in rows]


# ---------------------------------------------------------------------------
# Screening operations
# ---------------------------------------------------------------------------

def insert_screening(record: dict) -> int:
    with get_conn() as conn:
        cursor = conn.execute("""
            INSERT INTO screenings (
                patient_id,
                original_filename,
                stored_filename,
                heatmap_filename,
                quality_acceptable,
                quality_reason,
                dr_grade,
                dr_grade_label,
                confidence,
                referable,
                class_probabilities,
                created_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            record.get("patient_id"),
            record["original_filename"],
            record["stored_filename"],
            record.get("heatmap_filename"),
            int(record["quality_acceptable"]),
            record.get("quality_reason"),
            record.get("dr_grade"),
            record.get("dr_grade_label"),
            record.get("confidence"),
            record.get("referable"),
            record.get("class_probabilities"),
            datetime.now(timezone.utc).isoformat(),
        ))

        conn.commit()

        return cursor.lastrowid


def get_screening(screening_id: int):
    with get_conn() as conn:
        row = conn.execute(
            """
            SELECT
                s.*,
                p.name AS patient_name
            FROM screenings s
            LEFT JOIN patients p
                ON s.patient_id = p.patient_id
            WHERE s.id = ?
            """,
            (screening_id,)
        ).fetchone()

        return dict(row) if row else None


def list_screenings(limit: int = 100):
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT
                s.*,
                p.name AS patient_name
            FROM screenings s
            LEFT JOIN patients p
                ON s.patient_id = p.patient_id
            ORDER BY s.created_at DESC
            LIMIT ?
            """,
            (limit,)
        ).fetchall()

        return [dict(row) for row in rows]


def list_patient_screenings(patient_id: str, limit: int = 100):
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT *
            FROM screenings
            WHERE patient_id = ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (patient_id, limit)
        ).fetchall()

        return [dict(row) for row in rows]


# ---------------------------------------------------------------------------
# Direct execution
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")