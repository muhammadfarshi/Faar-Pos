from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from decimal import Decimal

class TaxComponentCreate(BaseModel):
    name: str
    rate: Decimal
    applies_condition: str = "always"

class TaxComponentResponse(TaxComponentCreate):
    id: int
    tax_group_id: int
    model_config = ConfigDict(from_attributes=True)

class TaxGroupCreate(BaseModel):
    name: str
    description: Optional[str] = None
    country_code: Optional[str] = None
    is_compound: bool = False
    components: List[TaxComponentCreate]

class TaxGroupUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    is_active: Optional[bool] = None

class TaxGroupResponse(BaseModel):
    id: int
    org_id: int
    name: str
    description: Optional[str]
    country_code: Optional[str]
    total_rate: Decimal
    is_compound: bool
    is_active: bool
    model_config = ConfigDict(from_attributes=True)

class TaxCalculationRequest(BaseModel):
    base_amount: Decimal
    tax_group_id: int

class TaxCalculationResponse(BaseModel):
    base_amount: Decimal
    tax_amount: Decimal
    total_amount: Decimal
