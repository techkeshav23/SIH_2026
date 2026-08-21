from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Order, Product, User
from app.models.schemas import ArtisanStats

router = APIRouter(tags=["dashboard"])


@router.get("/dashboard/artisan", response_model=ArtisanStats)
def artisan_stats(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    def count(stmt) -> int:
        return db.scalar(stmt) or 0

    products = count(select(func.count()).select_from(Product).where(Product.user_id == user.id))
    listed = count(select(func.count()).select_from(Product).where(
        Product.user_id == user.id, Product.status == "listed"))

    orders_base = select(func.count()).select_from(Order).where(Order.artisan_id == user.id)
    orders_total = count(orders_base)
    orders_pending = count(orders_base.where(Order.status == "pending"))
    orders_paid = count(orders_base.where(Order.status == "paid"))

    earnings = db.scalar(
        select(func.coalesce(func.sum(Order.total_price), 0.0)).where(
            Order.artisan_id == user.id, Order.status == "paid")
    ) or 0.0

    return ArtisanStats(
        products=products,
        listed=listed,
        orders_total=orders_total,
        orders_pending=orders_pending,
        orders_paid=orders_paid,
        earnings=float(earnings),
    )
