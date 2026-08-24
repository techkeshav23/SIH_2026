from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Campaign, Product, User
from app.models.schemas import BudgetIncrease, CampaignCreate, CampaignOut
from app.services import campaign_service, meta_ads

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
    """Create a custom campaign (optionally tied to a product) — always PAUSED
    on the ad platform, so it never spends until the artisan resumes it.

    To promote a single product with its photo + AI caption, use
    POST /promote/boost instead; both persist the same Campaign shape."""
    if body.daily_budget < meta_ads.MIN_DAILY_BUDGET_INR:
        raise HTTPException(
            status.HTTP_422_UNPROCESSABLE_ENTITY,
            f"Daily budget must be at least ₹{meta_ads.MIN_DAILY_BUDGET_INR:.0f} "
            "(the ad platform's minimum)",
        )

    product = None
    if body.product_id:
        product = db.get(Product, body.product_id)
        if not product or product.user_id != user.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    return campaign_service.create(
        db,
        user,
        name=body.name,
        daily_budget_inr=body.daily_budget,
        product=product,
        objective=body.objective,
        platforms=body.platforms,
    )


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
    """Raise this campaign's daily budget by `amount` rupees. The increase is
    applied to the ad set (where the budget actually lives) and mirrored
    locally."""
    c = _owned(db, user, campaign_id)
    return campaign_service.set_daily_budget(db, c, c.daily_budget + body.amount)
