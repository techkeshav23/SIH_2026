import uuid
from datetime import datetime, timezone

from sqlalchemy import JSON, DateTime, Float, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.db import Base


def _uuid() -> str:
    return uuid.uuid4().hex


def _now() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    language_pref: Mapped[str] = mapped_column(String, default="hi")
    craft_type: Mapped[str | None] = mapped_column(String, nullable=True)
    region: Mapped[str | None] = mapped_column(String, nullable=True)
    # DPDP Act 2023 consent audit trail
    consent_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    consent_version: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)

    products: Mapped[list["Product"]] = relationship(back_populates="user")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    user_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)

    title_en: Mapped[str | None] = mapped_column(String, nullable=True)
    title_hi: Mapped[str | None] = mapped_column(String, nullable=True)
    desc_en: Mapped[str | None] = mapped_column(Text, nullable=True)
    desc_hi: Mapped[str | None] = mapped_column(Text, nullable=True)
    category: Mapped[str | None] = mapped_column(String, nullable=True)
    material: Mapped[str | None] = mapped_column(String, nullable=True)
    tags: Mapped[list] = mapped_column(JSON, default=list)

    status: Mapped[str] = mapped_column(String, default="draft")  # draft|processing|ready|listed
    raw_image_url: Mapped[str | None] = mapped_column(String, nullable=True)
    enhanced_image_url: Mapped[str | None] = mapped_column(String, nullable=True)

    suggested_price_min: Mapped[float | None] = mapped_column(Float, nullable=True)
    suggested_price_max: Mapped[float | None] = mapped_column(Float, nullable=True)
    final_price: Mapped[float | None] = mapped_column(Float, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now)

    user: Mapped["User"] = relationship(back_populates="products")


class VoiceNote(Base):
    __tablename__ = "voice_notes"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    audio_url: Mapped[str | None] = mapped_column(String, nullable=True)
    transcript_raw: Mapped[str | None] = mapped_column(Text, nullable=True)
    transcript_lang: Mapped[str | None] = mapped_column(String, nullable=True)
    translated_en: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class PriceSignal(Base):
    __tablename__ = "price_signals"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    model_price: Mapped[float | None] = mapped_column(Float, nullable=True)
    comparables: Mapped[list] = mapped_column(JSON, default=list)
    reasoning: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Buyer(Base):
    __tablename__ = "buyers"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    phone: Mapped[str] = mapped_column(String, unique=True, index=True)
    name: Mapped[str | None] = mapped_column(String, nullable=True)
    org_name: Mapped[str | None] = mapped_column(String, nullable=True)
    gstin: Mapped[str | None] = mapped_column(String, nullable=True)
    type: Mapped[str] = mapped_column(String, default="B2B")  # GeM|B2B|retail
    # DPDP Act 2023 consent audit trail
    consent_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    consent_version: Mapped[str | None] = mapped_column(String, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Address(Base):
    __tablename__ = "addresses"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    buyer_id: Mapped[str] = mapped_column(ForeignKey("buyers.id"), index=True)
    name: Mapped[str] = mapped_column(String)
    phone: Mapped[str] = mapped_column(String)
    line1: Mapped[str] = mapped_column(String)
    line2: Mapped[str | None] = mapped_column(String, nullable=True)
    city: Mapped[str] = mapped_column(String)
    state: Mapped[str] = mapped_column(String)
    pincode: Mapped[str] = mapped_column(String)
    is_default: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    buyer_id: Mapped[str] = mapped_column(ForeignKey("buyers.id"), index=True)
    artisan_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)

    quantity: Mapped[int] = mapped_column(Integer, default=1)
    unit_price: Mapped[float] = mapped_column(Float)
    total_price: Mapped[float] = mapped_column(Float)

    # Denormalized shipping snapshot — kept even if the buyer edits/deletes the
    # saved address later, so the artisan always sees where to dispatch.
    ship_name: Mapped[str | None] = mapped_column(String, nullable=True)
    ship_phone: Mapped[str | None] = mapped_column(String, nullable=True)
    ship_address: Mapped[str | None] = mapped_column(Text, nullable=True)

    # pending -> accepted/rejected -> paid -> shipped -> completed | cancelled
    status: Mapped[str] = mapped_column(String, default="pending", index=True)
    note: Mapped[str | None] = mapped_column(Text, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now)


class Payment(Base):
    __tablename__ = "payments"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    order_id: Mapped[str] = mapped_column(ForeignKey("orders.id"), index=True)
    provider: Mapped[str] = mapped_column(String, default="mock")
    provider_order_id: Mapped[str | None] = mapped_column(String, nullable=True)
    provider_payment_id: Mapped[str | None] = mapped_column(String, nullable=True)
    amount: Mapped[float] = mapped_column(Float)
    currency: Mapped[str] = mapped_column(String, default="INR")
    status: Mapped[str] = mapped_column(String, default="created")  # created|paid|failed
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Inquiry(Base):
    __tablename__ = "inquiries"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    org_name: Mapped[str] = mapped_column(String)
    message: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String, default="new")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Review(Base):
    __tablename__ = "reviews"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    buyer_id: Mapped[str | None] = mapped_column(ForeignKey("buyers.id"), nullable=True, index=True)
    author_name: Mapped[str | None] = mapped_column(String, nullable=True)
    rating: Mapped[int] = mapped_column(Integer, default=5)
    text: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)


class Quote(Base):
    """B2B bulk-order price negotiation (RFQ). A buyer requests a quote for a
    quantity at a target unit price; the artisan counters/accepts; either side
    can keep countering until one accepts (-> becomes an Order) or declines."""

    __tablename__ = "quotes"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    product_id: Mapped[str] = mapped_column(ForeignKey("products.id"), index=True)
    buyer_id: Mapped[str] = mapped_column(ForeignKey("buyers.id"), index=True)
    artisan_id: Mapped[str] = mapped_column(ForeignKey("users.id"), index=True)

    quantity: Mapped[int] = mapped_column(Integer, default=1)
    buyer_price: Mapped[float] = mapped_column(Float)                 # buyer's current per-unit offer
    artisan_price: Mapped[float | None] = mapped_column(Float, nullable=True)  # artisan's current counter
    agreed_price: Mapped[float | None] = mapped_column(Float, nullable=True)   # set on accept
    list_price: Mapped[float | None] = mapped_column(Float, nullable=True)     # product price at request time

    # open (awaiting `turn`) | accepted | declined
    status: Mapped[str] = mapped_column(String, default="open", index=True)
    turn: Mapped[str] = mapped_column(String, default="artisan")      # who must respond next
    message: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_id: Mapped[str | None] = mapped_column(String, nullable=True)  # set when accepted -> order

    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_now, onupdate=_now)


class Notification(Base):
    """A per-recipient alert. recipient_id/role stay generic so both artisans
    (users) and buyers can receive notifications without a rigid FK."""

    __tablename__ = "notifications"

    id: Mapped[str] = mapped_column(String, primary_key=True, default=_uuid)
    recipient_id: Mapped[str] = mapped_column(String, index=True)
    recipient_role: Mapped[str] = mapped_column(String, default="artisan")  # artisan|buyer
    kind: Mapped[str] = mapped_column(String, default="info")  # order|review|inquiry|info
    title: Mapped[str] = mapped_column(String)
    body: Mapped[str | None] = mapped_column(Text, nullable=True)
    read: Mapped[bool] = mapped_column(default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_now, index=True)
