import mimetypes

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.deps import enforce_ai_quota
from app.core.db import get_db
from app.core.limiter import rate_limit
from app.core.storage import save_temp
from app.core.uploads import validate_audio, validate_image
from app.models import Product, User
from app.models.schemas import CatalogFromText, JobAccepted, ProductOut
from app.services import language_ai
from app.tasks import catalog_voice_task, enhance_image_task

router = APIRouter(prefix="/ai", tags=["ai"])

_ai_limit = rate_limit("ai", max_calls=30, window_sec=60)


def _owned(db: Session, user: User, product_id: str) -> Product:
    p = db.get(Product, product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    return p


def _audio_mime(file: UploadFile) -> str:
    mime = file.content_type
    if not mime or mime == "application/octet-stream":
        guessed, _ = mimetypes.guess_type(file.filename or "")
        mime = guessed or "audio/wav"
    return mime


# ---------- F1: image enhance (durable job) ----------
@router.post("/enhance-image", response_model=JobAccepted, status_code=status.HTTP_202_ACCEPTED)
async def enhance_image(
    product_id: str = Form(...),
    file: UploadFile = File(...),
    user: User = Depends(enforce_ai_quota),
    db: Session = Depends(get_db),
    _: None = Depends(_ai_limit),
):
    p = _owned(db, user, product_id)
    raw = await file.read()
    validate_image(file, raw)
    path = save_temp(raw, ".img")
    p.status = "processing"
    db.commit()
    enhance_image_task.delay(product_id, path)
    return JobAccepted(product_id=product_id, status="processing")


# ---------- F2: voice -> listing (durable job) ----------
@router.post("/catalog-from-voice", response_model=JobAccepted, status_code=status.HTTP_202_ACCEPTED)
async def catalog_from_voice(
    product_id: str = Form(...),
    file: UploadFile = File(...),
    source_lang: str = Form("hi"),
    user: User = Depends(enforce_ai_quota),
    db: Session = Depends(get_db),
    _: None = Depends(_ai_limit),
):
    p = _owned(db, user, product_id)
    audio = await file.read()
    validate_audio(file, audio)
    mime = _audio_mime(file)
    path = save_temp(audio, ".audio")
    p.status = "processing"
    db.commit()
    catalog_voice_task.delay(product_id, path, mime, source_lang)
    return JobAccepted(product_id=product_id, status="processing")


# ---------- F2 fallback: typed text -> listing (sync) ----------
@router.post("/catalog-from-text", response_model=ProductOut)
def catalog_from_text(
    body: CatalogFromText,
    user: User = Depends(enforce_ai_quota),
    db: Session = Depends(get_db),
    _: None = Depends(_ai_limit),
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
