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


def _account() -> str:
    return settings.meta_ad_account_id.removeprefix("act_")


def _manager_url(campaign_id: str) -> str:
    return (
        "https://adsmanager.facebook.com/adsmanager/manage/campaigns"
        f"?act={_account()}&selected_campaign_ids={campaign_id}"
    )


def create_campaign(
    name: str,
    objective: str = "OUTCOME_TRAFFIC",
    daily_budget_inr: float = 200.0,
    image_bytes: bytes | None = None,
) -> dict:
    """Create a PAUSED campaign, with the daily budget set directly on the
    campaign (campaign budget optimization — no separate AdSet budget needed).

    If `image_bytes` is given AND a Facebook Page is configured
    (settings.meta_page_id), also creates an AdSet + image AdCreative + Ad so
    the product photo actually shows up in Ads Manager / preview. Without a
    Page this step is skipped — the campaign is still created normally.

    Always returns a dict with at least {"id": ..., "url": ...}; never raises
    — falls back to a stub on any disabled/misconfigured/API-error condition
    so the caller's flow never breaks."""
    if not enabled():
        return _stub_campaign(name)
    try:
        return _create_real(name, objective, daily_budget_inr, image_bytes)
    except Exception as e:  # noqa: BLE001
        log.warning("Meta campaign create failed for %r: %s", name, e)
        return _stub_campaign(name, error=str(e)[:200])


def update_budget(campaign_id: str, daily_budget_inr: float) -> dict:
    """Update an existing (real, non-stub) campaign's daily budget. Never
    raises — returns {"ok": False, "error": ...} on failure so the caller can
    decide whether to still update the local record."""
    if not enabled() or campaign_id.startswith("stub_"):
        return {"ok": False, "error": "meta ads not enabled or stub campaign"}
    try:
        url = f"{_GRAPH_BASE}/{settings.meta_api_version}/{campaign_id}"
        resp = httpx.post(
            url,
            data={
                "daily_budget": _to_paise(daily_budget_inr),
                "access_token": settings.meta_access_token,
            },
            timeout=20.0,
        )
        resp.raise_for_status()
        return {"ok": True}
    except Exception as e:  # noqa: BLE001
        log.warning("Meta budget update failed for %s: %s", campaign_id, e)
        return {"ok": False, "error": str(e)[:200]}


def _to_paise(inr: float) -> str:
    # Meta budgets are in the account's currency's minor unit (paise for INR).
    return str(int(round(inr * 100)))


def _create_real(
    name: str, objective: str, daily_budget_inr: float, image_bytes: bytes | None
) -> dict:
    account = _account()
    resp = httpx.post(
        f"{_GRAPH_BASE}/{settings.meta_api_version}/act_{account}/campaigns",
        data={
            "name": name,
            "objective": objective,
            "status": "PAUSED",
            "special_ad_categories": "[]",
            "daily_budget": _to_paise(daily_budget_inr),
            "access_token": settings.meta_access_token,
        },
        timeout=20.0,
    )
    resp.raise_for_status()
    campaign_id = resp.json()["id"]
    result = {"id": campaign_id, "url": _manager_url(campaign_id), "stub": False}

    if image_bytes and settings.meta_page_id:
        try:
            _attach_image_ad(account, campaign_id, name, image_bytes)
        except Exception as e:  # noqa: BLE001
            # The campaign itself is real and created — don't fail the whole
            # operation just because the image/creative layer couldn't attach.
            log.warning("Meta image ad attach failed for campaign %s: %s", campaign_id, e)
            result["image_error"] = str(e)[:200]
    return result


def _attach_image_ad(account: str, campaign_id: str, name: str, image_bytes: bytes) -> None:
    """AdSet (PAUSED, linked to the campaign) -> AdImage upload -> AdCreative
    (object_story_spec, needs meta_page_id) -> Ad (PAUSED). Mirrors Meta's own
    documented "create a paused ad for testing" flow."""
    import base64

    token = settings.meta_access_token
    base = f"{_GRAPH_BASE}/{settings.meta_api_version}"

    # 1. AdSet — required parent for any Ad; PAUSED so it never enters delivery.
    adset_resp = httpx.post(
        f"{base}/act_{account}/adsets",
        data={
            "name": f"{name} — AdSet",
            "campaign_id": campaign_id,
            "status": "PAUSED",
            "billing_event": "IMPRESSIONS",
            "optimization_goal": "LINK_CLICKS",
            "bid_amount": "100",
            "targeting": '{"geo_locations":{"countries":["IN"]}}',
            "access_token": token,
        },
        timeout=20.0,
    )
    adset_resp.raise_for_status()
    adset_id = adset_resp.json()["id"]

    # 2. AdImage — upload the product photo, get back an image hash.
    img_resp = httpx.post(
        f"{base}/act_{account}/adimages",
        data={"bytes": base64.b64encode(image_bytes).decode("ascii"), "access_token": token},
        timeout=30.0,
    )
    img_resp.raise_for_status()
    images = img_resp.json().get("images", {})
    image_hash = next(iter(images.values()))["hash"]

    # 3. AdCreative — the actual ad content, tied to the Page + image.
    import json as _json

    creative_resp = httpx.post(
        f"{base}/act_{account}/adcreatives",
        data={
            "name": f"{name} — Creative",
            "object_story_spec": _json.dumps({
                "page_id": settings.meta_page_id,
                "link_data": {
                    "image_hash": image_hash,
                    "link": "https://kalasetu.example",  # placeholder CTA target
                    "message": name,
                },
            }),
            "access_token": token,
        },
        timeout=20.0,
    )
    creative_resp.raise_for_status()
    creative_id = creative_resp.json()["id"]

    # 4. Ad — PAUSED, links AdSet + AdCreative together.
    ad_resp = httpx.post(
        f"{base}/act_{account}/ads",
        data={
            "name": f"{name} — Ad",
            "adset_id": adset_id,
            "creative": _json.dumps({"creative_id": creative_id}),
            "status": "PAUSED",
            "access_token": token,
        },
        timeout=20.0,
    )
    ad_resp.raise_for_status()


def _stub_campaign(name: str, error: str | None = None) -> dict:
    import uuid

    fake_id = f"stub_{uuid.uuid4().hex[:12]}"
    log.info("Meta campaign stub used for %r (real API disabled/unavailable)", name)
    return {"id": fake_id, "url": None, "stub": True, "error": error}
