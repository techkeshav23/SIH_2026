from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


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
    consent_version: str | None = None


class ConsentIn(BaseModel):
    version: str


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


# ---- Buyer auth ----
class BuyerOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    phone: str
    name: str | None = None
    org_name: str | None = None
    gstin: str | None = None
    type: str = "B2B"
    consent_version: str | None = None


class BuyerUpdate(BaseModel):
    name: str | None = None
    org_name: str | None = None
    gstin: str | None = None
    type: str | None = None


class BuyerAuthToken(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    buyer: BuyerOut


# ---- Addresses ----
class AddressCreate(BaseModel):
    name: str
    phone: str
    line1: str
    line2: str | None = None
    city: str
    state: str
    pincode: str
    is_default: bool = False


class AddressOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    name: str
    phone: str
    line1: str
    line2: str | None = None
    city: str
    state: str
    pincode: str
    is_default: bool


# ---- Orders ----
class OrderCreate(BaseModel):
    product_id: str
    quantity: int = 1
    note: str | None = None
    address_id: str | None = None


class OrderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    product_id: str
    buyer_id: str
    artisan_id: str
    quantity: int
    unit_price: float
    total_price: float
    status: str
    note: str | None = None
    ship_name: str | None = None
    ship_phone: str | None = None
    ship_address: str | None = None
    created_at: datetime
    updated_at: datetime


# ---- Payments ----
class PaymentCheckout(BaseModel):
    """Returned to the client to launch the payment sheet (e.g. Razorpay)."""
    order_id: str
    payment_id: str
    provider: str
    provider_order_id: str
    amount: float
    currency: str = "INR"
    key_id: str | None = None  # publishable key for the client SDK


class PaymentConfirm(BaseModel):
    provider_payment_id: str | None = None
    signature: str | None = None


# ---- Reviews ----
class ReviewCreate(BaseModel):
    rating: int
    text: str | None = None


class ReviewOut(BaseModel):
    id: str
    product_id: str
    author: str
    rating: int
    text: str | None = None
    date: datetime | None = None


# ---- Notifications ----
class NotificationOut(BaseModel):
    id: str
    title: str
    body: str | None = None
    type: str
    read: bool
    time: datetime | None = None


# ---- Quotes (B2B RFQ / negotiation) ----
class QuoteCreate(BaseModel):
    product_id: str
    quantity: int
    target_price: float          # buyer's per-unit offer
    message: str | None = None


class QuotePrice(BaseModel):
    price: float                 # per-unit counter offer


class QuoteOut(BaseModel):
    id: str
    product_id: str
    product_title: str | None = None
    product_image: str | None = None
    quantity: int
    buyer_price: float
    artisan_price: float | None = None
    agreed_price: float | None = None
    list_price: float | None = None
    status: str
    turn: str
    message: str | None = None
    order_id: str | None = None
    created_at: datetime


# ---- Storefront ----
class StorefrontOut(BaseModel):
    artisan_id: str
    name: str | None = None
    craft_type: str | None = None
    region: str | None = None
    products: list[ProductOut] = []


# ---- Ad campaigns ----
class CampaignCreate(BaseModel):
    name: str
    product_id: str | None = None
    objective: str = "OUTCOME_TRAFFIC"     # OUTCOME_TRAFFIC | OUTCOME_ENGAGEMENT | OUTCOME_SALES
    daily_budget: float = 200.0            # INR — informational only, campaign is created PAUSED
    platforms: list[str] = ["meta"]        # "meta" | "google" | both


class BudgetIncrease(BaseModel):
    amount: float = Field(ge=250.0)  # ₹250 minimum bump, enforced server-side too


class CampaignOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    user_id: str
    product_id: str | None = None
    name: str
    objective: str
    daily_budget: float
    platforms: list[str] = []
    status: str
    platform_ids: dict = {}
    platform_urls: dict = {}
    error: str | None = None
    created_at: datetime


# ---- Dashboard ----
class ArtisanStats(BaseModel):
    products: int
    listed: int
    orders_total: int
    orders_pending: int
    orders_paid: int
    earnings: float
