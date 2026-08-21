from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core import quota
from app.core.db import get_db
from app.core.security import decode_token
from app.models import Buyer, User

bearer = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    user_id = decode_token(creds.credentials)
    if not user_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "User not found")
    return user


def enforce_ai_quota(user: User = Depends(get_current_user)) -> User:
    """Authenticated user who is still within their daily AI-call budget."""
    if not quota.hit(user.id):
        raise HTTPException(
            status.HTTP_429_TOO_MANY_REQUESTS,
            "Daily AI limit reached — try again tomorrow",
        )
    return user


def get_current_buyer(
    creds: HTTPAuthorizationCredentials | None = Depends(bearer),
    db: Session = Depends(get_db),
) -> Buyer:
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    buyer_id = decode_token(creds.credentials, expected_type="buyer")
    if not buyer_id:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired buyer token")
    buyer = db.get(Buyer, buyer_id)
    if not buyer:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Buyer not found")
    return buyer
