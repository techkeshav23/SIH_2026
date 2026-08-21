"""Guards for the pluggable govt/notification providers (off by default)."""
from app.services import bhashini, notifications, ondc


def test_providers_disabled_by_default():
    assert bhashini.enabled() is False
    assert ondc.enabled() is False


def test_ondc_publish_noop_when_disabled():
    # publish is best-effort and a no-op (returns None) when ONDC is off
    class _P:
        id = "x"
    assert ondc.publish_product(_P()) is None


def test_notify_never_raises():
    # log provider: must not raise
    notifications.order_placed("artisan-1", "order-123456")
    notifications.order_accepted("buyer-1", "order-123456")
    notifications.order_paid("artisan-1", "order-123456")
