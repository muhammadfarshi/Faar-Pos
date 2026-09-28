"""
FAAR POS Tax Calculation Engine
================================
Multi-country, multi-component tax calculator using strict Decimal arithmetic.
NEVER uses float — all calculations use Python's decimal.Decimal with ROUND_HALF_UP.

Supports:
- Simple tax (e.g., UK VAT 20% = always)
- Split tax (e.g., India GST 18% intra-state = CGST 9% + SGST 9%)
- Inter-state tax (e.g., India IGST 18%)
- Compound tax (tax on tax, e.g., some Canadian taxes)
- Any country's tax structure via TaxGroup + TaxComponent configuration
"""

from decimal import Decimal, ROUND_HALF_UP
from dataclasses import dataclass, field
from typing import Optional


TWO_PLACES = Decimal('0.01')
FOUR_PLACES = Decimal('0.0001')


def _quantize(value: Decimal, places: Decimal = TWO_PLACES) -> Decimal:
    """Round a Decimal value using ROUND_HALF_UP to the specified precision."""
    return value.quantize(places, rounding=ROUND_HALF_UP)


@dataclass(frozen=True)
class TaxComponentInput:
    """Input: a single tax component from the database."""
    name: str                    # e.g., "CGST", "SGST", "IGST", "VAT", "Sales Tax"
    rate: Decimal                # e.g., Decimal('0.0900') for 9%
    applies_condition: str       # 'always' | 'intra_region' | 'inter_region'
    sort_order: int = 0


@dataclass(frozen=True)
class TaxLineResult:
    """Result: a single calculated tax line."""
    name: str
    rate: Decimal                # e.g., Decimal('0.0900')
    rate_percent: Decimal        # e.g., Decimal('9.00') for display
    amount: Decimal              # e.g., Decimal('9.00') — always 2dp
    applies_condition: str


@dataclass
class TaxCalculationResult:
    """Full result of a tax calculation for one line item."""
    base_amount: Decimal         # (unit_price × quantity) − discount
    tax_lines: list[TaxLineResult] = field(default_factory=list)
    total_tax: Decimal = Decimal('0')
    line_total: Decimal = Decimal('0')   # base + total_tax
    is_compound: bool = False


class TaxCalculationService:
    """
    Production tax calculation service for FAAR POS.
    
    Usage:
        service = TaxCalculationService()
        result = service.calculate(
            unit_price=Decimal('100.00'),
            quantity=2,
            discount=Decimal('0'),
            tax_components=[
                TaxComponentInput('CGST', Decimal('0.09'), 'intra_region'),
                TaxComponentInput('SGST', Decimal('0.09'), 'intra_region'),
                TaxComponentInput('IGST', Decimal('0.18'), 'inter_region'),
            ],
            supply_region_type='intra_region',
            is_compound=False,
        )
    """

    def calculate(
        self,
        unit_price: Decimal,
        quantity: int,
        discount: Decimal,
        tax_components: list[TaxComponentInput],
        supply_region_type: Optional[str],  # 'intra_region' | 'inter_region' | None
        is_compound: bool = False,
    ) -> TaxCalculationResult:
        """
        Calculate tax breakdown for a single line item.

        Args:
            unit_price: Price per unit (Decimal, no float!)
            quantity: Integer quantity
            discount: Total discount on the line (Decimal)
            tax_components: All components from TaxGroup, ordered by sort_order
            supply_region_type: 'intra_region', 'inter_region', or None (= 'always' only)
            is_compound: If True, each component applies to (base + previously calculated taxes)

        Returns:
            TaxCalculationResult with full breakdown
        """
        # Validate types — refuse float silently
        if not isinstance(unit_price, Decimal):
            unit_price = Decimal(str(unit_price))
        if not isinstance(discount, Decimal):
            discount = Decimal(str(discount))

        base_amount = _quantize(unit_price * Decimal(quantity) - discount)

        # Filter components applicable to the supply type
        applicable = self._filter_components(tax_components, supply_region_type)

        tax_lines: list[TaxLineResult] = []
        accumulated_tax = Decimal('0')

        for component in sorted(applicable, key=lambda c: c.sort_order):
            if is_compound:
                # Compound: applies to base + taxes already calculated above
                taxable_base = base_amount + accumulated_tax
            else:
                # Simple: always applies to the pre-tax base
                taxable_base = base_amount

            raw_amount = taxable_base * component.rate
            amount = _quantize(raw_amount)

            tax_lines.append(TaxLineResult(
                name=component.name,
                rate=component.rate,
                rate_percent=_quantize(component.rate * Decimal('100')),
                amount=amount,
                applies_condition=component.applies_condition,
            ))
            accumulated_tax += amount

        total_tax = _quantize(accumulated_tax)
        line_total = _quantize(base_amount + total_tax)

        return TaxCalculationResult(
            base_amount=base_amount,
            tax_lines=tax_lines,
            total_tax=total_tax,
            line_total=line_total,
            is_compound=is_compound,
        )

    def _filter_components(
        self,
        components: list[TaxComponentInput],
        supply_region_type: Optional[str],
    ) -> list[TaxComponentInput]:
        """Return only components that apply given the supply region type."""
        result = []
        for comp in components:
            if comp.applies_condition == 'always':
                result.append(comp)
            elif comp.applies_condition == 'intra_region' and supply_region_type == 'intra_region':
                result.append(comp)
            elif comp.applies_condition == 'inter_region' and supply_region_type == 'inter_region':
                result.append(comp)
            # If supply_region_type is None, only 'always' components apply
        return result

    def calculate_transaction_totals(
        self,
        line_results: list[TaxCalculationResult],
    ) -> dict:
        """
        Aggregate multiple line item results into transaction-level totals.
        
        Returns:
            {
                'total_base_amount': Decimal,
                'total_tax_amount': Decimal,
                'total_discount_amount': Decimal,
                'grand_total': Decimal,
                'tax_component_totals': {'CGST': Decimal, 'VAT': Decimal, ...}
            }
        """
        total_base = _quantize(sum(r.base_amount for r in line_results))
        total_tax = _quantize(sum(r.total_tax for r in line_results))
        grand_total = _quantize(total_base + total_tax)

        # Aggregate by component name across all lines
        component_totals: dict[str, Decimal] = {}
        for result in line_results:
            for line in result.tax_lines:
                existing = component_totals.get(line.name, Decimal('0'))
                component_totals[line.name] = _quantize(existing + line.amount)

        return {
            'total_base_amount': total_base,
            'total_tax_amount': total_tax,
            'grand_total': grand_total,
            'tax_component_totals': component_totals,
        }

    def serialize_tax_breakdown(self, result: TaxCalculationResult) -> list[dict]:
        """
        Convert TaxCalculationResult to JSONB-compatible list for storage in transaction_items.
        
        Format: [{"name": "CGST", "rate": "0.0900", "rate_percent": "9.00", "amount": "9.00"}, ...]
        All values stored as strings to avoid float serialization issues.
        """
        return [
            {
                "name": line.name,
                "rate": str(line.rate),
                "rate_percent": str(line.rate_percent),
                "amount": str(line.amount),
                "applies_condition": line.applies_condition,
            }
            for line in result.tax_lines
        ]


# ── Module-level singleton ───────────────────────────────────────────────────
tax_engine = TaxCalculationService()
