from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_buyer, get_current_user
from app.core.db import get_db
from app.models import Buyer, Order, Payment, Product, User
from app.models.schemas import (
    OrderCreate,
    OrderOut,
    PaymentCheckout,
    PaymentConfirm,
)
from app.services import payments

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

    order = Order(
        product_id=product.id,
        buyer_id=buyer.id,
        artisan_id=product.user_id,
        quantity=body.quantity,
        unit_price=unit,
        total_price=round(unit * body.quantity, 2),
        note=body.note,
        status="pending",
    )
    db.add(order)
    db.commit()
    db.refresh(order)
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
    return o
