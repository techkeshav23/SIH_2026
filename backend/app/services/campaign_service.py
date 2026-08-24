"""Shared campaign creation/update logic.

Both entry points — POST /campaigns (a custom or shop-level campaign) and
POST /promote/boost (promote one product) — funnel through here, so a campaign
looks the same in the database and on Meta no matter which screen created it.
That's what makes the budget-boost card work against either one.

Storage contract for Campaign.platform_ids:
    {"meta": <campaign id>, "meta_adset": <ad set id>, "meta_ad": <ad id>}
`meta_adset` is the object budget edits target (see app.services.meta_ads).
"""
import logging
import os

from sqlalchemy.orm import Session

from app.core.config import settings
from app.models import Campaign, Product, User
from app.services import meta_ads

log = logging.getLogger("kalasetu.campaigns")

# Every campaign is created PAUSED on the ad platform and stays that way until
# the artisan resumes it in Ads Manager — so it can never spend unattended.
STATUS_PAUSED = "paused"
STATUS_FAILED = "failed"


def read_product_image(product: Product | None) -> bytes | None:
    """Product's studio (or raw) image bytes, read straight from storage — GCS
    in prod, local disk in dev. Returns None (never raises) when there's no
    image or it can't be read; the campaign is then created without a creative.
    """
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

        with open(os.path.join(UPLOAD_DIR, filename), "rb") as f:
            return f.read()
    except Exception:  # noqa: BLE001
        log.info("Could not read image for product %s", getattr(product, "id", "?"))
        return None


def create(
    db: Session,
    user: User,
    *,
    name: str,
    daily_budget_inr: float,
    product: Product | None = None,
    objective: str = "OUTCOME_TRAFFIC",
    days: int | None = None,
    platforms: list[str] | None = None,
    caption: str | None = None,
) -> Campaign:
    """Publish a PAUSED campaign to the requested platforms and persist it.

    Best-effort by design: a platform failure is recorded on `Campaign.error`
    rather than raised, so the artisan's intent is never lost. The returned
    Campaign is already committed.
    """
    platforms = platforms or ["meta"]
    errors: list[str] = []
    platform_ids: dict = {}
    platform_urls: dict = {}

    if "meta" in platforms:
        result = meta_ads.create_paused_campaign(
            name,
            daily_budget_inr=daily_budget_inr,
            objective=objective,
            days=days,
            caption=caption,
            image_bytes=read_product_image(product),
        )
        platform_ids["meta"] = result["campaign_id"]
        platform_ids["meta_adset"] = result["adset_id"]
        if result.get("ad_id"):
            platform_ids["meta_ad"] = result["ad_id"]
        if result.get("url"):
            platform_urls["meta"] = result["url"]
        for key in ("error", "creative_error"):
            if result.get(key):
                errors.append(f"meta: {result[key]}")

    # Unimplemented platforms report why instead of recording a fake id — a fake
    # id would make a genuinely-real Meta campaign look like a demo in the UI.
    for other in [p for p in platforms if p != "meta"]:
        from app.services import google_ads

        errors.append(f"{other}: {google_ads.create_campaign().get('error')}")

    c = Campaign(
        user_id=user.id,
        product_id=product.id if product else None,
        name=name,
        objective=objective,
        daily_budget=round(daily_budget_inr, 2),
        platforms=platforms,
        status=STATUS_PAUSED if platform_ids else STATUS_FAILED,
        platform_ids=platform_ids,
        platform_urls=platform_urls,
        error="; ".join(errors) if errors else None,
    )
    db.add(c)
    db.commit()
    db.refresh(c)
    return c


def set_daily_budget(db: Session, c: Campaign, new_daily_inr: float) -> Campaign:
    """Point the campaign's ad set at a new daily budget, then persist.

    The local record is updated even if the platform call fails (with the reason
    on `Campaign.error`) so the artisan's chosen budget isn't silently dropped.
    """
    errors: list[str] = []
    if "meta" in (c.platforms or []):
        result = meta_ads.update_budget(c.platform_ids.get("meta_adset"), new_daily_inr)
        if not result.get("ok"):
            errors.append(f"meta: {result.get('error', 'update failed')}")

    c.daily_budget = round(new_daily_inr, 2)
    c.error = "; ".join(errors) if errors else None
    db.commit()
    db.refresh(c)
    return c
