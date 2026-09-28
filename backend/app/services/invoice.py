from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from app.models.branch import Branch

async def generate_invoice_number(branch_id: str, db: AsyncSession) -> str:
    # We must lock the branch row for update to ensure atomic increment
    result = await db.execute(
        select(Branch).where(Branch.id == branch_id).with_for_update()
    )
    branch = result.scalar_one_or_none()
    
    if not branch:
        raise ValueError("Branch not found")

    sequence = branch.invoice_sequence
    branch.invoice_sequence += 1
    
    now = datetime.now(timezone.utc)
    year = now.strftime("%Y")
    month = now.strftime("%m")
    
    # Format: {invoice_prefix}{YYYY}{MM}-{SEQUENCE:06d}
    invoice_no = f"{branch.invoice_prefix}{year}{month}-{sequence:06d}"
    return invoice_no
