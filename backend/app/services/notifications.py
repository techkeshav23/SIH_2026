"""Notifications — persisted in-app feed + optional push (FCM) / SMS.

Every event is written to the `notifications` table (so the in-app bell shows a
real feed), then optionally pushed via NOTIFY_PROVIDER (log|fcm|sms). Persisting
and sending are both best-effort: a failure here never breaks the caller's flow.
"""
import logging

from app.core.config import settings
from app.core.db import SessionLocal
from app.models import Notification

log = logging.getLogger("kalasetu.notify")


def _provider() -> str:
    return getattr(settings, "notify_provider", "log")


def _persist(recipient: str, role: str, kind: str, title: str, body: str) -> None:
    """Insert a Notification row in its own short-lived session."""
    db = SessionLocal()
    try:
        db.add(Notification(
            recipient_id=recipient, recipient_role=role, kind=kind, title=title, body=body,
        ))
        db.commit()
    except Exception as e:  # noqa: BLE001
        log.warning("notification persist failed: %s", e)
        db.rollback()
    finally:
        db.close()


def notify(recipient: str, title: str, body: str, *, kind: str = "info", role: str = "artisan") -> None:
    _persist(recipient, role, kind, title, body)
    try:
        p = _provider()
        if p == "fcm":
            _send_fcm(recipient, title, body)
        elif p == "sms":
            _send_sms(recipient, f"{title}: {body}")
        else:
            log.info("[notify:%s] -> %s | %s — %s", p, recipient, title, body)
    except Exception as e:  # noqa: BLE001
        log.warning("notify send failed: %s", e)


# ---- semantic order events ----
def order_placed(artisan_id: str, order_id: str) -> None:
    notify(artisan_id, "New order", f"You have a new order {order_id[:6]}. Review it in the app.",
           kind="order", role="artisan")


def order_accepted(buyer_id: str, order_id: str) -> None:
    notify(buyer_id, "Order accepted", f"Order {order_id[:6]} was accepted. Please pay to confirm.",
           kind="order", role="buyer")


def order_paid(artisan_id: str, order_id: str) -> None:
    notify(artisan_id, "Payment received", f"Order {order_id[:6]} is paid. Prepare it for dispatch.",
           kind="order", role="artisan")


def order_shipped(buyer_id: str, order_id: str) -> None:
    notify(buyer_id, "Order shipped", f"Order {order_id[:6]} is on the way. Confirm when it arrives.",
           kind="order", role="buyer")


def order_completed(artisan_id: str, order_id: str) -> None:
    notify(artisan_id, "Order delivered", f"Order {order_id[:6]} was received by the buyer. Well done!",
           kind="order", role="artisan")


def order_cancelled(recipient_id: str, order_id: str, role: str = "artisan") -> None:
    notify(recipient_id, "Order cancelled", f"Order {order_id[:6]} was cancelled.",
           kind="order", role=role)


def review_added(artisan_id: str, product_title: str, rating: int) -> None:
    notify(artisan_id, "New review", f"{product_title} received a {rating}★ review.",
           kind="review", role="artisan")


# ---- quote / negotiation events ----
def quote_new(artisan_id: str, quantity: int) -> None:
    notify(artisan_id, "New bulk quote request", f"A buyer wants a quote for {quantity} units.",
           kind="quote", role="artisan")


def quote_countered(role: str, recipient_id: str, quote_id: str) -> None:
    notify(recipient_id, "Counter offer", f"New price offered on quote {quote_id[:6]}. Review it.",
           kind="quote", role=role)


def quote_accepted(role: str, recipient_id: str, quote_id: str) -> None:
    notify(recipient_id, "Quote accepted", f"Quote {quote_id[:6]} was accepted — an order was created.",
           kind="quote", role=role)


def quote_declined(role: str, recipient_id: str, quote_id: str) -> None:
    notify(recipient_id, "Quote declined", f"Quote {quote_id[:6]} was declined.",
           kind="quote", role=role)


# ---- providers (prod TODO) ----
def _send_fcm(token: str, title: str, body: str) -> None:
    # TODO(prod): firebase_admin.messaging.send(Message(notification=..., token=token))
    raise NotImplementedError("Wire FCM here")


def _send_sms(phone: str, text: str) -> None:
    # TODO(prod): reuse app.services.sms provider
    raise NotImplementedError("Wire SMS here")
