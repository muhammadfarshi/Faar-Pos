from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select

from app.core.database import get_db
from app.core.security import get_current_user, require_role
from app.models.organization import Organization
from app.models.branch import Branch
from app.models.user import User
from app.schemas.organization import OrgCreate, OrgResponse, BranchCreate, BranchResponse

router = APIRouter()

@router.post("/", response_model=OrgResponse)
async def create_organization(org_in: OrgCreate, db: AsyncSession = Depends(get_db)):
    # In a real system, you might restrict who can create orgs
    org = Organization(**org_in.model_dump())
    db.add(org)
    await db.commit()
    await db.refresh(org)
    return org

@router.get("/", response_model=list[OrgResponse])
async def list_organizations(db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(Organization))
    return result.scalars().all()

@router.post("/{org_id}/branches", response_model=BranchResponse, dependencies=[Depends(require_role("org_admin"))])
async def create_branch(org_id: int, branch_in: BranchCreate, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.org_id != org_id:
        raise HTTPException(status_code=403, detail="Not authorized for this org")
    
    branch = Branch(**branch_in.model_dump(), org_id=org_id)
    db.add(branch)
    await db.commit()
    await db.refresh(branch)
    return branch

@router.get("/{org_id}/branches", response_model=list[BranchResponse])
async def list_branches(org_id: int, db: AsyncSession = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.org_id != org_id:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    result = await db.execute(select(Branch).where(Branch.org_id == org_id))
    return result.scalars().all()
