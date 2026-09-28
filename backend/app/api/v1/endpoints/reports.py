from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import func
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.transaction import Transaction
from app.schemas.report import EODReportResponse
from datetime import date

router = APIRouter()

@router.get("/eod", response_model=EODReportResponse)
async def eod_report(target_date: date, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Very simplified
    result = await db.execute(
        select(
            func.sum(Transaction.grand_total).label("net_revenue"),
            func.sum(Transaction.total_tax_amount).label("total_tax"),
            func.count(Transaction.id).label("count")
        ).where(
            Transaction.branch_id == current_user.branch_id,
            func.date(Transaction.created_at) == target_date
        )
    )
    row = result.first()
    
    return {
        "date": target_date,
        "branch_id": current_user.branch_id,
        "total_sales": row.net_revenue or 0,
        "total_refunds": 0,
        "net_revenue": row.net_revenue or 0,
        "total_tax": row.total_tax or 0,
        "transaction_count": row.count or 0
    }
