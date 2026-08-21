from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.config import settings
from app.core.db import get_db
from app.core.security import create_access_token
from app.models import User
from app.models.schemas import (
    AuthToken,
    OtpRequest,
    OtpSent,
    OtpVerify,
    UserOut,
    UserUpdate,
)

router = APIRouter(tags=["auth"])

# dev-only in-memory OTP store; prod -> SMS gateway + Redis
_OTP_STORE: dict[str, str] = {}
_DEV_OTP = "123456"


@router.post("/auth/request-otp", response_model=OtpSent)
def request_otp(body: OtpRequest):
    otp = _DEV_OTP  # prod: random 6-digit + send SMS
    _OTP_STORE[body.phone] = otp
    return OtpSent(sent=True, dev_otp=otp if settings.is_dev else None)


@router.post("/auth/verify-otp", response_model=AuthToken)
def verify_otp(body: OtpVerify, db: Session = Depends(get_db)):
    expected = _OTP_STORE.get(body.phone)
    if not expected or body.otp != expected:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid OTP")
    _OTP_STORE.pop(body.phone, None)

    user = db.scalar(select(User).where(User.phone == body.phone))
    if not user:
        user = User(phone=body.phone)
        db.add(user)
        db.commit()
        db.refresh(user)

    token = create_access_token(user.id)
    return AuthToken(access_token=token, user=UserOut.model_validate(user))


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
