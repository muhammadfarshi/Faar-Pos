from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user
from app.models.product import Category, Product
from app.models.user import User
from app.schemas.product import CategoryCreate, CategoryResponse, ProductCreate, ProductResponse

router = APIRouter()

@router.post("/categories", response_model=CategoryResponse)
async def create_category(cat_in: CategoryCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    cat = Category(**cat_in.model_dump(), org_id=current_user.org_id)
    db.add(cat)
    await db.commit()
    await db.refresh(cat)
    return cat

@router.get("/categories", response_model=list[CategoryResponse])
async def list_categories(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Category).where(Category.org_id == current_user.org_id))
    return result.scalars().all()

@router.post("/", response_model=ProductResponse)
async def create_product(prod_in: ProductCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    prod = Product(**prod_in.model_dump(), org_id=current_user.org_id)
    db.add(prod)
    await db.commit()
    await db.refresh(prod)
    return prod

@router.get("/", response_model=list[ProductResponse])
async def list_products(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    result = await db.execute(select(Product).where(Product.org_id == current_user.org_id))
    return result.scalars().all()
