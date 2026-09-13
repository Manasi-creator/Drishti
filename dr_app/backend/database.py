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

        doctor_columns = {
            "phone": "TEXT",
            "date_of_birth": "TEXT",
            "gender": "TEXT",
            "medical_registration_number": "TEXT",
            "specialization": "TEXT",
            "qualification": "TEXT",
            "years_of_experience": "INTEGER",
            "hospital_clinic": "TEXT",
        }

        existing_columns = {
            row[1]
            for row in conn.execute("PRAGMA table_info(doctors)").fetchall()
        }
        for column_name, column_type in doctor_columns.items():
            if column_name not in existing_columns:
                conn.execute(
                    f"ALTER TABLE doctors ADD COLUMN {column_name} {column_type}"
                )

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
            "phone": "+91 98765 43210",
            "date_of_birth": "1988-03-14",
            "gender": "Female",
            "medical_registration_number": "MCI-AN-001",
            "specialization": "Retina",
            "qualification": "MBBS, MS (Ophthalmology)",
            "years_of_experience": 8,
            "hospital_clinic": "Drishti Eye Centre",
        },
        {
            "doctor_id": "DOC-002",
            "name": "Dr. Rohan Mehta",
            "email": "rohan.mehta@drishti.local",
            "password": "Drishti@123",
            "phone": "+91 98123 45678",
            "date_of_birth": "1984-11-07",
            "gender": "Male",
            "medical_registration_number": "MCI-RM-002",
            "specialization": "General Ophthalmology",
            "qualification": "MBBS, DOMS",
            "years_of_experience": 12,
            "hospital_clinic": "Mehta Vision Clinic",
        },
        {
            "doctor_id": "DOC-003",
            "name": "Dr. Priya Kulkarni",
            "email": "priya.kulkarni@drishti.local",
            "password": "Drishti@123",
            "phone": "+91 99887 66554",
            "date_of_birth": "1990-06-19",
            "gender": "Female",
            "medical_registration_number": "MCI-PK-003",
            "specialization": "Retinal Imaging",
            "qualification": "MBBS, DNB (Ophthalmology)",
            "years_of_experience": 6,
            "hospital_clinic": "Kulkarni Eye Hospital",
        },
    ]

    for doctor in default_doctors:
        with get_conn() as conn:
            existing = conn.execute(
                "SELECT * FROM doctors WHERE doctor_id = ? OR email = ?",
                (doctor["doctor_id"], doctor["email"]),
            ).fetchone()

            if existing is not None:
                conn.execute(
                    """
                    UPDATE doctors
                    SET name = ?,
                        email = ?,
                        phone = COALESCE(NULLIF(phone, ''), ?),
                        date_of_birth = COALESCE(NULLIF(date_of_birth, ''), ?),
                        gender = COALESCE(NULLIF(gender, ''), ?),
                        medical_registration_number = COALESCE(NULLIF(medical_registration_number, ''), ?),
                        specialization = COALESCE(NULLIF(specialization, ''), ?),
                        qualification = COALESCE(NULLIF(qualification, ''), ?),
                        years_of_experience = COALESCE(years_of_experience, ?),
                        hospital_clinic = COALESCE(NULLIF(hospital_clinic, ''), ?)
                    WHERE doctor_id = ?
                    """,
                    (
                        doctor["name"],
                        doctor["email"],
                        doctor["phone"],
                        doctor["date_of_birth"],
                        doctor["gender"],
                        doctor["medical_registration_number"],
                        doctor["specialization"],
                        doctor["qualification"],
                        doctor["years_of_experience"],
                        doctor["hospital_clinic"],
                        doctor["doctor_id"],
                    ),
                )
                conn.commit()
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
                    created_at,
                    phone,
                    date_of_birth,
                    gender,
                    medical_registration_number,
                    specialization,
                    qualification,
                    years_of_experience,
                    hospital_clinic
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    doctor["doctor_id"],
                    doctor["name"],
                    doctor["email"],
                    hash_password(doctor["password"]),
                    "doctor",
                    1,
                    datetime.now(timezone.utc).isoformat(),
                    doctor["phone"],
                    doctor["date_of_birth"],
                    doctor["gender"],
                    doctor["medical_registration_number"],
                    doctor["specialization"],
                    doctor["qualification"],
                    doctor["years_of_experience"],
                    doctor["hospital_clinic"],
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


def update_doctor_profile(doctor_id: str, updates: dict):
    if not updates:
        return get_doctor_by_id(doctor_id)

    allowed_fields = {
        "name",
        "email",
        "phone",
        "date_of_birth",
        "gender",
        "medical_registration_number",
        "specialization",
        "qualification",
        "years_of_experience",
        "hospital_clinic",
    }

    sanitized_updates = {
        key: value for key, value in updates.items() if key in allowed_fields
    }

    if not sanitized_updates:
        return get_doctor_by_id(doctor_id)

    assignments = ", ".join(f"{field} = ?" for field in sanitized_updates)
    values = list(sanitized_updates.values()) + [doctor_id]

    with get_conn() as conn:
        conn.execute(
            f"UPDATE doctors SET {assignments} WHERE doctor_id = ?",
            tuple(values),
        )
        conn.commit()

    return get_doctor_by_id(doctor_id)


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