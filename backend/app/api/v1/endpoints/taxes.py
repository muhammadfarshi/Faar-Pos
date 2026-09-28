from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.tax import TaxGroup, TaxComponent
from app.models.user import User
from app.schemas.tax import TaxGroupCreate, TaxGroupResponse, TaxCalculationRequest, TaxCalculationResponse
from app.services.tax_engine import TaxCalculationService
from decimal import Decimal

router = APIRouter()

@router.post("/", response_model=TaxGroupResponse)
async def create_tax_group(tax_in: TaxGroupCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    components_data = tax_in.components
    tax_group_data = tax_in.model_dump(exclude={"components"})
    
    total_rate = sum(c.rate for c in components_data)
    
    group = TaxGroup(**tax_group_data, org_id=current_user.org_id, total_rate=total_rate)
    db.add(group)
    await db.flush() # get ID
    
    for c in components_data:
        comp = TaxComponent(**c.model_dump(), tax_group_id=group.id)
        db.add(comp)
        
    await db.commit()
    await db.refresh(group)
    return group

@router.post("/calculate", response_model=TaxCalculationResponse)
async def calculate_tax(req: TaxCalculationRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(TaxGroup).where(TaxGroup.id == req.tax_group_id))
    group = result.scalar_one_or_none()
    if not group:
        return {"base_amount": req.base_amount, "tax_amount": 0, "total_amount": req.base_amount}
        
    tax_amount = TaxCalculationService.calculate(req.base_amount, Decimal(str(group.total_rate)))
    return {
        "base_amount": req.base_amount,
        "tax_amount": tax_amount,
        "total_amount": req.base_amount + tax_amount
    }
