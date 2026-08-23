from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_buyer, get_current_user
from app.core.db import get_db
from app.models import Address, Buyer, Order, Payment, Product, User
from app.models.schemas import (
    AddressCreate,
    AddressOut,
    OrderCreate,
    OrderOut,
    PaymentCheckout,
    PaymentConfirm,
)
from app.services import notifications, payments

router = APIRouter(prefix="/orders", tags=["orders"])


def _get_order(db: Session, order_id: str) -> Order:
    o = db.get(Order, order_id)
    if not o:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Order not found")
    return o


# ---------- buyer: place & track ----------
@router.post("", response_model=OrderOut, status_code=status.HTTP_201_CREATED)
def create_order(
    body: OrderCreate,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    product = db.get(Product, body.product_id)
    if not product or product.status != "listed":
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not available")
    if body.quantity < 1:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Quantity must be >= 1")

    unit = product.final_price or product.suggested_price_max or 0
    if unit <= 0:
        raise HTTPException(status.HTTP_409_CONFLICT, "Product has no price set")

    # Snapshot the chosen delivery address onto the order (denormalized).
    ship_name = ship_phone = ship_address = None
    if body.address_id:
        addr = db.get(Address, body.address_id)
        if not addr or addr.buyer_id != buyer.id:
            raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
        ship_name, ship_phone = addr.name, addr.phone
        parts = [addr.line1, addr.line2, f"{addr.city}, {addr.state} - {addr.pincode}"]
        ship_address = "\n".join(p for p in parts if p)

    order = Order(
        product_id=product.id,
        buyer_id=buyer.id,
        artisan_id=product.user_id,
        quantity=body.quantity,
        unit_price=unit,
        total_price=round(unit * body.quantity, 2),
        note=body.note,
        status="pending",
        ship_name=ship_name,
        ship_phone=ship_phone,
        ship_address=ship_address,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    notifications.order_placed(order.artisan_id, order.id)
    return order


@router.get("", response_model=list[OrderOut])
def my_orders(
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    stmt = select(Order).where(Order.buyer_id == buyer.id).order_by(Order.created_at.desc())
    return list(db.scalars(stmt))


# ---------- artisan: incoming & decide ----------
@router.get("/incoming", response_model=list[OrderOut])
def incoming_orders(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Order).where(Order.artisan_id == user.id).order_by(Order.created_at.desc())
    return list(db.scalars(stmt))


@router.post("/{order_id}/accept", response_model=OrderOut)
def accept_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    o = _get_order(db, order_id)
    if o.artisan_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot accept an order in '{o.status}'")
    o.status = "accepted"
    db.commit()
    db.refresh(o)
    notifications.order_accepted(o.buyer_id, o.id)
    return o


@router.post("/{order_id}/reject", response_model=OrderOut)
def reject_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    o = _get_order(db, order_id)
    if o.artisan_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status != "pending":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot reject an order in '{o.status}'")
    o.status = "rejected"
    db.commit()
    db.refresh(o)
    return o


# ---------- buyer: pay accepted order ----------
@router.post("/{order_id}/pay", response_model=PaymentCheckout)
def pay_order(
    order_id: str,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    o = _get_order(db, order_id)
    if o.buyer_id != buyer.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status != "accepted":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Order must be 'accepted' to pay (is '{o.status}')")

    checkout = payments.create_payment(o.id, o.total_price)
    payment = Payment(
        order_id=o.id,
        provider=checkout["provider"],
        provider_order_id=checkout["provider_order_id"],
        amount=o.total_price,
    )
    db.add(payment)
    db.commit()
    db.refresh(payment)
    return PaymentCheckout(
        order_id=o.id,
        payment_id=payment.id,
        provider=payment.provider,
        provider_order_id=payment.provider_order_id,
        amount=o.total_price,
        key_id=checkout.get("key_id"),
    )


@router.post("/{order_id}/confirm-payment", response_model=OrderOut)
def confirm_payment(
    order_id: str,
    body: PaymentConfirm,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    o = _get_order(db, order_id)
    if o.buyer_id != buyer.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    payment = db.scalar(select(Payment).where(Payment.order_id == o.id).order_by(Payment.created_at.desc()))
    if not payment:
        raise HTTPException(status.HTTP_409_CONFLICT, "No payment initiated for this order")

    if not payments.verify_payment(body.provider_payment_id, body.signature):
        payment.status = "failed"
        db.commit()
        raise HTTPException(status.HTTP_402_PAYMENT_REQUIRED, "Payment verification failed")

    payment.status = "paid"
    payment.provider_payment_id = body.provider_payment_id
    o.status = "paid"
    db.commit()
    db.refresh(o)
    notifications.order_paid(o.artisan_id, o.id)
    return o


# ---------- fulfilment: ship -> deliver -> complete, or cancel ----------
@router.post("/{order_id}/ship", response_model=OrderOut)
def ship_order(
    order_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Artisan dispatches a paid order."""
    o = _get_order(db, order_id)
    if o.artisan_id != user.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status != "paid":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Only a 'paid' order can be shipped (is '{o.status}')")
    o.status = "shipped"
    db.commit()
    db.refresh(o)
    notifications.order_shipped(o.buyer_id, o.id)
    return o


@router.post("/{order_id}/confirm-delivery", response_model=OrderOut)
def confirm_delivery(
    order_id: str,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    """Buyer confirms receipt -> order is completed."""
    o = _get_order(db, order_id)
    if o.buyer_id != buyer.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status != "shipped":
        raise HTTPException(status.HTTP_409_CONFLICT, f"Only a 'shipped' order can be received (is '{o.status}')")
    o.status = "completed"
    db.commit()
    db.refresh(o)
    notifications.order_completed(o.artisan_id, o.id)
    return o


@router.post("/{order_id}/cancel", response_model=OrderOut)
def cancel_order(
    order_id: str,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    """Buyer cancels an order that hasn't been paid yet."""
    o = _get_order(db, order_id)
    if o.buyer_id != buyer.id:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Not your order")
    if o.status not in ("pending", "accepted"):
        raise HTTPException(status.HTTP_409_CONFLICT, f"Cannot cancel an order in '{o.status}'")
    o.status = "cancelled"
    db.commit()
    db.refresh(o)
    notifications.order_cancelled(o.artisan_id, o.id)
    return o


# ---------- buyer delivery addresses ----------
@router.get("/addresses", response_model=list[AddressOut])
def list_addresses(
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    stmt = (
        select(Address)
        .where(Address.buyer_id == buyer.id)
        .order_by(Address.is_default.desc(), Address.created_at.desc())
    )
    return list(db.scalars(stmt))


@router.post("/addresses", response_model=AddressOut, status_code=status.HTTP_201_CREATED)
def add_address(
    body: AddressCreate,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    # First address (or an explicit request) becomes the default.
    existing = db.scalars(select(Address).where(Address.buyer_id == buyer.id)).all()
    make_default = body.is_default or not existing
    if make_default:
        for a in existing:
            a.is_default = False

    addr = Address(
        buyer_id=buyer.id, name=body.name, phone=body.phone, line1=body.line1,
        line2=body.line2, city=body.city, state=body.state, pincode=body.pincode,
        is_default=make_default,
    )
    db.add(addr)
    db.commit()
    db.refresh(addr)
    return addr


@router.delete("/addresses/{address_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_address(
    address_id: str,
    buyer: Buyer = Depends(get_current_buyer),
    db: Session = Depends(get_db),
):
    addr = db.get(Address, address_id)
    if not addr or addr.buyer_id != buyer.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Address not found")
    db.delete(addr)
    db.commit()
