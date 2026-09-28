from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.printer import PrinterConfig
from app.schemas.printer import PrinterConfigCreate, PrinterConfigResponse

router = APIRouter()

@router.post("/", response_model=PrinterConfigResponse)
async def create_printer(p_in: PrinterConfigCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    printer = PrinterConfig(**p_in.model_dump(), branch_id=current_user.branch_id)
    db.add(printer)
    await db.commit()
    await db.refresh(printer)
    return printer

@router.get("/", response_model=list[PrinterConfigResponse])
async def list_printers(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(PrinterConfig).where(PrinterConfig.branch_id == current_user.branch_id))
    return result.scalars().all()
