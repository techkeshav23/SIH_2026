"""Reviews + in-app notifications.

Reviews are public to read (buyers browse) and buyer-authenticated to write.
Notifications are a per-recipient feed that works for both artisans (users) and
buyers — resolved from whichever token is presented.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.api.deps import get_current_buyer
from app.core.db import get_db
from app.core.security import decode_token
from app.models import Buyer, Notification, Product, Review, User
from app.models.schemas import ConsentIn, NotificationOut, ReviewCreate, ReviewOut
from app.services import notifications as notify_svc

router = APIRouter(tags=["community"])

_bearer = HTTPBearer(auto_error=False)


def _recipient(
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
) -> tuple[str, str]:
    """Resolve the caller as either an artisan (user) or a buyer, returning
    (recipient_id, role). Raises 401 if neither token is valid."""
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    uid = decode_token(creds.credentials, expected_type="access")
    if uid and db.get(User, uid):
        return uid, "artisan"
    bid = decode_token(creds.credentials, expected_type="buyer")
    if bid and db.get(Buyer, bid):
        return bid, "buyer"
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")


# ---------- reviews ----------
@router.get("/products/{product_id}/reviews", response_model=list[ReviewOut])
def list_reviews(product_id: str, db: Session = Depends(get_db)):
    stmt = select(Review).where(Review.product_id == product_id).order_by(Review.created_at.desc())
    return [
        ReviewOut(
            id=r.id, product_id=r.product_id, author=r.author_name or "Buyer",
            rating=r.rating, text=r.text, date=r.created_at,
        )
        for r in db.scalars(stmt)
    ]


@router.post("/products/{product_id}/reviews", response_model=ReviewOut,
             status_code=status.HTTP_201_CREATED)
def add_review(
    product_id: str,
    body: ReviewCreate,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    product = db.get(Product, product_id)
    if not product:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    if not 1 <= body.rating <= 5:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Rating must be 1-5")

    author = buyer.name or buyer.org_name or "Buyer"
    review = Review(
        product_id=product_id, buyer_id=buyer.id, author_name=author,
        rating=body.rating, text=(body.text or "").strip() or None,
    )
    db.add(review)
    db.commit()
    db.refresh(review)

    # Best-effort: alert the artisan (never breaks the review write).
    title = product.title_en or product.title_hi or "your product"
    notify_svc.review_added(product.user_id, title, review.rating)

    return ReviewOut(
        id=review.id, product_id=review.product_id, author=author,
        rating=review.rating, text=review.text, date=review.created_at,
    )


# ---------- notifications ----------
@router.get("/notifications", response_model=list[NotificationOut])
def list_notifications(
    who: tuple[str, str] = Depends(_recipient),
    db: Session = Depends(get_db),
):
    recipient_id, _role = who
    stmt = (
        select(Notification)
        .where(Notification.recipient_id == recipient_id)
        .order_by(Notification.created_at.desc())
        .limit(50)
    )
    return [
        NotificationOut(
            id=n.id, title=n.title, body=n.body, type=n.kind, read=n.read, time=n.created_at,
        )
        for n in db.scalars(stmt)
    ]


@router.post("/notifications/read", status_code=status.HTTP_204_NO_CONTENT)
def mark_read(
    who: tuple[str, str] = Depends(_recipient),
    db: Session = Depends(get_db),
):
    recipient_id, _role = who
    db.execute(
        update(Notification)
        .where(Notification.recipient_id == recipient_id, Notification.read.is_(False))
        .values(read=True)
    )
    db.commit()


# ---------- DPDP consent ----------
@router.post("/consent", status_code=status.HTTP_204_NO_CONTENT)
def record_consent(
    body: ConsentIn,
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
    db: Session = Depends(get_db),
):
    """Record the signed-in user's/buyer's DPDP consent (version + timestamp)."""
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    uid = decode_token(creds.credentials, expected_type="access")
    obj = db.get(User, uid) if uid else None
    if obj is None:
        bid = decode_token(creds.credentials, expected_type="buyer")
        obj = db.get(Buyer, bid) if bid else None
    if obj is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")
    obj.consent_at = datetime.now(timezone.utc)
    obj.consent_version = body.version
    db.commit()
