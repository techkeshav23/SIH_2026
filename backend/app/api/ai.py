import mimetypes

from fastapi import APIRouter, BackgroundTasks, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import SessionLocal, get_db
from app.models import Product, User, VoiceNote
from app.models.schemas import CatalogFromText, JobAccepted, ProductOut
from app.services import image_ai, language_ai

router = APIRouter(prefix="/ai", tags=["ai"])


def _owned(db: Session, user: User, product_id: str) -> Product:
    p = db.get(Product, product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    return p


# ---------- F1: image enhance (async) ----------
def _enhance_task(product_id: str, raw_bytes: bytes):
    db = SessionLocal()
    try:
        p = db.get(Product, product_id)
        if not p:
            return
        p.enhanced_image_url = image_ai.enhance(raw_bytes, product_id)
        p.status = "ready"
        db.commit()
    finally:
        db.close()


@router.post("/enhance-image", response_model=JobAccepted, status_code=status.HTTP_202_ACCEPTED)
async def enhance_image(
    background: BackgroundTasks,
    product_id: str = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = _owned(db, user, product_id)
    raw = await file.read()
    p.status = "processing"
    db.commit()
    background.add_task(_enhance_task, product_id, raw)
    return JobAccepted(product_id=product_id, status="processing")


# ---------- F2: voice -> listing (async) ----------
def _catalog_task(product_id: str, audio_bytes: bytes, mime_type: str, source_lang: str):
    db = SessionLocal()
    try:
        p = db.get(Product, product_id)
        if not p:
            return
        # single Gemini multimodal call: audio -> transcript + EN/HI listing
        listing = language_ai.catalog_from_audio(audio_bytes, mime_type, source_lang)
        db.add(VoiceNote(product_id=product_id, transcript_raw=listing.transcript,
                         transcript_lang=source_lang, translated_en=listing.description_en))
        p.title_en, p.title_hi = listing.title_en, listing.title_hi
        p.desc_en, p.desc_hi = listing.description_en, listing.description_hi
        p.category, p.material, p.tags = listing.category, listing.material, listing.tags
        p.status = "ready"
        db.commit()
    finally:
        db.close()


def _audio_mime(file: UploadFile) -> str:
    mime = file.content_type
    if not mime or mime == "application/octet-stream":
        guessed, _ = mimetypes.guess_type(file.filename or "")
        mime = guessed or "audio/wav"
    return mime


@router.post("/catalog-from-voice", response_model=JobAccepted, status_code=status.HTTP_202_ACCEPTED)
async def catalog_from_voice(
    background: BackgroundTasks,
    product_id: str = Form(...),
    file: UploadFile = File(...),
    source_lang: str = Form("hi"),
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = _owned(db, user, product_id)
    audio = await file.read()
    mime = _audio_mime(file)
    p.status = "processing"
    db.commit()
    background.add_task(_catalog_task, product_id, audio, mime, source_lang)
    return JobAccepted(product_id=product_id, status="processing")


# ---------- F2 fallback: typed text -> listing (sync) ----------
@router.post("/catalog-from-text", response_model=ProductOut)
def catalog_from_text(
    body: CatalogFromText,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = _owned(db, user, body.product_id)
    listing = language_ai.generate_listing(body.text, p.category or "", p.material or "")
    p.title_en, p.title_hi = listing.title_en, listing.title_hi
    p.desc_en, p.desc_hi = listing.description_en, listing.description_hi
    p.category, p.material, p.tags = listing.category, listing.material, listing.tags
    p.status = "ready"
    db.commit()
    db.refresh(p)
    return p
