"""Google Ads adapter — NOT IMPLEMENTED YET.

Creating a Google Ads campaign needs four linked resources (CampaignBudget ->
Campaign -> AdGroup -> AdGroupAd) plus OAuth and a developer token that must be
approved for production customer ids. That's a much heavier setup than Meta, so
it isn't wired up.

Deliberate choice: rather than returning a fake "success" (which made real
Meta-only campaigns look like demos in the UI), `create_campaign` reports
`available: False` with a reason. The API layer surfaces that as a per-platform
error and does not record a fake platform id.

To implement: mirror app.services.meta_ads — one `create_paused_campaign`-style
entry point that builds everything PAUSED, and an `update_budget` that targets
the CampaignBudget resource.
"""
import logging

from app.core.config import settings

log = logging.getLogger("kalasetu.google_ads")

_UNAVAILABLE = "Google Ads isn't connected yet — campaigns run on Meta for now"


def enabled() -> bool:
    return bool(
        settings.use_google_ads
        and settings.google_ads_developer_token
        and settings.google_ads_refresh_token
        and settings.google_ads_customer_id
    )


def create_campaign(*_args, **_kwargs) -> dict:
    log.info("Google Ads campaign requested but the integration is not implemented")
    return {"available": False, "error": _UNAVAILABLE}


def update_budget(*_args, **_kwargs) -> dict:
    return {"ok": False, "error": _UNAVAILABLE}
