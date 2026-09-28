#!/usr/bin/env python3
"""
FAAR POS Database Seed Script
==============================
Creates a demo organization, branch, and admin user so you can log in immediately.

Usage:
    python seed.py

Default credentials after seeding:
    Email:    admin@faarpos.com
    Password: Admin@1234

Demo branch: FAAR Main Store (Branch Code: MAIN)
"""
import asyncio
import os
from decimal import Decimal
from passlib.context import CryptContext
from sqlalchemy import select
from app.core.database import async_session_maker, engine
from app.models.base import Base
from app.models.organization import Organization
from app.models.branch import Branch
from app.models.user import User
from app.models.tax import TaxGroup, TaxComponent
from app.models.product import Category, Product
from app.models.inventory import BranchInventory
from app.models.printer import PrinterConfig


async def seed():
    # Ensure tables exist
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with async_session_maker() as db:
        print("Connected to database")

        # --- Organization ---
        result = await db.execute(select(Organization).where(Organization.slug == "faar-store"))
        org = result.scalar_one_or_none()
        if not org:
            org = Organization(
                name="FAAR Store",
                slug="faar-store",
                country_code="IN",
                currency_code="INR",
                currency_symbol="₹",
                timezone="Asia/Kolkata",
                subscription_plan="professional",
                is_active=True
            )
            db.add(org)
            await db.flush()
            print(f" Organization created (id={org.id})")
        else:
            print(f" Organization found (id={org.id})")

        # --- Branch ---
        result = await db.execute(
            select(Branch).where(Branch.org_id == org.id, Branch.branch_code == "MAIN")
        )
        branch = result.scalar_one_or_none()
        if not branch:
            branch = Branch(
                org_id=org.id,
                name="FAAR Main Store",
                branch_code="MAIN",
                address="123 Market Street",
                city="Kochi",
                state_region="Kerala",
                country_code="IN",
                phone="+91-9876543210",
                email="main@faarstore.com",
                invoice_prefix="MAIN-",
                invoice_sequence=0,
                is_active=True
            )
            db.add(branch)
            await db.flush()
            print(f" Branch created (id={branch.id})")
        else:
            print(f" Branch found (id={branch.id})")

        # --- Admin User ---
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        admin_pw = pwd_context.hash("Admin@1234")

        result = await db.execute(select(User).where(User.email == "admin@faarpos.com"))
        admin_user = result.scalar_one_or_none()
        if not admin_user:
            admin_user = User(
                org_id=org.id,
                branch_id=branch.id,
                email="admin@faarpos.com",
                hashed_password=admin_pw,
                full_name="FAAR Admin",
                role="org_admin",
                is_active=True,
                token_version=0
            )
            db.add(admin_user)
            await db.flush()
            print(f" Admin user created (id={admin_user.id})")
        else:
            admin_user.hashed_password = admin_pw
            print(f" Admin user updated (id={admin_user.id})")

        # --- Cashier User ---
        cashier_pw = pwd_context.hash("Cashier@1234")
        result = await db.execute(select(User).where(User.email == "cashier@faarpos.com"))
        cashier_user = result.scalar_one_or_none()
        if not cashier_user:
            cashier_user = User(
                org_id=org.id,
                branch_id=branch.id,
                email="cashier@faarpos.com",
                hashed_password=cashier_pw,
                full_name="FAAR Cashier",
                role="cashier",
                is_active=True,
                token_version=0
            )
            db.add(cashier_user)
            await db.flush()
            print(f" Cashier user created (id={cashier_user.id})")
        else:
            cashier_user.hashed_password = cashier_pw
            print(f" Cashier user updated (id={cashier_user.id})")

        # --- Tax Group ---
        result = await db.execute(select(TaxGroup).where(TaxGroup.org_id == org.id, TaxGroup.name == "GST 18%"))
        tg = result.scalar_one_or_none()
        if not tg:
            tg = TaxGroup(
                org_id=org.id,
                name="GST 18%",
                description="India GST - 9% CGST + 9% SGST (intra) or 18% IGST (inter)",
                country_code="IN",
                total_rate=Decimal("0.1800"),
                is_compound=False,
                is_active=True
            )
            db.add(tg)
            await db.flush()

            cgst = TaxComponent(tax_group_id=tg.id, name="CGST", rate=Decimal("0.09"), applies_condition="intra_region", sort_order=1)
            sgst = TaxComponent(tax_group_id=tg.id, name="SGST", rate=Decimal("0.09"), applies_condition="intra_region", sort_order=2)
            igst = TaxComponent(tax_group_id=tg.id, name="IGST", rate=Decimal("0.18"), applies_condition="inter_region", sort_order=1)
            db.add_all([cgst, sgst, igst])
            await db.flush()
            print(f" Tax Group 'GST 18%' created (id={tg.id})")
        else:
            print(f" Tax Group found (id={tg.id})")

        # --- Product Categories ---
        result = await db.execute(select(Category).where(Category.org_id == org.id, Category.name == "Brass Fixtures"))
        brass_cat = result.scalar_one_or_none()
        if not brass_cat:
            brass_cat = Category(org_id=org.id, name="Brass Fixtures", description="Brass hardware and fixtures", sort_order=1)
            db.add(brass_cat)
            await db.flush()

        result = await db.execute(select(Category).where(Category.org_id == org.id, Category.name == "Glass Panels"))
        glass_cat = result.scalar_one_or_none()
        if not glass_cat:
            glass_cat = Category(org_id=org.id, name="Glass Panels", description="Glass and mirror panels", sort_order=2)
            db.add(glass_cat)
            await db.flush()

        # --- Products ---
        products_data = [
            ("Brass Door Handle Set", "BRS-001", brass_cat.id, "set", Decimal("850.00")),
            ("Brass Towel Rail 600mm", "BRS-002", brass_cat.id, "pcs", Decimal("2100.00")),
            ("Brass Curtain Rod 2M", "BRS-003", brass_cat.id, "pcs", Decimal("1250.00")),
            ("Brass Cabinet Knob", "BRS-004", brass_cat.id, "pcs", Decimal("450.00")),
            ("Brass Shelf Bracket Pair", "BRS-005", brass_cat.id, "pair", Decimal("680.00")),
            ("Clear Glass Panel 60x90cm", "GLS-001", glass_cat.id, "pcs", Decimal("3500.00")),
            ("Frosted Glass Panel 30x60cm", "GLS-002", glass_cat.id, "pcs", Decimal("1800.00")),
            ("Tempered Glass 90x120cm", "GLS-003", glass_cat.id, "pcs", Decimal("5200.00")),
            ("Mirror Glass 60x60cm", "GLS-004", glass_cat.id, "pcs", Decimal("2800.00")),
            ("Tinted Glass Panel 45x90cm", "GLS-005", glass_cat.id, "pcs", Decimal("4100.00")),
        ]

        for name, sku, cat_id, uom, price in products_data:
            result = await db.execute(select(Product).where(Product.org_id == org.id, Product.sku == sku))
            prod = result.scalar_one_or_none()
            if not prod:
                prod = Product(
                    org_id=org.id,
                    category_id=cat_id,
                    name=name,
                    sku=sku,
                    unit_of_measure=uom,
                    base_price=price,
                    tax_group_id=tg.id,
                    is_active=True
                )
                db.add(prod)
                await db.flush()

                # Branch Inventory
                inv = BranchInventory(
                    branch_id=branch.id,
                    product_id=prod.id,
                    quantity_on_hand=50 if "BRS" in sku else 20,
                    low_stock_threshold=10
                )
                db.add(inv)
            else:
                prod.base_price = price

        await db.flush()
        print(f" {len(products_data)} products seeded with inventory")

        # --- Printer Config ---
        result = await db.execute(select(PrinterConfig).where(PrinterConfig.branch_id == branch.id, PrinterConfig.name == "Main Printer"))
        printer = result.scalar_one_or_none()
        if not printer:
            printer = PrinterConfig(
                branch_id=branch.id,
                name="Main Printer",
                connection_type="bluetooth",
                paper_width_mm=80,
                is_default=True,
                is_active=True
            )
            db.add(printer)

        await db.commit()

    await engine.dispose()

    print("\n" + "=" * 50)
    print(" Database seeded successfully!")
    print("=" * 50)
    print("  API:      http://localhost:8000")
    print("  Docs:     http://localhost:8000/docs")
    print("  Email:    admin@faarpos.com")
    print("  Password: Admin@1234")
    print("  Branch:   FAAR Main Store (MAIN)")
    print("=" * 50)


if __name__ == "__main__":
    asyncio.run(seed())
