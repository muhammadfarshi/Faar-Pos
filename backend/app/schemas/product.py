from pydantic import BaseModel, ConfigDict
from typing import Optional
from decimal import Decimal

class CategoryCreate(BaseModel):
    name: str
    description: Optional[str] = None
    sort_order: int = 0

class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    sort_order: Optional[int] = None

class CategoryResponse(CategoryCreate):
    id: int
    org_id: int
    model_config = ConfigDict(from_attributes=True)

class ProductCreate(BaseModel):
    name: str
    sku: str
    category_id: Optional[int] = None
    description: Optional[str] = None
    unit_of_measure: str = "pcs"
    base_price: Decimal
    tax_group_id: Optional[int] = None
    barcode: Optional[str] = None
    image_url: Optional[str] = None

class ProductUpdate(BaseModel):
    name: Optional[str] = None
    category_id: Optional[int] = None
    description: Optional[str] = None
    base_price: Optional[Decimal] = None
    barcode: Optional[str] = None
    image_url: Optional[str] = None
    is_active: Optional[bool] = None

class ProductResponse(ProductCreate):
    id: int
    org_id: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)

class ProductWithInventory(ProductResponse):
    quantity_on_hand: int
    model_config = ConfigDict(from_attributes=True)
