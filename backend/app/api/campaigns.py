from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Campaign, User
from app.models.schemas import CampaignCreate, CampaignOut

router = APIRouter(prefix="/campaigns", tags=["campaigns"])


def _owned(db: Session, user: User, campaign_id: str) -> Campaign:
    c = db.get(Campaign, campaign_id)
    if not c or c.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Campaign not found")
    return c


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
    others or the local record; see app.services.meta_ads/google_ads)."""
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

    platform_ids: dict = {}
    platform_urls: dict = {}
    errors: list[str] = []

    if "meta" in body.platforms:
        from app.services import meta_ads

        result = meta_ads.create_campaign(body.name, body.objective)
        platform_ids["meta"] = result["id"]
        if result.get("url"):
            platform_urls["meta"] = result["url"]
        if result.get("error"):
            errors.append(f"meta: {result['error']}")

    if "google" in body.platforms:
        from app.services import google_ads

        result = google_ads.create_campaign(body.name, body.objective)
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
