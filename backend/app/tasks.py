"""Celery tasks for the AI pipeline (image enhance, voice cataloging).

Each task opens its own DB session and reads its input from a temp file path
(see app/core/storage.py). On failure the product is marked back to `draft`
so the app doesn't get stuck in `processing`.
"""
from app.core.celery_app import celery_app
from app.core.db import SessionLocal
from app.core.storage import read_and_cleanup
from app.models import Product, VoiceNote
from app.services import image_ai, language_ai


@celery_app.task(name="ai.enhance_image", bind=True, max_retries=2, default_retry_delay=5)
def enhance_image_task(self, product_id: str, image_path: str):
    data = read_and_cleanup(image_path)
    db = SessionLocal()
    try:
        p = db.get(Product, product_id)
        if not p:
            return
        try:
            p.enhanced_image_url = image_ai.enhance(data, product_id)
            p.status = "ready"
        except Exception as exc:  # noqa: BLE001
            p.status = "draft"
            db.commit()
            raise self.retry(exc=exc)
        db.commit()
    finally:
        db.close()


@celery_app.task(name="ai.catalog_voice", bind=True, max_retries=2, default_retry_delay=5)
def catalog_voice_task(self, product_id: str, audio_path: str, mime_type: str, source_lang: str):
    data = read_and_cleanup(audio_path)
    db = SessionLocal()
    try:
        p = db.get(Product, product_id)
        if not p:
            return
        try:
            listing = language_ai.catalog_from_audio(data, mime_type, source_lang)
            db.add(VoiceNote(product_id=product_id, transcript_raw=listing.transcript,
                             transcript_lang=source_lang, translated_en=listing.description_en))
            p.title_en, p.title_hi = listing.title_en, listing.title_hi
            p.desc_en, p.desc_hi = listing.description_en, listing.description_hi
            p.category, p.material, p.tags = listing.category, listing.material, listing.tags
            p.status = "ready"
        except Exception as exc:  # noqa: BLE001
            p.status = "draft"
            db.commit()
            raise self.retry(exc=exc)
        db.commit()
    finally:
        db.close()
