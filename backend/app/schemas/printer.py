from pydantic import BaseModel, ConfigDict
from typing import Optional

class PrinterConfigCreate(BaseModel):
    name: str
    connection_type: str
    paper_width_mm: int = 80
    ip_address: Optional[str] = None
    port: Optional[int] = None
    mac_address: Optional[str] = None
    is_default: bool = False

class PrinterConfigUpdate(BaseModel):
    name: Optional[str] = None
    connection_type: Optional[str] = None
    ip_address: Optional[str] = None
    port: Optional[int] = None
    mac_address: Optional[str] = None
    is_default: Optional[bool] = None
    is_active: Optional[bool] = None

class PrinterConfigResponse(PrinterConfigCreate):
    id: int
    branch_id: int
    is_active: bool
    model_config = ConfigDict(from_attributes=True)
