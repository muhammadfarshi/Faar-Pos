from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime

class BranchInventoryResponse(BaseModel):
    id: int
    branch_id: int
    product_id: int
    quantity_on_hand: int
    low_stock_threshold: int
    model_config = ConfigDict(from_attributes=True)

class InventoryLogResponse(BaseModel):
    id: int
    branch_id: int
    product_id: int
    user_id: int
    movement_type: str
    quantity_delta: int
    quantity_after: int
    notes: Optional[str]
    created_at: datetime
    model_config = ConfigDict(from_attributes=True)

class AdjustmentRequest(BaseModel):
    product_id: int
    quantity_delta: int
    notes: Optional[str] = None

class RestockRequest(BaseModel):
    product_id: int
    quantity_added: int
    notes: Optional[str] = None
