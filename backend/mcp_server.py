# FAAR POS — Admin Analytics MCP Server
# Read-only PostgreSQL access via Model Context Protocol
# Usage: python mcp_server.py
# Then query via: Google AI Studio, Claude Desktop, or any MCP client

import asyncio
import json
from decimal import Decimal
from datetime import datetime, date
from typing import Any
import asyncpg
import os
from mcp.server import Server
from mcp.server.stdio import stdio_server
from mcp.types import Tool, TextContent

# ── Config ──────────────────────────────────────────────────────────────────
DATABASE_URL = os.environ.get("DATABASE_URL")
# NOTE: Use read-only DB credentials here — never the main app credentials
# Create a read-only PostgreSQL role:
#   CREATE ROLE faar_readonly WITH LOGIN PASSWORD 'readonly_pass';
#   GRANT CONNECT ON DATABASE faar_pos TO faar_readonly;
#   GRANT USAGE ON SCHEMA public TO faar_readonly;
#   GRANT SELECT ON ALL TABLES IN SCHEMA public TO faar_readonly;

app = Server("faar-pos-analytics")
_pool: asyncpg.Pool | None = None


def _json_serial(obj: Any) -> Any:
    """JSON serializer for objects not serializable by default json code."""
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return str(obj)
    raise TypeError(f"Type {type(obj)} not serializable")


async def get_pool() -> asyncpg.Pool:
    global _pool
    if _pool is None:
        _pool = await asyncpg.create_pool(DATABASE_URL, min_size=1, max_size=5)
    return _pool


async def query(sql: str, *args) -> list[dict]:
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch(sql, *args)
        return [dict(r) for r in rows]


# ── Tool Definitions ─────────────────────────────────────────────────────────

@app.list_tools()
async def list_tools() -> list[Tool]:
    return [
        Tool(
            name="get_sales_summary",
            description="Get sales summary for a branch or all branches. Filters by date range.",
            inputSchema={
                "type": "object",
                "properties": {
                    "start_date": {"type": "string", "format": "date", "description": "Start date YYYY-MM-DD"},
                    "end_date": {"type": "string", "format": "date", "description": "End date YYYY-MM-DD"},
                    "branch_code": {"type": "string", "description": "Optional branch code filter"},
                    "org_slug": {"type": "string", "description": "Organization slug"},
                },
                "required": ["start_date", "end_date", "org_slug"],
            },
        ),
        Tool(
            name="get_top_products",
            description="Get top selling products by revenue or quantity for a given period.",
            inputSchema={
                "type": "object",
                "properties": {
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                    "org_slug": {"type": "string"},
                    "branch_code": {"type": "string"},
                    "limit": {"type": "integer", "default": 10},
                    "order_by": {"type": "string", "enum": ["revenue", "quantity"], "default": "revenue"},
                },
                "required": ["start_date", "end_date", "org_slug"],
            },
        ),
        Tool(
            name="get_inventory_status",
            description="Get current inventory levels across branches, optionally filtered by low stock.",
            inputSchema={
                "type": "object",
                "properties": {
                    "org_slug": {"type": "string"},
                    "branch_code": {"type": "string"},
                    "low_stock_only": {"type": "boolean", "default": False},
                },
                "required": ["org_slug"],
            },
        ),
        Tool(
            name="get_reorder_suggestions",
            description="Analyze inventory velocity vs stock levels to suggest reorder quantities and timing.",
            inputSchema={
                "type": "object",
                "properties": {
                    "org_slug": {"type": "string"},
                    "branch_code": {"type": "string"},
                    "lookback_days": {"type": "integer", "default": 30, "description": "Days to analyze sales velocity"},
                },
                "required": ["org_slug"],
            },
        ),
        Tool(
            name="get_branch_comparison",
            description="Compare performance metrics across all branches of an organization.",
            inputSchema={
                "type": "object",
                "properties": {
                    "org_slug": {"type": "string"},
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                },
                "required": ["org_slug", "start_date", "end_date"],
            },
        ),
        Tool(
            name="get_tax_collected",
            description="Get tax collected breakdown by tax component across a date range.",
            inputSchema={
                "type": "object",
                "properties": {
                    "org_slug": {"type": "string"},
                    "branch_code": {"type": "string"},
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                },
                "required": ["org_slug", "start_date", "end_date"],
            },
        ),
        Tool(
            name="get_inventory_movement",
            description="Get inventory movement log for a product or all products in a date range.",
            inputSchema={
                "type": "object",
                "properties": {
                    "org_slug": {"type": "string"},
                    "branch_code": {"type": "string"},
                    "product_sku": {"type": "string"},
                    "start_date": {"type": "string", "format": "date"},
                    "end_date": {"type": "string", "format": "date"},
                    "movement_type": {"type": "string", "enum": ["sale", "restock", "damage", "adjustment", "all"], "default": "all"},
                },
                "required": ["org_slug"],
            },
        ),
    ]


@app.call_tool()
async def call_tool(name: str, arguments: dict) -> list[TextContent]:
    try:
        result = await _dispatch(name, arguments)
        return [TextContent(type="text", text=json.dumps(result, default=_json_serial, indent=2))]
    except Exception as e:
        return [TextContent(type="text", text=f"Error: {str(e)}")]


async def _dispatch(name: str, args: dict) -> Any:
    if name == "get_sales_summary":
        return await _get_sales_summary(args)
    elif name == "get_top_products":
        return await _get_top_products(args)
    elif name == "get_inventory_status":
        return await _get_inventory_status(args)
    elif name == "get_reorder_suggestions":
        return await _get_reorder_suggestions(args)
    elif name == "get_branch_comparison":
        return await _get_branch_comparison(args)
    elif name == "get_tax_collected":
        return await _get_tax_collected(args)
    elif name == "get_inventory_movement":
        return await _get_inventory_movement(args)
    else:
        raise ValueError(f"Unknown tool: {name}")


async def _get_sales_summary(args: dict) -> dict:
    branch_filter = "AND b.branch_code = $4" if args.get("branch_code") else ""
    params = [args["org_slug"], args["start_date"], args["end_date"]]
    if args.get("branch_code"):
        params.append(args["branch_code"])

    rows = await query(f"""
        SELECT
            b.branch_code,
            b.name AS branch_name,
            COUNT(t.id) AS transaction_count,
            SUM(t.grand_total) AS total_revenue,
            SUM(t.total_tax_amount) AS total_tax,
            SUM(t.total_base_amount) AS total_base,
            AVG(t.grand_total) AS avg_order_value,
            COUNT(CASE WHEN t.status = 'voided' THEN 1 END) AS voided_count,
            SUM(CASE WHEN t.payment_method = 'cash' THEN t.grand_total ELSE 0 END) AS cash_sales,
            SUM(CASE WHEN t.payment_method = 'card' THEN t.grand_total ELSE 0 END) AS card_sales,
            SUM(CASE WHEN t.payment_method = 'upi' THEN t.grand_total ELSE 0 END) AS upi_sales
        FROM transactions t
        JOIN branches b ON t.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id
        WHERE o.slug = $1
          AND t.created_at::date BETWEEN $2 AND $3
          AND t.status != 'voided'
          AND t.deleted_at IS NULL
          {branch_filter}
        GROUP BY b.branch_code, b.name
        ORDER BY total_revenue DESC NULLS LAST
    """, *params)

    return {
        "period": {"start": args["start_date"], "end": args["end_date"]},
        "branches": rows,
        "totals": {
            "revenue": sum(Decimal(str(r["total_revenue"] or 0)) for r in rows),
            "tax": sum(Decimal(str(r["total_tax"] or 0)) for r in rows),
            "transactions": sum(r["transaction_count"] or 0 for r in rows),
        },
    }


async def _get_top_products(args: dict) -> list[dict]:
    branch_filter = "AND b.branch_code = $5" if args.get("branch_code") else ""
    order_col = "SUM(ti.quantity)" if args.get("order_by") == "quantity" else "SUM(ti.line_total)"
    params = [args["org_slug"], args["start_date"], args["end_date"], args.get("limit", 10)]
    if args.get("branch_code"):
        params.append(args["branch_code"])

    return await query(f"""
        SELECT
            p.sku,
            ti.product_name_snapshot AS name,
            SUM(ti.quantity) AS total_units_sold,
            SUM(ti.line_total) AS total_revenue,
            SUM(ti.tax_total) AS total_tax,
            COUNT(DISTINCT t.id) AS transaction_count
        FROM transaction_items ti
        JOIN transactions t ON ti.transaction_id = t.id
        JOIN branches b ON t.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id
        JOIN products p ON ti.product_id = p.id
        WHERE o.slug = $1
          AND t.created_at::date BETWEEN $2 AND $3
          AND t.status != 'voided'
          AND t.deleted_at IS NULL
          {branch_filter}
        GROUP BY p.sku, ti.product_name_snapshot
        ORDER BY {order_col} DESC NULLS LAST
        LIMIT $4
    """, *params)


async def _get_inventory_status(args: dict) -> list[dict]:
    low_stock_filter = "AND bi.quantity_on_hand <= bi.low_stock_threshold" if args.get("low_stock_only") else ""
    branch_filter = "AND b.branch_code = $2" if args.get("branch_code") else ""
    params = [args["org_slug"]]
    if args.get("branch_code"):
        params.append(args["branch_code"])

    return await query(f"""
        SELECT
            b.branch_code,
            b.name AS branch_name,
            p.sku,
            p.name AS product_name,
            bi.quantity_on_hand,
            bi.low_stock_threshold,
            CASE
                WHEN bi.quantity_on_hand <= 0 THEN 'out_of_stock'
                WHEN bi.quantity_on_hand <= bi.low_stock_threshold THEN 'low_stock'
                ELSE 'in_stock'
            END AS stock_status,
            p.base_price
        FROM branch_inventories bi
        JOIN branches b ON bi.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id
        JOIN products p ON bi.product_id = p.id
        WHERE o.slug = $1
          AND p.deleted_at IS NULL
          AND b.deleted_at IS NULL
          {branch_filter}
          {low_stock_filter}
        ORDER BY bi.quantity_on_hand ASC, p.name
    """, *params)


async def _get_reorder_suggestions(args: dict) -> list[dict]:
    lookback = args.get("lookback_days", 30)
    branch_filter = "AND b.branch_code = $3" if args.get("branch_code") else ""
    params = [args["org_slug"], lookback]
    if args.get("branch_code"):
        params.append(args["branch_code"])

    return await query(f"""
        WITH sales_velocity AS (
            SELECT
                ti.product_id,
                t.branch_id,
                SUM(ti.quantity) AS units_sold,
                COUNT(DISTINCT t.created_at::date) AS active_days,
                SUM(ti.quantity)::decimal / NULLIF($2, 0) AS daily_velocity
            FROM transaction_items ti
            JOIN transactions t ON ti.transaction_id = t.id
            JOIN branches b ON t.branch_id = b.id
            JOIN organizations o ON b.org_id = o.id
            WHERE o.slug = $1
              AND t.created_at >= NOW() - ($2 || ' days')::interval
              AND t.status != 'voided'
              {branch_filter}
            GROUP BY ti.product_id, t.branch_id
        )
        SELECT
            b.branch_code,
            p.sku,
            p.name AS product_name,
            bi.quantity_on_hand AS current_stock,
            bi.low_stock_threshold,
            COALESCE(sv.daily_velocity, 0) AS daily_sales_velocity,
            CASE
                WHEN COALESCE(sv.daily_velocity, 0) > 0
                THEN (bi.quantity_on_hand / sv.daily_velocity)::integer
                ELSE NULL
            END AS days_of_stock_remaining,
            CASE
                WHEN COALESCE(sv.daily_velocity, 0) > 0
                  AND bi.quantity_on_hand / sv.daily_velocity < 7
                THEN 'URGENT'
                WHEN COALESCE(sv.daily_velocity, 0) > 0
                  AND bi.quantity_on_hand / sv.daily_velocity < 14
                THEN 'SOON'
                ELSE 'OK'
            END AS reorder_urgency,
            GREATEST(0, (sv.daily_velocity * 30 - bi.quantity_on_hand)::integer) AS suggested_reorder_qty
        FROM branch_inventories bi
        JOIN branches b ON bi.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id
        JOIN products p ON bi.product_id = p.id
        LEFT JOIN sales_velocity sv ON sv.product_id = bi.product_id AND sv.branch_id = bi.branch_id
        WHERE o.slug = $1
          AND p.deleted_at IS NULL
          AND b.deleted_at IS NULL
          {branch_filter}
        ORDER BY
            CASE reorder_urgency WHEN 'URGENT' THEN 1 WHEN 'SOON' THEN 2 ELSE 3 END,
            days_of_stock_remaining NULLS LAST
    """, *params)


async def _get_branch_comparison(args: dict) -> list[dict]:
    return await query("""
        SELECT
            b.branch_code,
            b.name AS branch_name,
            b.city,
            b.country_code,
            COUNT(t.id) AS transactions,
            COALESCE(SUM(t.grand_total), 0) AS revenue,
            COALESCE(SUM(t.total_tax_amount), 0) AS tax_collected,
            COALESCE(AVG(t.grand_total), 0) AS avg_order_value,
            COUNT(DISTINCT t.cashier_id) AS active_cashiers
        FROM branches b
        JOIN organizations o ON b.org_id = o.id
        LEFT JOIN transactions t ON t.branch_id = b.id
            AND t.created_at::date BETWEEN $2 AND $3
            AND t.status != 'voided'
            AND t.deleted_at IS NULL
        WHERE o.slug = $1
          AND b.deleted_at IS NULL
        GROUP BY b.branch_code, b.name, b.city, b.country_code
        ORDER BY revenue DESC NULLS LAST
    """, args["org_slug"], args["start_date"], args["end_date"])


async def _get_tax_collected(args: dict) -> dict:
    branch_filter = "AND b.branch_code = $4" if args.get("branch_code") else ""
    params = [args["org_slug"], args["start_date"], args["end_date"]]
    if args.get("branch_code"):
        params.append(args["branch_code"])

    # Explode JSONB tax_breakdown array to get per-component totals
    rows = await query(f"""
        SELECT
            b.branch_code,
            tax_component->>'name' AS tax_name,
            SUM((tax_component->>'amount')::decimal) AS total_collected
        FROM transactions t
        JOIN transaction_items ti ON ti.transaction_id = t.id
        JOIN branches b ON t.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id,
        LATERAL jsonb_array_elements(ti.tax_breakdown) AS tax_component
        WHERE o.slug = $1
          AND t.created_at::date BETWEEN $2 AND $3
          AND t.status != 'voided'
          AND t.deleted_at IS NULL
          {branch_filter}
        GROUP BY b.branch_code, tax_component->>'name'
        ORDER BY b.branch_code, total_collected DESC
    """, *params)

    return {"period": {"start": args["start_date"], "end": args["end_date"]}, "tax_breakdown": rows}


async def _get_inventory_movement(args: dict) -> list[dict]:
    filters = ["o.slug = $1"]
    params: list[Any] = [args["org_slug"]]

    if args.get("branch_code"):
        params.append(args["branch_code"])
        filters.append(f"b.branch_code = ${len(params)}")

    if args.get("product_sku"):
        params.append(args["product_sku"])
        filters.append(f"p.sku = ${len(params)}")

    if args.get("start_date"):
        params.append(args["start_date"])
        filters.append(f"il.created_at::date >= ${len(params)}")

    if args.get("end_date"):
        params.append(args["end_date"])
        filters.append(f"il.created_at::date <= ${len(params)}")

    if args.get("movement_type") and args["movement_type"] != "all":
        params.append(args["movement_type"])
        filters.append(f"il.movement_type = ${len(params)}")

    where_clause = " AND ".join(filters)

    return await query(f"""
        SELECT
            il.created_at,
            b.branch_code,
            p.sku,
            p.name AS product_name,
            il.movement_type,
            il.quantity_delta,
            il.quantity_after,
            il.notes,
            u.full_name AS performed_by
        FROM inventory_logs il
        JOIN branches b ON il.branch_id = b.id
        JOIN organizations o ON b.org_id = o.id
        JOIN products p ON il.product_id = p.id
        JOIN users u ON il.user_id = u.id
        WHERE {where_clause}
        ORDER BY il.created_at DESC
        LIMIT 500
    """, *params)


# ── Entry Point ──────────────────────────────────────────────────────────────
async def main():
    if not DATABASE_URL:
        raise ValueError("DATABASE_URL environment variable is required (use read-only credentials!)")
    async with stdio_server() as (read_stream, write_stream):
        await app.run(read_stream, write_stream, app.create_initialization_options())


if __name__ == "__main__":
    asyncio.run(main())
