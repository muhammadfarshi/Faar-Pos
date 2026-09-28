from pydantic import BaseModel, ConfigDict
from typing import Optional

class OrgCreate(BaseModel):
    name: str
    slug: str
    country_code: str
    currency_code: str
    currency_symbol: str
    timezone: str
    logo_url: Optional[str] = None
    subscription_plan: str = "starter"

class OrgUpdate(BaseModel):
    name: Optional[str] = None
    logo_url: Optional[str] = None
    is_active: Optional[bool] = None

class OrgResponse(OrgCreate):
    id: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)

class BranchCreate(BaseModel):
    name: str
    branch_code: str
    address: str
    city: str
    state_region: str
    country_code: str
    phone: str
    email: str
    invoice_prefix: str
    tax_registration_no: Optional[str] = None

class BranchUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    is_active: Optional[bool] = None

class BranchResponse(BranchCreate):
    id: int
    org_id: int
    invoice_sequence: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)
