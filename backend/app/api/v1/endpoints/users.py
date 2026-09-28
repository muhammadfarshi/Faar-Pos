from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user, require_role, hash_password
from app.models.user import User
from app.schemas.user import UserCreate, UserResponse

router = APIRouter()

@router.post("/", response_model=UserResponse, dependencies=[Depends(require_role("org_admin", "branch_admin"))])
async def create_user(user_in: UserCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Check if user exists
    result = await db.execute(select(User).where(User.email == user_in.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email already registered")
        
    new_user = User(
        org_id=current_user.org_id,
        branch_id=user_in.branch_id,
        email=user_in.email,
        hashed_password=hash_password(user_in.password),
        full_name=user_in.full_name,
        role=user_in.role
    )
    db.add(new_user)
    await db.commit()
    await db.refresh(new_user)
    return new_user

@router.get("/", response_model=list[UserResponse])
async def list_users(db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    query = select(User).where(User.org_id == current_user.org_id)
    if current_user.role in ["branch_admin", "manager"]:
        query = query.where(User.branch_id == current_user.branch_id)
        
    result = await db.execute(query)
    return result.scalars().all()
