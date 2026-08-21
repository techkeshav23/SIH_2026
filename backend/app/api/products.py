from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import Product, User
from app.models.schemas import ProductCreate, ProductOut, ProductUpdate

router = APIRouter(prefix="/products", tags=["products"])


def _owned(db: Session, user: User, product_id: str) -> Product:
    p = db.get(Product, product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    return p


@router.get("", response_model=list[ProductOut])
def list_products(
    status_filter: str | None = None,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    stmt = select(Product).where(Product.user_id == user.id)
    if status_filter:
        stmt = stmt.where(Product.status == status_filter)
    return list(db.scalars(stmt.order_by(Product.created_at.desc())))


@router.post("", response_model=ProductOut, status_code=status.HTTP_201_CREATED)
def create_product(
    body: ProductCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = Product(user_id=user.id, category=body.category, material=body.material, status="draft")
    db.add(p)
    db.commit()
    db.refresh(p)
    return p


@router.get("/{product_id}", response_model=ProductOut)
def get_product(
    product_id: str,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    return _owned(db, user, product_id)


@router.patch("/{product_id}", response_model=ProductOut)
def update_product(
    product_id: str,
    body: ProductUpdate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = _owned(db, user, product_id)
    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(p, field, value)
    db.commit()
    db.refresh(p)
    return p
