"""Payment provider abstraction.

`mock` (default) simulates a gateway so the whole order→pay→confirm flow works
end-to-end with zero keys — ideal for dev/demo. Swap PAYMENT_PROVIDER=razorpay
+ keys in prod; the interface (create/verify) stays identical.
"""
import uuid

from app.core.config import settings


def provider_name() -> str:
    return getattr(settings, "payment_provider", "mock")


def create_payment(order_id: str, amount: float, currency: str = "INR") -> dict:
    """Create a provider-side payment order. Returns checkout details for the client."""
    if provider_name() == "razorpay":
        return _create_razorpay(order_id, amount, currency)
    return {
        "provider": "mock",
        "provider_order_id": f"mock_{uuid.uuid4().hex[:16]}",
        "key_id": None,
    }


def verify_payment(provider_payment_id: str | None, signature: str | None) -> bool:
    """Verify a completed payment. Mock provider always succeeds in dev."""
    if provider_name() == "razorpay":
        return _verify_razorpay(provider_payment_id, signature)
    return True


# ---- Razorpay (prod) ----
def _create_razorpay(order_id: str, amount: float, currency: str) -> dict:
    # TODO(prod): razorpay.Client(auth=(key_id, key_secret)).order.create(
    #     {"amount": int(amount * 100), "currency": currency, "receipt": order_id})
    raise NotImplementedError("Wire Razorpay order.create here")


def _verify_razorpay(provider_payment_id: str | None, signature: str | None) -> bool:
    # TODO(prod): razorpay.utility.verify_payment_signature({...}) — HMAC check
    raise NotImplementedError("Wire Razorpay signature verification here")
