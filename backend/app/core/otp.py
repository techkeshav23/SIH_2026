"""OTP lifecycle store.

In-memory implementation with TTL, attempt limits, and resend cooldown —
production-shaped behaviour without external deps. Swap the backing dict for
Redis in prod (same public functions) so the API layer never changes.
"""
import secrets
import time
from dataclasses import dataclass

from app.core.config import settings


@dataclass
class _Entry:
    otp: str
    expires_at: float
    attempts: int
    last_sent_at: float


_STORE: dict[str, _Entry] = {}


class OtpError(Exception):
    """Raised for cooldown / lockout conditions (maps to HTTP 429/401)."""


def _now() -> float:
    return time.time()


def generate(phone: str) -> str:
    """Create (or refresh) an OTP for a phone, enforcing resend cooldown."""
    existing = _STORE.get(phone)
    if existing and (_now() - existing.last_sent_at) < settings.otp_resend_cooldown_sec:
        wait = int(settings.otp_resend_cooldown_sec - (_now() - existing.last_sent_at))
        raise OtpError(f"Please wait {wait}s before requesting another OTP")

    otp = "".join(secrets.choice("0123456789") for _ in range(settings.otp_length))
    _STORE[phone] = _Entry(
        otp=otp,
        expires_at=_now() + settings.otp_ttl_sec,
        attempts=0,
        last_sent_at=_now(),
    )
    return otp


def verify(phone: str, otp: str) -> bool:
    """Check an OTP; consumes it on success, counts attempts on failure."""
    entry = _STORE.get(phone)
    if not entry:
        return False
    if _now() > entry.expires_at:
        _STORE.pop(phone, None)
        return False
    entry.attempts += 1
    if entry.attempts > settings.otp_max_attempts:
        _STORE.pop(phone, None)
        raise OtpError("Too many attempts — request a new OTP")
    if secrets.compare_digest(entry.otp, otp):
        _STORE.pop(phone, None)
        return True
    return False


def clear() -> None:
    """Test helper."""
    _STORE.clear()
