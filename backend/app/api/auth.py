from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core import otp as otp_store
from app.core.config import settings
from app.core.db import get_db
from app.core.limiter import rate_limit
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.models import User
from app.models.schemas import (
    AccessToken,
    AuthToken,
    OtpRequest,
    OtpSent,
    OtpVerify,
    RefreshRequest,
    UserOut,
    UserUpdate,
)
from app.services import sms

router = APIRouter(tags=["auth"])


@router.post("/auth/request-otp", response_model=OtpSent)
def request_otp(
    body: OtpRequest,
    _: None = Depends(rate_limit("otp", max_calls=5, window_sec=60)),
):
    try:
        otp = otp_store.generate(body.phone)
    except otp_store.OtpError as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e))
    sms.send_otp(body.phone, otp)
    # Only leak the OTP in dev/console mode for convenience — never in prod.
    dev_otp = otp if settings.is_dev and settings.sms_provider == "console" else None
    return OtpSent(sent=True, dev_otp=dev_otp)


@router.post("/auth/verify-otp", response_model=AuthToken)
def verify_otp(
    body: OtpVerify,
    db: Session = Depends(get_db),
    _: None = Depends(rate_limit("otp_verify", max_calls=10, window_sec=60)),
):
    try:
        ok = otp_store.verify(body.phone, body.otp)
    except otp_store.OtpError as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e))
    if not ok:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired OTP")

    user = db.scalar(select(User).where(User.phone == body.phone))
    if not user:
        user = User(phone=body.phone)
        db.add(user)
        db.commit()
        db.refresh(user)

    return AuthToken(
        access_token=create_access_token(user.id),
        refresh_token=create_refresh_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/auth/refresh", response_model=AccessToken)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)):
    user_id = decode_token(body.refresh_token, expected_type="refresh")
    if not user_id or not db.get(User, user_id):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")
    return AccessToken(access_token=create_access_token(user_id))


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    return user


@router.patch("/me", response_model=UserOut)
def update_me(
    body: UserUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(user, field, value)
    db.commit()
    db.refresh(user)
    return user
