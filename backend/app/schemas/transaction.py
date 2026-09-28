from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from decimal import Decimal
from datetime import datetime

class TransactionItemCreate(BaseModel):
    product_id: int
    quantity: int
    unit_price: Decimal
    discount_amount: Decimal = Decimal('0')

class TransactionCreate(BaseModel):
    transaction_type: str
    customer_name: Optional[str] = None
    customer_phone: Optional[str] = None
    customer_email: Optional[str] = None
    place_of_supply: Optional[str] = None
    supply_region_type: Optional[str] = None
    payment_method: str
    payment_reference: Optional[str] = None
    notes: Optional[str] = None
    items: List[TransactionItemCreate]

class TransactionItemResponse(BaseModel):
    id: int
    transaction_id: int
    product_id: int
    product_name_snapshot: str
    sku_snapshot: str
    quantity: int
    unit_price: Decimal
    discount_amount: Decimal
    tax_breakdown: list
    tax_total: Decimal
    line_total: Decimal
    model_config = ConfigDict(from_attributes=True)

class TransactionResponse(BaseModel):
    id: int
    branch_id: int
    cashier_id: int
    receipt_no: str
    idempotency_key: str
    transaction_type: str
    customer_name: Optional[str]
    customer_phone: Optional[str]
    customer_email: Optional[str]
    total_base_amount: Decimal
    total_tax_amount: Decimal
    total_discount_amount: Decimal
    grand_total: Decimal
    payment_method: str
    status: str
    sync_status: str
    created_at: datetime
    items: List[TransactionItemResponse]
    model_config = ConfigDict(from_attributes=True)

class VoidRequest(BaseModel):
    reason: Optional[str] = None
