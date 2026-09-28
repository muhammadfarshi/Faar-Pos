from sqlalchemy import Integer, String, Boolean, CHAR
from sqlalchemy.orm import Mapped, mapped_column
from .base import Base, TimestampMixin

class Organization(Base, TimestampMixin):
    __tablename__ = "organizations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    slug: Mapped[str] = mapped_column(String(100), unique=True, index=True, nullable=False)
    country_code: Mapped[str] = mapped_column(CHAR(2), nullable=False)
    currency_code: Mapped[str] = mapped_column(CHAR(3), nullable=False)
    currency_symbol: Mapped[str] = mapped_column(String(10), nullable=False)
    timezone: Mapped[str] = mapped_column(String(50), nullable=False)
    logo_url: Mapped[str | None] = mapped_column(String(255), nullable=True)
    subscription_plan: Mapped[str] = mapped_column(String(50), default='starter', nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
