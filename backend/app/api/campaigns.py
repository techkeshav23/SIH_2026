import os

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.db import get_db
from app.models import Campaign, Product, User
from app.models.schemas import BudgetIncrease, CampaignCreate, CampaignOut

router = APIRouter(prefix="/campaigns", tags=["campaigns"])


def _owned(db: Session, user: User, campaign_id: str) -> Campaign:
    c = db.get(Campaign, campaign_id)
    if not c or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Campaign not found")
    return c


def _read_product_image(product: Product | None) -> bytes | None:
    """Read the product's enhanced (or raw) image bytes directly from storage —
    GCS or local disk — so we can attach it to the ad creative. Returns None
    (never raises) if there's no image or it can't be read; the campaign is
    still created without the image/creative layer in that case."""
    if product is None:
        return None
    path = product.enhanced_image_url or product.raw_image_url
    if not path:
        return None
    filename = path.rsplit("/", 1)[-1]
    try:
        if settings.gcs_bucket:
            from app.core import gcs

            return gcs.get_image(filename)
        from app.services.image_ai import UPLOAD_DIR

        full_path = os.path.join(UPLOAD_DIR, filename)
        with open(full_path, "rb") as f:
            return f.read()
    except Exception:  # noqa: BLE001
        return None


@router.get("", response_model=list[CampaignOut])
def list_campaigns(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Campaign).where(Campaign.user_id == user.id).order_by(Campaign.created_at.desc())
    return list(db.scalars(stmt))


@router.post("", response_model=CampaignOut, status_code=status.HTTP_201_CREATED)
def create_campaign(
    body: CampaignCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Creates the campaign locally, then publishes a PAUSED campaign to each
    requested ad platform (best-effort — a platform failure never blocks the
    others or the local record; see app.services.meta_ads/google_ads). If the
    product has a photo, it's attached to the ad creative (Meta needs a linked
    Facebook Page for this — see settings.meta_page_id; skipped gracefully if
    not configured)."""
    c = Campaign(
        user_id=user.id,
        product_id=body.product_id,
        name=body.name,
        objective=body.objective,
        daily_budget=body.daily_budget,
        platforms=body.platforms,
        status="created",
    )
    db.add(c)
    db.commit()
    db.refresh(c)

    product = db.get(Product, body.product_id) if body.product_id else None
    image_bytes = _read_product_image(product)

    platform_ids: dict = {}
    platform_urls: dict = {}
    errors: list[str] = []

    if "meta" in body.platforms:
        from app.services import meta_ads

        result = meta_ads.create_campaign(
            body.name, body.objective, body.daily_budget, image_bytes
        )
        platform_ids["meta"] = result["id"]
        if result.get("url"):
            platform_urls["meta"] = result["url"]
        if result.get("error"):
            errors.append(f"meta: {result['error']}")
        if result.get("image_error"):
            errors.append(f"meta image: {result['image_error']}")

    if "google" in body.platforms:
        from app.services import google_ads

        result = google_ads.create_campaign(
            body.name, body.objective, body.daily_budget, image_bytes
        )
        platform_ids["google"] = result["id"]
        if result.get("url"):
            platform_urls["google"] = result["url"]
        if result.get("error"):
            errors.append(f"google: {result['error']}")

    c.platform_ids = platform_ids
    c.platform_urls = platform_urls
    c.error = "; ".join(errors) if errors else None
    db.commit()
    db.refresh(c)
    return c


@router.get("/{campaign_id}", response_model=CampaignOut)
def get_campaign(
    campaign_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _owned(db, user, campaign_id)


@router.post("/{campaign_id}/boost", response_model=CampaignOut)
def boost_budget(
    campaign_id: str,
    body: BudgetIncrease,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Increase a campaign's daily budget by `amount` (min ₹250, enforced by
    the schema). Updates the real platform campaign(s) best-effort, then the
    local record regardless — so the artisan's intended budget is never lost
    even if a platform call fails."""
    c = _owned(db, user, campaign_id)
    new_budget = c.daily_budget + body.amount

    errors: list[str] = []
    if "meta" in c.platforms and c.platform_ids.get("meta"):
        from app.services import meta_ads

        result = meta_ads.update_budget(c.platform_ids["meta"], new_budget)
        if not result.get("ok"):
            errors.append(f"meta: {result.get('error', 'update failed')}")

    if "google" in c.platforms and c.platform_ids.get("google"):
        from app.services import google_ads

        result = google_ads.update_budget(c.platform_ids["google"], new_budget)
        if not result.get("ok"):
            errors.append(f"google: {result.get('error', 'update failed')}")

    c.daily_budget = new_budget
    c.error = "; ".join(errors) if errors else None
    db.commit()
    db.refresh(c)
    return c
