"""
Auth endpoints:
  POST /auth/login    → returns access_token, refresh_token, user info, branch info
  POST /auth/refresh  → returns new access_token
  POST /auth/logout   → invalidates refresh token
  GET  /auth/me       → current user profile with branch info
"""
from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from sqlalchemy.orm import selectinload

from app.core.database import get_db
from app.core.security import (
    verify_password,
    create_access_token,
    create_refresh_token,
    get_current_user,
)
from app.schemas.auth import LoginRequest, TokenResponse, RefreshRequest
from app.schemas.user import UserResponse
from app.models.user import User
from app.models.branch import Branch

router = APIRouter()


@router.post("/login", response_model=dict)
async def login(req: LoginRequest, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(User).where(User.email == req.email))
    user: User | None = result.scalar_one_or_none()

    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is deactivated",
        )

    access_token = create_access_token(
        data={"sub": str(user.id), "role": user.role, "org_id": user.org_id}
    )
    refresh_token, hashed_rt, rt_exp = create_refresh_token()

    user.refresh_token_hash = hashed_rt
    user.refresh_token_expires_at = rt_exp
    user.last_login_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(user)

    # Fetch branch info if assigned
    branch_data = None
    if user.branch_id:
        branch_res = await db.execute(
            select(Branch).where(Branch.id == user.branch_id)
        )
        branch: Branch | None = branch_res.scalar_one_or_none()
        if branch:
            branch_data = {
                "id": branch.id,
                "org_id": branch.org_id,
                "name": branch.name,
                "branch_code": branch.branch_code,
                "invoice_prefix": branch.invoice_prefix,
                "currency_code": "USD",   # from org in production
                "currency_symbol": "$",   # from org in production
                "tax_registration_no": getattr(branch, 'tax_registration_no', None),
                "country_code": branch.country_code,
                "city": branch.city,
                "is_active": branch.is_active,
            }

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "refresh_token": refresh_token,
        "user": {
            "id": user.id,
            "org_id": user.org_id,
            "branch_id": user.branch_id,
            "email": user.email,
            "full_name": user.full_name,
            "role": user.role,
            "is_active": user.is_active,
        },
        "branch": branch_data,
    }


@router.post("/refresh", response_model=dict)
async def refresh_token(req: RefreshRequest, db: AsyncSession = Depends(get_db)):
    """Refresh access token using a valid refresh token."""
    from app.core.security import verify_password as verify_rt

    result = await db.execute(
        select(User).where(User.is_active == True)
    )
    users = result.scalars().all()

    matched_user: User | None = None
    for u in users:
        if (
            u.refresh_token_hash
            and u.refresh_token_expires_at
            and u.refresh_token_expires_at > datetime.now(timezone.utc)
            and verify_rt(req.refresh_token, u.refresh_token_hash)
        ):
            matched_user = u
            break

    if not matched_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )

    new_access_token = create_access_token(
        data={
            "sub": str(matched_user.id),
            "role": matched_user.role,
            "org_id": matched_user.org_id,
        }
    )
    return {"access_token": new_access_token, "token_type": "bearer"}


@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    current_user.refresh_token_hash = None
    current_user.refresh_token_expires_at = None
    current_user.token_version = (current_user.token_version or 0) + 1
    await db.commit()
    return {"message": "Logged out successfully"}


@router.get("/me", response_model=dict)
async def read_me(current_user: User = Depends(get_current_user)):
    return {
        "id": current_user.id,
        "org_id": current_user.org_id,
        "branch_id": current_user.branch_id,
        "email": current_user.email,
        "full_name": current_user.full_name,
        "role": current_user.role,
        "is_active": current_user.is_active,
    }
