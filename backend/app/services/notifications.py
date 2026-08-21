"""Notifications — push (FCM) + SMS, provider-abstracted.

Order events (new order, accepted, paid) notify the relevant party. The `log`
provider (default) just logs — great for dev/demo. Swap NOTIFY_PROVIDER=fcm /
sms + keys in prod. Best-effort: a notification failure never breaks the flow.
"""
import logging

from app.core.config import settings

log = logging.getLogger("kalasetu.notify")


def _provider() -> str:
    return getattr(settings, "notify_provider", "log")


def notify(recipient: str, title: str, body: str) -> None:
    try:
        p = _provider()
        if p == "fcm":
            _send_fcm(recipient, title, body)
        elif p == "sms":
            _send_sms(recipient, f"{title}: {body}")
        else:
            log.info("[notify:%s] -> %s | %s — %s", p, recipient, title, body)
    except Exception as e:  # noqa: BLE001
        log.warning("notify failed: %s", e)


# ---- semantic order events ----
def order_placed(artisan_id: str, order_id: str) -> None:
    notify(artisan_id, "New order", f"You have a new order {order_id[:6]}. Review it in the app.")


def order_accepted(buyer_id: str, order_id: str) -> None:
    notify(buyer_id, "Order accepted", f"Order {order_id[:6]} was accepted. Please pay to confirm.")


def order_paid(artisan_id: str, order_id: str) -> None:
    notify(artisan_id, "Payment received", f"Order {order_id[:6]} is paid. Prepare it for dispatch.")


# ---- providers (prod TODO) ----
def _send_fcm(token: str, title: str, body: str) -> None:
    # TODO(prod): firebase_admin.messaging.send(Message(notification=..., token=token))
    raise NotImplementedError("Wire FCM here")


def _send_sms(phone: str, text: str) -> None:
    # TODO(prod): reuse app.services.sms provider
    raise NotImplementedError("Wire SMS here")
