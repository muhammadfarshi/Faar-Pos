from pydantic import BaseModel
from typing import List
from decimal import Decimal
from datetime import date

class EODReportResponse(BaseModel):
    date: date
    branch_id: int
    total_sales: Decimal
    total_refunds: Decimal
    net_revenue: Decimal
    total_tax: Decimal
    transaction_count: int

class SalesReportResponse(BaseModel):
    total_revenue: Decimal
    total_tax: Decimal
    total_transactions: int
    sales_by_payment_method: dict

class BranchComparisonResponse(BaseModel):
    branch_id: int
    branch_name: str
    revenue: Decimal
    transactions: int

class ReorderSuggestionResponse(BaseModel):
    product_id: int
    product_name: str
    current_stock: int
    threshold: int
    suggested_order_qty: int
