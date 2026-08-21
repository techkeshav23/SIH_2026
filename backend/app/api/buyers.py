from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.db import get_db
from app.models import Inquiry, Product
from app.models.schemas import InquiryCreate, InquiryOut, ProductOut

router = APIRouter(prefix="/buyers", tags=["buyers"])


@router.get("/feed", response_model=list[ProductOut])
def feed(category: str | None = None, db: Session = Depends(get_db)):
    """Public discovery of listed products — simulated ONDC/GeM buyer view."""
    stmt = select(Product).where(Product.status == "listed")
    if category:
        stmt = stmt.where(Product.category == category)
    return list(db.scalars(stmt.order_by(Product.updated_at.desc())))


@router.post("/inquiries", response_model=InquiryOut, status_code=status.HTTP_201_CREATED)
def create_inquiry(body: InquiryCreate, db: Session = Depends(get_db)):
    p = db.get(Product, body.product_id)
    if not p:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")
    inq = Inquiry(product_id=body.product_id, org_name=body.org_name, message=body.message)
    db.add(inq)
    db.commit()
    db.refresh(inq)
    return inq
