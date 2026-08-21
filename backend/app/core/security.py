from datetime import datetime, timedelta, timezone

from jose import JWTError, jwt

from app.core.config import settings

ALGORITHM = "HS256"


def _encode(sub: str, token_type: str, ttl: timedelta) -> str:
    payload = {
        "sub": sub,
        "type": token_type,
        "exp": datetime.now(timezone.utc) + ttl,
    }
    return jwt.encode(payload, settings.secret_key, algorithm=ALGORITHM)


def create_access_token(user_id: str) -> str:
    return _encode(user_id, "access", timedelta(minutes=settings.access_token_ttl_min))


def create_refresh_token(user_id: str) -> str:
    return _encode(user_id, "refresh", timedelta(days=settings.refresh_token_ttl_days))


def create_buyer_access_token(buyer_id: str) -> str:
    return _encode(buyer_id, "buyer", timedelta(minutes=settings.access_token_ttl_min))


def create_buyer_refresh_token(buyer_id: str) -> str:
    return _encode(buyer_id, "buyer_refresh", timedelta(days=settings.refresh_token_ttl_days))


def decode_token(token: str, expected_type: str = "access") -> str | None:
    """Return the subject (user id) if the token is valid and of the right type."""
    try:
        payload = jwt.decode(token, settings.secret_key, algorithms=[ALGORITHM])
    except JWTError:
        return None
    if payload.get("type") != expected_type:
        return None
    return payload.get("sub")
