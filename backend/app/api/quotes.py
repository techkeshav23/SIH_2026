"""B2B bulk-order price negotiation (RFQ).

A buyer requests a quote for a quantity at a target unit price. The artisan and
buyer then take turns (counter/accept/decline) until one accepts — which spawns
an Order at the agreed price — or declines.
"""
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_buyer
from app.core.db import get_db
from app.core.security import decode_token
from app.models import Buyer, Order, Product, Quote, User
from app.models.schemas import QuoteCreate, QuoteOut, QuotePrice
from app.services import notifications as notify_svc

router = APIRouter(prefix="/quotes", tags=["quotes"])

_bearer = HTTPBearer(auto_error=False)


def _actor(creds: HTTPAuthorizationCredentials | None, db: Session) -> tuple[str, str]:
    """Resolve caller as ('artisan', user_id) or ('buyer', buyer_id)."""
    if creds is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing token")
    uid = decode_token(creds.credentials, expected_type="access")
    if uid and db.get(User, uid):
        return "artisan", uid
    bid = decode_token(creds.credentials, expected_type="buyer")
    if bid and db.get(Buyer, bid):
        return "buyer", bid
    raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token")


def _out(db: Session, q: Quote) -> QuoteOut:
    p = db.get(Product, q.product_id)
    title = image = None
    if p:
        title = p.title_en or p.title_hi
        image = p.enhanced_image_url or p.raw_image_url
    return QuoteOut(
        id=q.id, product_id=q.product_id, product_title=title, product_image=image,
        quantity=q.quantity, buyer_price=q.buyer_price, artisan_price=q.artisan_price,
        agreed_price=q.agreed_price, list_price=q.list_price, status=q.status,
        turn=q.turn, message=q.message, order_id=q.order_id, created_at=q.created_at,
    )


def _get(db: Session, quote_id: str) -> Quote:
    q = db.get(Quote, quote_id)
    if not q:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Quote not found")
    return q


def _guard_turn(q: Quote, role: str, actor_id: str):
    """Only the party whose turn it is (and who owns the quote) may act."""
    owns = (role == "buyer" and q.buyer_id == actor_id) or (role == "artisan" and q.artisan_id == actor_id)
    if not owns:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your quote")
    if q.status != "open":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Quote is '{q.status}', not open")
    if q.turn != role:
        raise HTTPException(status.HTTP_409_CONFLICT, "Waiting on the other party")


# ---------- buyer: create + list ----------
@router.post("", response_model=QuoteOut, status_code=status.HTTP_201_CREATED)
def create_quote(
    body: QuoteCreate,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    product = db.get(Product, body.product_id)
    if not product or product.status != "listed":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not available")
    if body.quantity < 1 or body.target_price <= 0:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Quantity and price must be positive")

    q = Quote(
        product_id=product.id, buyer_id=buyer.id, artisan_id=product.user_id,
        quantity=body.quantity, buyer_price=body.target_price,
        list_price=product.final_price or product.suggested_price_max or product.suggested_price_min,
        message=body.message, status="open", turn="artisan",
    )
    db.add(q)
    db.commit()
    db.refresh(q)
    notify_svc.quote_new(product.user_id, q.quantity)
    return _out(db, q)


@router.get("", response_model=list[QuoteOut])
def my_quotes(buyer: Buyer = Depends(get_current_buyer), db: Session = Depends(get_db)):
    stmt = select(Quote).where(Quote.buyer_id == buyer.id).order_by(Quote.updated_at.desc())
    return [_out(db, q) for q in db.scalars(stmt)]


@router.get("/incoming", response_model=list[QuoteOut])
def incoming_quotes(
    db: Session = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
):
    role, aid = _actor(creds, db)
    if role != "artisan":
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Artisan only")
    stmt = select(Quote).where(Quote.artisan_id == aid).order_by(Quote.updated_at.desc())
    return [_out(db, q) for q in db.scalars(stmt)]


# ---------- negotiation: either party, on their turn ----------
@router.post("/{quote_id}/counter", response_model=QuoteOut)
def counter_quote(
    quote_id: str,
    body: QuotePrice,
    db: Session = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
):
    role, aid = _actor(creds, db)
    q = _get(db, quote_id)
    _guard_turn(q, role, aid)
    if body.price <= 0:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Price must be positive")

    if role == "artisan":
        q.artisan_price = body.price
        q.turn = "buyer"
        notify_svc.quote_countered("buyer", q.buyer_id, q.id)
    else:
        q.buyer_price = body.price
        q.turn = "artisan"
        notify_svc.quote_countered("artisan", q.artisan_id, q.id)
    db.commit()
    db.refresh(q)
    return _out(db, q)


@router.post("/{quote_id}/accept", response_model=QuoteOut)
def accept_quote(
    quote_id: str,
    db: Session = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
):
    role, aid = _actor(creds, db)
    q = _get(db, quote_id)
    _guard_turn(q, role, aid)

    # accept the OTHER party's current offer
    if role == "artisan":
        q.agreed_price = q.buyer_price
    else:
        if q.artisan_price is None:
            raise HTTPException(status.HTTP_409_CONFLICT, "No counter to accept yet")
        q.agreed_price = q.artisan_price

    # product must still be available to convert into an order
    product = db.get(Product, q.product_id)
    if not product or product.status != "listed":
        raise HTTPException(status.HTTP_409_CONFLICT, "Product no longer available")

    # negotiated deal -> straight to an 'accepted' order (both sides agreed)
    order = Order(
        product_id=q.product_id, buyer_id=q.buyer_id, artisan_id=q.artisan_id,
        quantity=q.quantity, unit_price=q.agreed_price,
        total_price=round(q.agreed_price * q.quantity, 2),
        status="accepted", note=f"Bulk deal ({q.quantity} units) negotiated via quote",
    )
    db.add(order)
    db.flush()
    q.status = "accepted"
    q.order_id = order.id
    db.commit()
    db.refresh(q)

    # tell the other party it's a deal
    if role == "artisan":
        notify_svc.quote_accepted("buyer", q.buyer_id, q.id)
    else:
        notify_svc.quote_accepted("artisan", q.artisan_id, q.id)
    return _out(db, q)


@router.post("/{quote_id}/decline", response_model=QuoteOut)
def decline_quote(
    quote_id: str,
    db: Session = Depends(get_db),
    creds: HTTPAuthorizationCredentials | None = Depends(_bearer),
):
    role, aid = _actor(creds, db)
    q = _get(db, quote_id)
    _guard_turn(q, role, aid)
    q.status = "declined"
    db.commit()
    db.refresh(q)
    other_role = "buyer" if role == "artisan" else "artisan"
    other_id = q.buyer_id if role == "artisan" else q.artisan_id
    notify_svc.quote_declined(other_role, other_id, q.id)
    return _out(db, q)
