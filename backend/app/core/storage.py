"""Temp storage for uploads handed off to async jobs.

The API persists the raw upload to disk and passes a *path* (not bytes) to the
Celery task. This keeps the broker payload small and — with a Redis broker —
makes jobs restart-safe: the file is on disk and the job reference is in Redis.

For multi-host deploys, back this with object storage (S3/Cloudinary) instead.
"""
import os
import uuid

_TMP = os.path.join(os.path.dirname(__file__), "..", "..", "uploads", "tmp")
os.makedirs(_TMP, exist_ok=True)


def save_temp(data: bytes, suffix: str = "") -> str:
    path = os.path.join(_TMP, f"{uuid.uuid4().hex}{suffix}")
    with open(path, "wb") as f:
        f.write(data)
    return path


def read_and_cleanup(path: str) -> bytes:
    with open(path, "rb") as f:
        data = f.read()
    try:
        os.remove(path)
    except OSError:
        pass
    return data
