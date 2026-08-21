"""Upload validation for AI endpoints — size, MIME type, and (for images)
content sniffing so a mislabelled/broken file is rejected before hitting the
AI pipeline.
"""
import io

from fastapi import HTTPException, UploadFile, status
from PIL import Image, UnidentifiedImageError

from app.core.config import settings


def _too_big(size: int) -> bool:
    return size > settings.max_upload_mb * 1024 * 1024


def validate_image(file: UploadFile, data: bytes) -> None:
    if _too_big(len(data)):
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            f"Image exceeds {settings.max_upload_mb} MB")
    if file.content_type and file.content_type not in settings.image_types:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                            f"Unsupported image type: {file.content_type}")
    # content sniff: must actually be a decodable image
    try:
        Image.open(io.BytesIO(data)).verify()
    except (UnidentifiedImageError, OSError):
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "File is not a valid image")


def validate_audio(file: UploadFile, data: bytes) -> None:
    if _too_big(len(data)):
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                            f"Audio exceeds {settings.max_upload_mb} MB")
    if not data:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Empty audio file")
    if file.content_type and file.content_type not in settings.audio_types:
        raise HTTPException(status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
                            f"Unsupported audio type: {file.content_type}")
