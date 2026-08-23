from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_buyer
from app.core import otp as otp_store
from app.core.config import settings
from app.core.db import get_db
from app.core.limiter import rate_limit
from app.core.security import (
    create_buyer_access_token,
    create_buyer_refresh_token,
    decode_token,
)
from app.models import Buyer
from app.models.schemas import (
    AccessToken,
    BuyerAuthToken,
    BuyerOut,
    BuyerUpdate,
    OtpRequest,
    OtpSent,
    OtpVerify,
    RefreshRequest,
)

router = APIRouter(prefix="/buyer", tags=["buyer"])


@router.post("/auth/request-otp", response_model=OtpSent)
def request_otp(
    body: OtpRequest,
    _: None = Depends(rate_limit("buyer_otp", max_calls=5, window_sec=60)),
):
    try:
        otp = otp_store.generate(body.phone)
    except otp_store.OtpError as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e))
    from app.services import sms

    sms.send_otp(body.phone, otp)
    dev_otp = otp if settings.allow_dev_otp else None
    return OtpSent(sent=True, dev_otp=dev_otp)


@router.post("/auth/verify-otp", response_model=BuyerAuthToken)
def verify_otp(body: OtpVerify, db: Session = Depends(get_db)):
    try:
        ok = otp_store.verify(body.phone, body.otp)
    except otp_store.OtpError as e:
        raise HTTPException(status.HTTP_429_TOO_MANY_REQUESTS, str(e))
    if not ok:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired OTP")

    buyer = db.scalar(select(Buyer).where(Buyer.phone == body.phone))
    if not buyer:
        buyer = Buyer(phone=body.phone)
        db.add(buyer)
        db.commit()
        db.refresh(buyer)

    return BuyerAuthToken(
        access_token=create_buyer_access_token(buyer.id),
        refresh_token=create_buyer_refresh_token(buyer.id),
        buyer=BuyerOut.model_validate(buyer),
    )


@router.post("/auth/refresh", response_model=AccessToken)
def refresh(body: RefreshRequest, db: Session = Depends(get_db)):
    buyer_id = decode_token(body.refresh_token, expected_type="buyer_refresh")
    if not buyer_id or not db.get(Buyer, buyer_id):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid refresh token")
    return AccessToken(access_token=create_buyer_access_token(buyer_id))


@router.get("/me", response_model=BuyerOut)
def me(buyer: Buyer = Depends(get_current_buyer)):
    return buyer


@router.patch("/me", response_model=BuyerOut)
def update_me(
    body: BuyerUpdate,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(buyer, field, value)
    db.commit()
    db.refresh(buyer)
    return buyer
