"""Promote — marketing helpers for the app's Promote/Poster feature.

An AI marketing caption for a product (Gemini-written, falls back to a
template), and the paid Boost/ads endpoint (Meta Marketing API) per the
contract in docs/PROMOTE_ADS_API.md. Boost creates a real, PAUSED campaign
in the artisan's own Meta ad account — never spends, never goes live — using
app.services.meta_ads (off/misconfigured -> a functional stub, same
demo-safety pattern as app.services.meta_ads.create_campaign)."""
import os

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.db import get_db
from app.models import Campaign, Product, User
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


class BoostIn(BaseModel):
    product_id: str
    budget_rupees: float = Field(gt=0)
    days: int = Field(gt=0, le=30)
    audience: str = "nearby"        # "nearby" | "india"
    image_source: str = "studio"    # "poster" | "studio" | "gallery"


class BoostOut(BaseModel):
    status: str                          # under_review | active | rejected | failed
    ad_id: str | None = None
    campaign_id: str | None = None
    estimated_reach: list[int] = []
    permalink: str | None = None


def _read_product_image(product: Product) -> bytes | None:
    """Read the product's studio (enhanced) image bytes directly from storage
    — mirrors app.api.campaigns._read_product_image. Returns None if there's
    no image or it can't be read (the boost still proceeds without an image)."""
    path = product.enhanced_image_url or product.raw_image_url
    if not path:
        return None
    filename = path.rsplit("/", 1)[-1]
    try:
        if settings.gcs_bucket:
            from app.core import gcs

            return gcs.get_image(filename)
        from app.services.image_ai import UPLOAD_DIR

        with open(os.path.join(UPLOAD_DIR, filename), "rb") as f:
            return f.read()
    except Exception:  # noqa: BLE001
        return None


@router.post("/boost", response_model=BoostOut)
def boost(
    body: BoostIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Create a real (PAUSED) ad campaign for one product — see
    docs/PROMOTE_ADS_API.md for the full contract."""
    p = db.get(Product, body.product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    from app.services import meta_ads

    # image_source == "poster"/"gallery" isn't uploaded from the client yet in
    # this pass (the Flutter Boost screen renders the poster on-device and
    # doesn't send it up) — fall back to the studio photo either way so the
    # ad still gets a real image whenever one exists.
    image_bytes = _read_product_image(p) if body.image_source in ("studio", "poster", "gallery") else None

    hi_title = p.title_hi or p.title_en or "Handmade product"
    caption = language_ai.marketing_caption(
        hi_title, p.desc_hi or p.desc_en or "", float(p.final_price or p.suggested_price_max or 0), "hi"
    )

    name = f"KalaSetu — {hi_title}"[:190]
    result = meta_ads.boost_product(
        name=name,
        budget_rupees=body.budget_rupees,
        days=body.days,
        audience=body.audience,
        caption=caption,
        image_bytes=image_bytes,
    )
    if result.get("status") == "failed":
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, result.get("error", "Meta API error"))

    # Persist it as a Campaign so a boost created here is visible everywhere the
    # artisan looks (GET /campaigns, the Marketing screen, the product page's
    # budget-boost card) — same source of truth as POST /campaigns.
    campaign_id = str(result.get("campaign_id") or "")
    platform_ids: dict = {"meta": campaign_id} if campaign_id else {}
    if result.get("ad_id"):
        platform_ids["meta_ad"] = str(result["ad_id"])
    c = Campaign(
        user_id=user.id,
        product_id=p.id,
        name=name,
        objective="OUTCOME_TRAFFIC",
        # The ad set spends per day; store the per-day rate so the boost card's
        # "current daily budget" matches what Meta actually has.
        daily_budget=round(body.budget_rupees / max(body.days, 1), 2),
        platforms=["meta"],
        status="created",
        platform_ids=platform_ids,
        platform_urls={"meta": result["permalink"]} if result.get("permalink") else {},
    )
    db.add(c)
    db.commit()

    return BoostOut(**{k: v for k, v in result.items() if k in BoostOut.model_fields})
