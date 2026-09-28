import uuid
from sqlalchemy import Integer, String, ForeignKey, Text, DECIMAL, CheckConstraint, DateTime, JSON, Uuid
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column
from datetime import datetime, timezone
from .base import Base, TimestampMixin

class Transaction(Base, TimestampMixin):
    __tablename__ = "transactions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    branch_id: Mapped[int] = mapped_column(Integer, ForeignKey("branches.id", ondelete="RESTRICT"), nullable=False)
    cashier_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="RESTRICT"), nullable=False)
    receipt_no: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    transaction_type: Mapped[str] = mapped_column(String(20), nullable=False)
    customer_name: Mapped[str | None] = mapped_column(String(255), nullable=True)
    customer_phone: Mapped[str | None] = mapped_column(String(50), nullable=True)
    customer_email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    place_of_supply: Mapped[str | None] = mapped_column(String(100), nullable=True)
    supply_region_type: Mapped[str | None] = mapped_column(String(20), nullable=True)
    total_base_amount: Mapped[float] = mapped_column(DECIMAL(12, 2), nullable=False)
    total_tax_amount: Mapped[float] = mapped_column(DECIMAL(12, 2), nullable=False)
    total_discount_amount: Mapped[float] = mapped_column(DECIMAL(12, 2), default=0, nullable=False)
    grand_total: Mapped[float] = mapped_column(DECIMAL(12, 2), nullable=False)
    payment_method: Mapped[str] = mapped_column(String(30), nullable=False)
    payment_reference: Mapped[str | None] = mapped_column(String(255), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default='completed', nullable=False)
    notes: Mapped[str | None] = mapped_column(Text, nullable=True)
    sync_status: Mapped[str] = mapped_column(String(20), default='synced', nullable=False)

    __table_args__ = (
        CheckConstraint(transaction_type.in_(['sale', 'refund']), name="check_transaction_type"),
    )

class TransactionItem(Base):
    __tablename__ = "transaction_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    transaction_id: Mapped[int] = mapped_column(Integer, ForeignKey("transactions.id", ondelete="RESTRICT"), nullable=False)
    product_id: Mapped[int] = mapped_column(Integer, ForeignKey("products.id", ondelete="RESTRICT"), nullable=False)
    product_name_snapshot: Mapped[str] = mapped_column(String(255), nullable=False)
    sku_snapshot: Mapped[str] = mapped_column(String(100), nullable=False)
    quantity: Mapped[int] = mapped_column(Integer, nullable=False)
    unit_price: Mapped[float] = mapped_column(DECIMAL(12, 4), nullable=False)
    discount_amount: Mapped[float] = mapped_column(DECIMAL(10, 2), default=0, nullable=False)
    tax_breakdown: Mapped[dict] = mapped_column(JSONB().with_variant(JSON, "sqlite"), default=list, nullable=False)
    tax_total: Mapped[float] = mapped_column(DECIMAL(10, 2), default=0, nullable=False)
    line_total: Mapped[float] = mapped_column(DECIMAL(12, 2), nullable=False)

class IdempotencyKey(Base):
    __tablename__ = "idempotency_keys"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True).with_variant(Uuid(as_uuid=True), "sqlite"), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    idempotency_key: Mapped[str] = mapped_column(String(255), nullable=False, index=True)
    status: Mapped[str] = mapped_column(String(20), default='processing', nullable=False)
    response_status_code: Mapped[int | None] = mapped_column(Integer, nullable=True)
    response_body: Mapped[dict | None] = mapped_column(JSONB().with_variant(JSON, "sqlite"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
