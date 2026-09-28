from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import update
from app.models.branch import Branch

class InvoiceService:
    @staticmethod
    async def generate_receipt_no(branch_id: int, db: AsyncSession) -> str:
        # Atomic increment with SELECT FOR UPDATE
        result = await db.execute(
            select(Branch).where(Branch.id == branch_id).with_for_update()
        )
        branch = result.scalar_one_or_none()
        if not branch:
            raise ValueError("Branch not found")

        branch.invoice_sequence += 1
        seq = branch.invoice_sequence
        prefix = branch.invoice_prefix
        
        now = datetime.now(timezone.utc)
        year_str = now.strftime("%Y")
        month_str = now.strftime("%m")
        
        receipt_no = f"{prefix}{year_str}{month_str}-{seq:06d}"
        
        # Save back to db is handled by caller committing the session
        return receipt_no
