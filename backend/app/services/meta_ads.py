"""Meta Marketing API adapter — creates real ad objects in the artisan's own
Meta (Facebook/Instagram) ad account.

Demo-safety: everything is created with status=PAUSED. Meta documents this as
the standard way to exercise the API — a PAUSED campaign is visible in Ads
Manager (so a judge can see it was really created) but never enters the auction
and never spends money.

Structure (one shape for every caller, so budget edits always target the same
object):

    Campaign (PAUSED, no budget)
      └─ AdSet (PAUSED, holds daily_budget + schedule + targeting)
           └─ Ad (PAUSED) ── AdCreative (product image + caption)

The budget lives on the **ad set**, not the campaign. That's what Meta needs for
a deliverable ad, and it keeps `update_budget` unambiguous. The Ad/AdCreative
layer additionally requires a linked Facebook Page (settings.meta_page_id) and
a Meta app in Live mode; when either is missing the campaign + ad set are still
created for real and we just skip the creative.

Off by default (USE_META_ADS=false, or missing credentials) -> the public
functions return functional stubs so the UI/demo never breaks.
"""
import base64
import json
import logging
import uuid
from datetime import datetime, timedelta, timezone

import httpx

from app.core.config import settings

log = logging.getLogger("kalasetu.meta_ads")

_GRAPH_BASE = "https://graph.facebook.com"

# Meta rejects an ad-set daily budget under the account minimum (~₹96.15/day on
# INR accounts). Single source of truth — the API layer validates against this
# too, so the artisan never gets a confusing platform-side rejection.
MIN_DAILY_BUDGET_INR = 97.0

# Meta only accepts certain objective <-> optimization_goal pairings; sending a
# mismatched pair fails ad-set creation. Map each objective we expose to a goal
# it actually supports (REACH is only valid for awareness-style objectives).
_OPTIMIZATION_GOAL = {
    "OUTCOME_TRAFFIC": "LINK_CLICKS",
    "OUTCOME_ENGAGEMENT": "POST_ENGAGEMENT",
    "OUTCOME_AWARENESS": "REACH",
    # Sales optimisation needs a pixel/conversion event we don't have, so drive
    # clicks instead of failing outright.
    "OUTCOME_SALES": "LINK_CLICKS",
}


def enabled() -> bool:
    return bool(
        settings.use_meta_ads
        and settings.meta_access_token
        and settings.meta_ad_account_id
    )


def is_stub_id(value: str | None) -> bool:
    return bool(value) and str(value).startswith("stub_")


def _account() -> str:
    return settings.meta_ad_account_id.removeprefix("act_")


def _base() -> str:
    return f"{_GRAPH_BASE}/{settings.meta_api_version}"


def _manager_url(campaign_id: str) -> str:
    return (
        "https://adsmanager.facebook.com/adsmanager/manage/campaigns"
        f"?act={_account()}&selected_campaign_ids={campaign_id}"
    )


def _to_paise(inr: float) -> str:
    # Meta budgets are in the account currency's minor unit (paise for INR).
    return str(int(round(inr * 100)))


def _post(path: str, data: dict, timeout: float = 20.0) -> dict:
    data = {**data, "access_token": settings.meta_access_token}
    resp = httpx.post(f"{_base()}{path}", data=data, timeout=timeout)
    resp.raise_for_status()
    return resp.json()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
def create_paused_campaign(
    name: str,
    *,
    daily_budget_inr: float,
    objective: str = "OUTCOME_TRAFFIC",
    days: int | None = None,
    caption: str | None = None,
    image_bytes: bytes | None = None,
    link: str = "https://kalasetu.example",
) -> dict:
    """Create Campaign -> AdSet (-> AdCreative -> Ad when possible), all PAUSED.

    Never raises. Returns:
        {campaign_id, adset_id, ad_id, url, stub, error, creative_error}
    `stub` is True when Meta is disabled/misconfigured or the call failed, in
    which case the ids are fake but the shape is identical, so callers (and the
    UI) need no special-casing.
    """
    if not enabled():
        return _stub_result()
    try:
        return _create_real(
            name,
            daily_budget_inr=daily_budget_inr,
            objective=objective,
            days=days,
            caption=caption,
            image_bytes=image_bytes,
            link=link,
        )
    except Exception as e:  # noqa: BLE001
        log.warning("Meta campaign create failed for %r: %s", name, e)
        return _stub_result(error=_err(e))


def update_budget(adset_id: str | None, daily_budget_inr: float) -> dict:
    """Set the daily budget on an **ad set** (that's where the budget lives —
    see the module docstring). Never raises; returns {"ok": bool, "error"?}."""
    if not enabled():
        return {"ok": False, "error": "Meta Ads is not enabled"}
    if not adset_id or is_stub_id(adset_id):
        return {"ok": False, "error": "demo campaign — nothing to update on Meta"}
    if daily_budget_inr < MIN_DAILY_BUDGET_INR:
        return {"ok": False, "error": f"below Meta minimum of ₹{MIN_DAILY_BUDGET_INR:.0f}/day"}
    try:
        _post(f"/{adset_id}", {"daily_budget": _to_paise(daily_budget_inr)})
        return {"ok": True}
    except Exception as e:  # noqa: BLE001
        log.warning("Meta budget update failed for adset %s: %s", adset_id, e)
        return {"ok": False, "error": _err(e)}


def estimated_reach(daily_budget_inr: float, days: int) -> list[int]:
    """Rough reach band for the given spend. Deliberately a heuristic, not a
    Meta delivery estimate — labelled as an estimate in the UI."""
    total = daily_budget_inr * max(days, 1)
    return [round(total * 1.4), round(total * 3.2)]


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
def _err(e: Exception) -> str:
    """Prefer Meta's human-readable message over httpx's generic status text."""
    resp = getattr(e, "response", None)
    if resp is not None:
        try:
            err = resp.json().get("error", {})
            msg = err.get("error_user_msg") or err.get("message")
            if msg:
                return str(msg)[:300]
        except Exception:  # noqa: BLE001
            pass
    return str(e)[:300]


def _create_real(
    name: str,
    *,
    daily_budget_inr: float,
    objective: str,
    days: int | None,
    caption: str | None,
    image_bytes: bytes | None,
    link: str,
) -> dict:
    account = _account()
    daily_budget_inr = max(daily_budget_inr, MIN_DAILY_BUDGET_INR)

    # 1. Campaign — no budget here; the ad set carries it. Meta requires
    #    is_adset_budget_sharing_enabled to be explicit when it isn't a
    #    campaign-budget (CBO) campaign.
    campaign_id = _post(
        f"/act_{account}/campaigns",
        {
            "name": name,
            "objective": objective,
            "status": "PAUSED",
            "special_ad_categories": "[]",
            "is_adset_budget_sharing_enabled": "false",
        },
    )["id"]

    # 2. AdSet — budget, optional schedule, targeting.
    adset_fields = {
        "name": f"{name} — Ad set",
        "campaign_id": campaign_id,
        "daily_budget": _to_paise(daily_budget_inr),
        "billing_event": "IMPRESSIONS",
        "optimization_goal": _OPTIMIZATION_GOAL.get(objective, "LINK_CLICKS"),
        "bid_strategy": "LOWEST_COST_WITHOUT_CAP",
        "targeting": json.dumps(
            {"geo_locations": {"countries": ["IN"]}, "age_min": 18, "age_max": 65}
        ),
        "status": "PAUSED",
    }
    if days:
        start = datetime.now(timezone.utc) + timedelta(minutes=10)
        end = start + timedelta(days=days)
        adset_fields["start_time"] = start.strftime("%Y-%m-%dT%H:%M:%S%z")
        adset_fields["end_time"] = end.strftime("%Y-%m-%dT%H:%M:%S%z")

    adset_id = _post(f"/act_{account}/adsets", adset_fields)["id"]

    result = {
        "campaign_id": campaign_id,
        "adset_id": adset_id,
        "ad_id": None,
        "url": _manager_url(campaign_id),
        "stub": False,
        "error": None,
        "creative_error": None,
    }

    # 3. Creative + Ad — needs an image AND a linked Page. A failure here is
    #    non-fatal: the campaign + ad set are already real and PAUSED.
    if image_bytes and settings.meta_page_id:
        try:
            result["ad_id"] = _create_creative_and_ad(
                account, adset_id, name, caption or name, image_bytes, link
            )
        except Exception as e:  # noqa: BLE001
            log.warning("Meta creative/ad failed for campaign %s: %s", campaign_id, e)
            result["creative_error"] = _err(e)
    elif image_bytes and not settings.meta_page_id:
        result["creative_error"] = "no Facebook Page linked (set META_PAGE_ID) — ad image skipped"

    return result


def _create_creative_and_ad(
    account: str, adset_id: str, name: str, caption: str, image_bytes: bytes, link: str
) -> str:
    """Upload the product image, build an AdCreative from it, and attach a
    PAUSED Ad to `adset_id`. Returns the ad id."""
    images = _post(
        f"/act_{account}/adimages",
        {"bytes": base64.b64encode(image_bytes).decode("ascii")},
        timeout=30.0,
    ).get("images", {})
    image_hash = next(iter(images.values()))["hash"]

    creative_id = _post(
        f"/act_{account}/adcreatives",
        {
            "name": f"{name} — Creative",
            "object_story_spec": json.dumps({
                "page_id": settings.meta_page_id,
                "link_data": {"image_hash": image_hash, "link": link, "message": caption},
            }),
        },
    )["id"]

    return _post(
        f"/act_{account}/ads",
        {
            "name": f"{name} — Ad",
            "adset_id": adset_id,
            "creative": json.dumps({"creative_id": creative_id}),
            "status": "PAUSED",
        },
    )["id"]


def _stub_result(error: str | None = None) -> dict:
    log.info("Meta stub used (real API disabled/unavailable)%s", f": {error}" if error else "")
    return {
        "campaign_id": f"stub_{uuid.uuid4().hex[:12]}",
        "adset_id": f"stub_{uuid.uuid4().hex[:12]}",
        "ad_id": None,
        "url": None,
        "stub": True,
        "error": error,
        "creative_error": None,
    }
