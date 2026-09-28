from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.inventory import BranchInventory, InventoryLog
from app.schemas.inventory import BranchInventoryResponse, RestockRequest, InventoryLogResponse

router = APIRouter()

@router.get("/", response_model=list[BranchInventoryResponse])
async def list_inventory(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(BranchInventory).where(BranchInventory.branch_id == current_user.branch_id))
    return result.scalars().all()

@router.post("/restock", response_model=InventoryLogResponse)
async def restock(req: RestockRequest, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    inv_res = await db.execute(select(BranchInventory).where(
        BranchInventory.branch_id == current_user.branch_id,
        BranchInventory.product_id == req.product_id
    ))
    inv = inv_res.scalar_one_or_none()
    if not inv:
        inv = BranchInventory(branch_id=current_user.branch_id, product_id=req.product_id, quantity_on_hand=0)
        db.add(inv)
        
    qty_after = inv.quantity_on_hand + req.quantity_added
    inv.quantity_on_hand = qty_after
    
    log = InventoryLog(
        branch_id=current_user.branch_id,
        product_id=req.product_id,
        user_id=current_user.id,
        movement_type='restock',
        quantity_delta=req.quantity_added,
        quantity_after=qty_after,
        notes=req.notes
    )
    db.add(log)
    await db.commit()
    await db.refresh(log)
    return log
