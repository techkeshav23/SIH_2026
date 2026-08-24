"""Google Ads API adapter — placeholder for creating a real PAUSED campaign in
the artisan's own Google Ads account.

Google Ads campaign creation needs 4 linked resources (CampaignBudget ->
Campaign -> AdGroup -> AdGroupAd) plus OAuth + a developer token, which is a
heavier setup than Meta. USE_GOOGLE_ADS is off by default, so this always
returns a functional stub today — wire `_create_real` up to the
google-ads-python client once credentials are available, following the exact
same enabled()/create_campaign()/stub shape as app.services.meta_ads.
"""
import logging
import uuid

from app.core.config import settings

log = logging.getLogger("kalasetu.google_ads")


def enabled() -> bool:
    return bool(
        settings.use_google_ads
        and settings.google_ads_developer_token
        and settings.google_ads_refresh_token
        and settings.google_ads_customer_id
    )


def create_campaign(name: str, objective: str = "OUTCOME_TRAFFIC") -> dict:
    if not enabled():
        return _stub_campaign(name)
    try:
        return _create_real(name, objective)
    except Exception as e:  # noqa: BLE001
        log.warning("Google Ads campaign create failed for %r: %s", name, e)
        return _stub_campaign(name, error=str(e)[:200])


def _create_real(name: str, objective: str) -> dict:
    # TODO(prod): use google-ads-python (CampaignBudgetService, CampaignService,
    # AdGroupService, AdGroupAdService), all mutate operations with the created
    # Campaign's status set to PAUSED. Requires an approved developer token for
    # production customer ids (test accounts work immediately).
    raise NotImplementedError("Wire google-ads-python campaign creation here")


def _stub_campaign(name: str, error: str | None = None) -> dict:
    fake_id = f"stub_{uuid.uuid4().hex[:12]}"
    log.info("Google Ads campaign stub used for %r (real API disabled/unavailable)", name)
    return {"id": fake_id, "url": None, "stub": True, "error": error}
