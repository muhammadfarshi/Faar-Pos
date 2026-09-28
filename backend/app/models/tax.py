from sqlalchemy import Integer, String, Boolean, ForeignKey, CHAR, DECIMAL, Text, CheckConstraint
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base, TimestampMixin

class TaxGroup(Base, TimestampMixin):
    __tablename__ = "tax_groups"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    org_id: Mapped[int] = mapped_column(Integer, ForeignKey("organizations.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    country_code: Mapped[str | None] = mapped_column(CHAR(2), nullable=True)
    total_rate: Mapped[float] = mapped_column(DECIMAL(6, 4), nullable=False)
    is_compound: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

class TaxComponent(Base):
    __tablename__ = "tax_components"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    tax_group_id: Mapped[int] = mapped_column(Integer, ForeignKey("tax_groups.id", ondelete="CASCADE"), nullable=False)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    rate: Mapped[float] = mapped_column(DECIMAL(6, 4), nullable=False)
    applies_condition: Mapped[str] = mapped_column(String(20), default='always', nullable=False)
    sort_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    __table_args__ = (
        CheckConstraint(applies_condition.in_(['always', 'intra_region', 'inter_region']), name="check_tax_condition"),
    )
