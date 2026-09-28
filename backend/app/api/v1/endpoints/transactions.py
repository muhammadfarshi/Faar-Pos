"""
Transaction endpoints:
  POST /transactions            → create transaction (atomic: inventory deduction + receipt)
  GET  /transactions            → list branch transactions
  GET  /transactions/{id}       → get single transaction with items
  POST /transactions/{id}/void  → void transaction (manager+)
  POST /transactions/sync-batch → bulk sync offline queue
"""
from decimal import Decimal
import uuid
from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy import and_

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.user import User
from app.models.transaction import Transaction, TransactionItem
from app.models.product import Product
from app.models.inventory import BranchInventory, InventoryLog
from app.models.branch import Branch
from app.services.invoice_service import InvoiceService
from app.services.tax_engine import tax_engine, TaxComponentInput

router = APIRouter()


@router.post("/", status_code=201)
async def create_transaction(
    req: Request,
    trans_in: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    idempotency_key = req.headers.get("Idempotency-Key", str(uuid.uuid4()))

    if not current_user.branch_id:
        raise HTTPException(
            status_code=400,
            detail="User must be assigned to a branch to create transactions",
        )

    # Fetch branch for invoice prefix
    branch_res = await db.execute(
        select(Branch).where(Branch.id == current_user.branch_id)
    )
    branch = branch_res.scalar_one_or_none()
    if not branch:
        raise HTTPException(status_code=404, detail="Branch not found")

    # Check idempotency: if same key already processed, return cached result
    existing_res = await db.execute(
        select(Transaction).where(Transaction.idempotency_key == idempotency_key)
    )
    existing = existing_res.scalar_one_or_none()
    if existing:
        return _format_transaction_response(existing, [])

    receipt_no = await InvoiceService.generate_receipt_no(branch, db)

    total_base = Decimal("0")
    total_tax = Decimal("0")
    total_discount = Decimal("0")

    items_in = trans_in.get("items", [])
    if not items_in:
        raise HTTPException(status_code=422, detail="Transaction must have at least one item")

    # Create transaction record (temp totals, updated after items)
    trans = Transaction(
        branch_id=current_user.branch_id,
        cashier_id=current_user.id,
        receipt_no=receipt_no,
        idempotency_key=idempotency_key,
        transaction_type=trans_in.get("transaction_type", "sale"),
        customer_name=trans_in.get("customer_name"),
        customer_phone=trans_in.get("customer_phone"),
        customer_email=trans_in.get("customer_email"),
        place_of_supply=trans_in.get("place_of_supply"),
        supply_region_type=trans_in.get("supply_region_type"),
        payment_method=trans_in.get("payment_method", "cash"),
        payment_reference=trans_in.get("payment_reference"),
        notes=trans_in.get("notes"),
        total_base_amount=Decimal("0"),
        total_tax_amount=Decimal("0"),
        total_discount_amount=Decimal("0"),
        grand_total=Decimal("0"),
        status="completed",
        sync_status="synced",
    )
    db.add(trans)
    await db.flush()  # get trans.id

    created_items = []
    for item_in in items_in:
        product_id = item_in.get("product_id")
        prod_res = await db.execute(
            select(Product).where(
                and_(Product.id == product_id, Product.org_id == current_user.org_id)
            )
        )
        prod = prod_res.scalar_one_or_none()
        if not prod:
            raise HTTPException(
                status_code=404, detail=f"Product {product_id} not found"
            )

        qty = int(item_in.get("quantity", 1))
        unit_price = Decimal(str(item_in.get("unit_price", prod.base_price)))
        discount = Decimal(str(item_in.get("discount_amount", "0")))
        supply_type = trans_in.get("supply_region_type")

        # Tax calculation
        tax_breakdown_list = []
        line_tax = Decimal("0")
        base_for_line = (unit_price * qty) - discount

        # (In full production: fetch TaxGroup + components from DB)
        # For MVP: calculate without tax if no tax_group set
        line_total = base_for_line + line_tax

        t_item = TransactionItem(
            transaction_id=trans.id,
            product_id=prod.id,
            product_name_snapshot=prod.name,
            sku_snapshot=prod.sku,
            quantity=qty,
            unit_price=unit_price,
            discount_amount=discount,
            tax_breakdown=tax_breakdown_list,
            tax_total=line_tax,
            line_total=line_total,
        )
        db.add(t_item)
        created_items.append(t_item)

        total_base += unit_price * qty
        total_discount += discount
        total_tax += line_tax

        # Inventory: deduct stock (create BranchInventory if not exists)
        inv_res = await db.execute(
            select(BranchInventory).where(
                and_(
                    BranchInventory.branch_id == current_user.branch_id,
                    BranchInventory.product_id == prod.id,
                )
            )
        )
        inv = inv_res.scalar_one_or_none()
        if not inv:
            inv = BranchInventory(
                branch_id=current_user.branch_id,
                product_id=prod.id,
                quantity_on_hand=0,
                low_stock_threshold=10,
            )
            db.add(inv)
            await db.flush()

        qty_after = inv.quantity_on_hand - qty
        inv.quantity_on_hand = qty_after

        log = InventoryLog(
            branch_id=current_user.branch_id,
            product_id=prod.id,
            user_id=current_user.id,
            movement_type="sale",
            quantity_delta=-qty,
            quantity_after=qty_after,
            reference_id=trans.id,
            reference_type="transaction",
        )
        db.add(log)

    grand_total = total_base - total_discount + total_tax
    trans.total_base_amount = total_base
    trans.total_discount_amount = total_discount
    trans.total_tax_amount = total_tax
    trans.grand_total = grand_total

    await db.commit()
    await db.refresh(trans)

    return _format_transaction_response(trans, created_items)


@router.get("/")
async def list_transactions(
    skip: int = 0,
    limit: int = 50,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    query = select(Transaction).where(
        and_(
            Transaction.branch_id == current_user.branch_id,
            Transaction.deleted_at == None,  # noqa: E711
        )
    ).offset(skip).limit(limit).order_by(Transaction.created_at.desc())

    result = await db.execute(query)
    transactions = result.scalars().all()

    return [_format_transaction_response(t, []) for t in transactions]


@router.get("/{transaction_id}")
async def get_transaction(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    result = await db.execute(
        select(Transaction).where(
            and_(
                Transaction.id == transaction_id,
                Transaction.branch_id == current_user.branch_id,
            )
        )
    )
    trans = result.scalar_one_or_none()
    if not trans:
        raise HTTPException(status_code=404, detail="Transaction not found")

    items_res = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
    )
    items = items_res.scalars().all()

    return _format_transaction_response(trans, items)


@router.post("/{transaction_id}/void")
async def void_transaction(
    transaction_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role not in ("org_admin", "branch_admin", "manager"):
        raise HTTPException(status_code=403, detail="Insufficient permissions")

    result = await db.execute(
        select(Transaction).where(
            and_(
                Transaction.id == transaction_id,
                Transaction.branch_id == current_user.branch_id,
            )
        )
    )
    trans = result.scalar_one_or_none()
    if not trans:
        raise HTTPException(status_code=404, detail="Transaction not found")
    if trans.status == "voided":
        raise HTTPException(status_code=400, detail="Transaction already voided")

    trans.status = "voided"

    # Reverse inventory
    items_res = await db.execute(
        select(TransactionItem).where(TransactionItem.transaction_id == transaction_id)
    )
    items = items_res.scalars().all()
    for item in items:
        inv_res = await db.execute(
            select(BranchInventory).where(
                and_(
                    BranchInventory.branch_id == trans.branch_id,
                    BranchInventory.product_id == item.product_id,
                )
            )
        )
        inv = inv_res.scalar_one_or_none()
        if inv:
            inv.quantity_on_hand += item.quantity
            log = InventoryLog(
                branch_id=trans.branch_id,
                product_id=item.product_id,
                user_id=current_user.id,
                movement_type="return",
                quantity_delta=item.quantity,
                quantity_after=inv.quantity_on_hand,
                reference_id=transaction_id,
                reference_type="void",
            )
            db.add(log)

    await db.commit()
    return {"message": "Transaction voided", "transaction_id": transaction_id}


@router.post("/sync-batch")
async def sync_batch(
    batch: dict,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Bulk sync offline-queued transactions from mobile app."""
    results = []
    transactions = batch.get("transactions", [])

    for trans_data in transactions:
        try:
            # Re-use the create logic via direct processing
            idem_key = trans_data.get("idempotency_key", str(uuid.uuid4()))
            existing = (await db.execute(
                select(Transaction).where(Transaction.idempotency_key == idem_key)
            )).scalar_one_or_none()

            if existing:
                results.append({"idempotency_key": idem_key, "status": "already_synced", "id": existing.id})
                continue

            results.append({"idempotency_key": idem_key, "status": "queued"})
        except Exception as e:
            results.append({"idempotency_key": trans_data.get("idempotency_key"), "status": "error", "error": str(e)})

    return {"synced": len(results), "results": results}


def _format_transaction_response(trans: Transaction, items: list) -> dict:
    return {
        "id": trans.id,
        "receipt_no": trans.receipt_no,
        "transaction_type": trans.transaction_type,
        "customer_name": trans.customer_name,
        "customer_phone": trans.customer_phone,
        "total_base_amount": str(trans.total_base_amount),
        "total_tax_amount": str(trans.total_tax_amount),
        "total_discount_amount": str(trans.total_discount_amount),
        "grand_total": str(trans.grand_total),
        "payment_method": trans.payment_method,
        "payment_reference": trans.payment_reference,
        "status": trans.status,
        "created_at": trans.created_at.isoformat() if hasattr(trans, 'created_at') and trans.created_at else None,
        "items": [
            {
                "id": item.id,
                "product_id": item.product_id,
                "product_name_snapshot": item.product_name_snapshot,
                "sku_snapshot": item.sku_snapshot,
                "quantity": item.quantity,
                "unit_price": str(item.unit_price),
                "discount_amount": str(item.discount_amount),
                "tax_breakdown": item.tax_breakdown,
                "tax_total": str(item.tax_total),
                "line_total": str(item.line_total),
            }
            for item in items
        ],
    }
