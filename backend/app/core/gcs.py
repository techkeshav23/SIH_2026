"""Durable image storage on Google Cloud Storage.

Cloud Run's local disk is ephemeral (wiped on every deploy/restart), so enhanced
product images must live in GCS. The bucket is private; images are served back
through the API (/uploads/{name}) so no public bucket exposure is needed.
"""
import functools

from app.core.config import settings

enabled = bool(settings.gcs_bucket)


@functools.lru_cache(maxsize=1)
def _client():
    from google.cloud import storage

    return storage.Client()


def _blob(name: str):
    return _client().bucket(settings.gcs_bucket).blob(f"uploads/{name}")


def put_image(name: str, data: bytes) -> None:
    _blob(name).upload_from_string(data, content_type="image/jpeg")


def get_image(name: str) -> bytes | None:
    b = _blob(name)
    if not b.exists():
        return None
    return b.download_as_bytes()
