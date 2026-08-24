"""Meta Marketing API adapter — creates a real campaign in the artisan's own
Meta (Facebook/Instagram) ad account.

Demo-safety: every campaign is created with status=PAUSED. Meta itself
documents this as the standard way to test the API — a PAUSED campaign is
visible in Ads Manager (so a judge can see it was really created) but never
enters the ad auction and never spends money.

Off by default (USE_META_ADS=false, or missing credentials) -> `create_campaign`
returns a functional stub (fake id) so the UI/demo never breaks even before
real Meta credentials are configured.
"""
import logging

import httpx

from app.core.config import settings

log = logging.getLogger("kalasetu.meta_ads")

_GRAPH_BASE = "https://graph.facebook.com"


def enabled() -> bool:
    return bool(
        settings.use_meta_ads
        and settings.meta_access_token
        and settings.meta_ad_account_id
    )


def create_campaign(name: str, objective: str = "OUTCOME_TRAFFIC") -> dict:
    """Create a PAUSED campaign. Always returns a dict with at least
    {"id": ..., "url": ...}; never raises — falls back to a stub on any
    disabled/misconfigured/API-error condition so the caller's flow never
    breaks."""
    if not enabled():
        return _stub_campaign(name)
    try:
        return _create_real(name, objective)
    except Exception as e:  # noqa: BLE001
        log.warning("Meta campaign create failed for %r: %s", name, e)
        return _stub_campaign(name, error=str(e)[:200])


def _create_real(name: str, objective: str) -> dict:
    account = settings.meta_ad_account_id.removeprefix("act_")
    url = f"{_GRAPH_BASE}/{settings.meta_api_version}/act_{account}/campaigns"
    resp = httpx.post(
        url,
        data={
            "name": name,
            "objective": objective,
            "status": "PAUSED",
            "special_ad_categories": "[]",
            # No campaign-level budget is set here (ad sets would carry their
            # own) — Meta now requires this to be explicit either way.
            "is_adset_budget_sharing_enabled": "false",
            "access_token": settings.meta_access_token,
        },
        timeout=20.0,
    )
    resp.raise_for_status()
    campaign_id = resp.json()["id"]
    return {
        "id": campaign_id,
        "url": f"https://adsmanager.facebook.com/adsmanager/manage/campaigns?act={account}&selected_campaign_ids={campaign_id}",
        "stub": False,
    }


def _stub_campaign(name: str, error: str | None = None) -> dict:
    import uuid

    fake_id = f"stub_{uuid.uuid4().hex[:12]}"
    log.info("Meta campaign stub used for %r (real API disabled/unavailable)", name)
    return {"id": fake_id, "url": None, "stub": True, "error": error}
