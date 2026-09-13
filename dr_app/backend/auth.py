import os
from datetime import datetime, timedelta, timezone

import jwt
from passlib.context import CryptContext

SECRET_KEY = os.getenv("DRISHTI_JWT_SECRET", "dev-local-jwt-secret-change-me")
ALGORITHM = "HS256"

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    return pwd_context.verify(password, password_hash)


def create_access_token(doctor_id: str, role: str) -> str:
    expiry = datetime.now(timezone.utc) + timedelta(hours=12)
    payload = {
        "sub": doctor_id,
        "role": role,
        "exp": expiry,
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str):
    if not token:
        raise ValueError("Missing token")
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
