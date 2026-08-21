"""ONDC / GeM market-linkage adapter.

Publishes a listed product to the Open Network for Digital Commerce (seller-app
role) so it's discoverable by any ONDC buyer app — the core "year-round market
access" promise. GeM (Government e-Marketplace) listing is analogous.

Real protocol (search/on_search, signed requests) is stubbed with a TODO;
enabled via USE_ONDC + credentials. Off by default (products stay local).
Publish is best-effort — a failure never blocks listing a product.
"""
import logging

from app.core.config import settings

log = logging.getLogger("kalasetu.ondc")


def enabled() -> bool:
    return settings.use_ondc and bool(settings.ondc_subscriber_id)


def publish_product(product) -> dict | None:
    """Publish a product to ONDC. Best-effort; returns provider ack or None."""
    if not enabled():
        return None
    try:
        return _publish(product)
    except Exception as e:  # noqa: BLE001
        log.warning("ONDC publish failed for %s: %s", product.id, e)
        return None


def _publish(product) -> dict:
    # TODO(prod): build an ONDC catalog item from the product and POST a signed
    # request to the network registry / gateway (settings.ondc_base_url) using
    # settings.ondc_subscriber_id + ondc_signing_key (Ed25519). Handle on_search.
    raise NotImplementedError("Wire ONDC seller-app catalog publish here")
