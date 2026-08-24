"""Promote — marketing helpers for the app's Promote/Poster feature.

Currently: an AI marketing caption for a product (Gemini-written, falls back to a
template). The paid Boost/ads endpoint (Meta Marketing API) is separate — see
docs/PROMOTE_ADS_API.md (the friend's part)."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Product, User
from app.services import language_ai

router = APIRouter(prefix="/promote", tags=["promote"])


class CaptionIn(BaseModel):
    product_id: str
    lang: str = "hi"  # "hi" | "en"


class CaptionOut(BaseModel):
    caption: str


@router.post("/caption", response_model=CaptionOut)
def caption(
    body: CaptionIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = db.get(Product, body.product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    hi = body.lang == "hi"
    title = (p.title_hi if hi else p.title_en) or p.title_en or p.title_hi or "Handmade product"
    desc = (p.desc_hi if hi else p.desc_en) or p.desc_en or p.desc_hi or ""
    price = float(p.final_price or p.suggested_price_max or 0)
    return CaptionOut(caption=language_ai.marketing_caption(title, desc, price, body.lang))
