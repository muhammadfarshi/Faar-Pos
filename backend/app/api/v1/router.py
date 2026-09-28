from fastapi import APIRouter
from app.api.v1.endpoints import auth, organizations, users, products, taxes, transactions, inventory, reports, printers

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(organizations.router, prefix="/organizations", tags=["organizations"])
api_router.include_router(users.router, prefix="/users", tags=["users"])
api_router.include_router(products.router, prefix="/products", tags=["products"])
api_router.include_router(taxes.router, prefix="/taxes", tags=["taxes"])
api_router.include_router(transactions.router, prefix="/transactions", tags=["transactions"])
api_router.include_router(inventory.router, prefix="/inventory", tags=["inventory"])
api_router.include_router(reports.router, prefix="/reports", tags=["reports"])
api_router.include_router(printers.router, prefix="/printers", tags=["printers"])
