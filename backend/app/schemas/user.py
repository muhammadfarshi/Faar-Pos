from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional

class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    role: str
    branch_id: Optional[int] = None

class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    role: Optional[str] = None
    branch_id: Optional[int] = None
    is_active: Optional[bool] = None

class UserResponse(BaseModel):
    id: int
    org_id: int
    branch_id: Optional[int]
    email: EmailStr
    full_name: str
    role: str
    is_active: bool
    model_config = ConfigDict(from_attributes=True)

class PasswordReset(BaseModel):
    old_password: str
    new_password: str
