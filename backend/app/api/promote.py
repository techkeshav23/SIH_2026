"""Promote — marketing helpers for the app's Promote/Poster feature.

Two things live here: an AI marketing caption for a product (Gemini-written,
falls back to a template), and Boost — promote one product as a real ad.

Boost creates a PAUSED campaign in the artisan's own Meta ad account (never
spends, never goes live until they resume it) via app.services.campaign_service,
the same path POST /campaigns uses — so a boost and a custom campaign are
identical in the database and in Ads Manager. See docs/PROMOTE_ADS_API.md."""
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Product, User
from app.services import campaign_service, language_ai, meta_ads

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
    # Total spend the artisan wants, spread over `days`. The per-day rate sent
    # to Meta is total/days, floored at the platform minimum.
    budget_rupees: float = Field(gt=0)
    days: int = Field(gt=0, le=30)
    audience: str = "nearby"        # "nearby" | "india"
    image_source: str = "studio"    # "poster" | "studio" | "gallery"


class BoostOut(BaseModel):
    # "paused" is the honest state: everything is created PAUSED on Meta and
    # only spends once the artisan resumes it. "failed" if no platform accepted.
    status: str                          # paused | failed
    campaign_id: str | None = None       # our Campaign id
    ad_id: str | None = None             # Meta ad id, when a creative was built
    daily_budget: float = 0              # per-day rate actually sent to Meta
    estimated_reach: list[int] = []
    permalink: str | None = None
    note: str | None = None              # why the image/creative was skipped, etc.


@router.post("/boost", response_model=BoostOut)
def boost(
    body: BoostIn,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Promote one product as a real (PAUSED) ad — see docs/PROMOTE_ADS_API.md."""
    p = db.get(Product, body.product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    # Spread the total over the run, but never below Meta's per-day floor —
    # otherwise the platform rejects the ad set outright.
    daily = max(body.budget_rupees / body.days, meta_ads.MIN_DAILY_BUDGET_INR)

    title = p.title_hi or p.title_en or "Handmade product"
    caption = language_ai.marketing_caption(
        title,
        p.desc_hi or p.desc_en or "",
        float(p.final_price or p.suggested_price_max or 0),
        "hi",
    )

    # image_source "poster"/"gallery" aren't uploaded from the client yet (the
    # poster is rendered on-device), so the studio photo backs all three for now.
    c = campaign_service.create(
        db,
        user,
        name=f"KalaSetu — {title}"[:190],
        daily_budget_inr=daily,
        product=p,
        days=body.days,
        platforms=["meta"],
        caption=caption,
    )

    if c.status == campaign_service.STATUS_FAILED:
        raise HTTPException(status.HTTP_502_BAD_GATEWAY, c.error or "Ad platform error")

    return BoostOut(
        status=c.status,
        campaign_id=c.id,
        ad_id=c.platform_ids.get("meta_ad"),
        daily_budget=c.daily_budget,
        estimated_reach=meta_ads.estimated_reach(daily, body.days),
        permalink=c.platform_urls.get("meta"),
        note=c.error,
    )
