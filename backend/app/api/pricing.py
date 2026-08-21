from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.db import get_db
from app.models import PriceSignal, Product, User
from app.models.schemas import PriceRequest, PriceSuggestion
from app.services import pricing_engine

router = APIRouter(prefix="/pricing", tags=["pricing"])


@router.post("/suggest", response_model=PriceSuggestion)
def suggest_price(
    body: PriceRequest,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    p = db.get(Product, body.product_id)
    if not p or p.user_id != user.id:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Product not found")

    result = pricing_engine.suggest(p.id, p.category, p.material, body.material_cost)

    p.suggested_price_min = result.suggested_price_min
    p.suggested_price_max = result.suggested_price_max
    db.add(PriceSignal(
        product_id=p.id,
        model_price=(result.suggested_price_min + result.suggested_price_max) / 2,
        comparables=[c.model_dump() for c in result.comparables],
        reasoning=result.reasoning,
    ))
    db.commit()
    return result
