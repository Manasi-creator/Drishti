"""
SQLite database layer for the DR screening portal.
Zero-setup, file-based DB — fine for an MVP/demo; swap for Postgres later if needed.
"""

import sqlite3
from contextlib import contextmanager
from datetime import datetime, timezone
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
DB_PATH = str(BASE_DIR / "screenings.db")

def init_db():
    with get_conn() as conn:
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


@contextmanager
def get_conn():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()


def insert_screening(record: dict) -> int:
    with get_conn() as conn:
        cursor = conn.execute("""
            INSERT INTO screenings (
                patient_id, original_filename, stored_filename, heatmap_filename,
                quality_acceptable, quality_reason, dr_grade, dr_grade_label,
                confidence, referable, class_probabilities, created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        row = conn.execute("SELECT * FROM screenings WHERE id = ?", (screening_id,)).fetchone()
        return dict(row) if row else None


def list_screenings(limit: int = 100):
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM screenings ORDER BY created_at DESC LIMIT ?", (limit,)
        ).fetchall()
        return [dict(r) for r in rows]

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully.")