from datetime import datetime

from pydantic import BaseModel, ConfigDict


# ---- Auth ----
class OtpRequest(BaseModel):
    phone: str


class OtpSent(BaseModel):
    sent: bool
    dev_otp: str | None = None


class OtpVerify(BaseModel):
    phone: str
    otp: str


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    phone: str
    name: str | None = None
    language_pref: str = "hi"
    craft_type: str | None = None
    region: str | None = None


class UserUpdate(BaseModel):
    name: str | None = None
    language_pref: str | None = None
    craft_type: str | None = None
    region: str | None = None


class AuthToken(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: UserOut


class RefreshRequest(BaseModel):
    refresh_token: str


class AccessToken(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---- Products ----
class ProductCreate(BaseModel):
    category: str | None = None
    material: str | None = None


class ProductUpdate(BaseModel):
    title_en: str | None = None
    title_hi: str | None = None
    desc_en: str | None = None
    desc_hi: str | None = None
    category: str | None = None
    material: str | None = None
    tags: list[str] | None = None
    final_price: float | None = None
    status: str | None = None


class ProductOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    user_id: str
    title_en: str | None = None
    title_hi: str | None = None
    desc_en: str | None = None
    desc_hi: str | None = None
    category: str | None = None
    material: str | None = None
    tags: list[str] = []
    status: str
    raw_image_url: str | None = None
    enhanced_image_url: str | None = None
    suggested_price_min: float | None = None
    suggested_price_max: float | None = None
    final_price: float | None = None
    created_at: datetime
    updated_at: datetime


class JobAccepted(BaseModel):
    product_id: str
    status: str
    message: str = "processing — poll GET /products/{id}"


# ---- AI cataloger ----
class CatalogFromText(BaseModel):
    product_id: str
    text: str
    source_lang: str = "hi"


class CatalogResult(BaseModel):
    """Structured listing the LLM must return (also used as Gemini response schema)."""
    title_en: str
    title_hi: str
    description_en: str
    description_hi: str
    category: str
    material: str
    tags: list[str] = []
    transcript: str | None = None  # original-language transcript (voice path)


# ---- Pricing ----
class PriceRequest(BaseModel):
    product_id: str
    material_cost: float | None = None


class Comparable(BaseModel):
    title: str
    price: float
    source: str


class PriceSuggestion(BaseModel):
    product_id: str
    suggested_price_min: float
    suggested_price_max: float
    currency: str = "INR"
    reasoning: str
    comparables: list[Comparable] = []


# ---- Buyers ----
class InquiryCreate(BaseModel):
    product_id: str
    org_name: str
    message: str


class InquiryOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    product_id: str
    org_name: str
    message: str
    status: str
    created_at: datetime
