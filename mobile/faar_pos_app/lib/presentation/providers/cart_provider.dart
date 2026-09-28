import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/tax_entity.dart';
import '../../domain/services/tax_engine.dart';
import '../../core/config/app_config.dart';
import '../../data/local/app_database.dart';

class CartState {
  final List<CartItemEntity> items;
  final TaxCondition supplyCondition;
  final String currencySymbol;
  final Decimal? _cartDiscount;
  final String? selectedCustomerId;
  final String? customerName;
  final String? customerPhone;

  Decimal get cartDiscount => _cartDiscount ?? Decimal.zero;

  const CartState({
    this.items = const [],
    this.supplyCondition = TaxCondition.intraRegion,
    this.currencySymbol = AppConfig.defaultCurrencySymbol,
    Decimal? cartDiscount,
    this.selectedCustomerId,
    this.customerName,
    this.customerPhone,
  }) : _cartDiscount = cartDiscount;

  CartState copyWith({
    List<CartItemEntity>? items,
    TaxCondition? supplyCondition,
    String? currencySymbol,
    Decimal? cartDiscount,
    String? selectedCustomerId,
    String? customerName,
    String? customerPhone,
  }) =>
      CartState(
        items: items ?? this.items,
        supplyCondition: supplyCondition ?? this.supplyCondition,
        currencySymbol: currencySymbol ?? this.currencySymbol,
        cartDiscount: cartDiscount ?? this.cartDiscount,
        selectedCustomerId: selectedCustomerId ?? this.selectedCustomerId,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
      );
}

class CartNotifier extends Notifier<CartState> {
  int _nextLocalId = 1;

  // Default GST 18% fallback group
  final TaxGroupEntity _defaultGstGroup = TaxGroupEntity(
    id: 1,
    name: 'GST 18%',
    totalRateDecimal: Decimal.parse('18.00'),
    isCompound: false,
    components: [
      TaxComponentEntity(
        id: 1,
        name: 'CGST 9%',
        rateDecimal: Decimal.parse('9.00'),
        appliesToCondition: TaxCondition.intraRegion,
      ),
      TaxComponentEntity(
        id: 2,
        name: 'SGST 9%',
        rateDecimal: Decimal.parse('9.00'),
        appliesToCondition: TaxCondition.intraRegion,
      ),
      TaxComponentEntity(
        id: 3,
        name: 'IGST 18%',
        rateDecimal: Decimal.parse('18.00'),
        appliesToCondition: TaxCondition.interRegion,
      ),
    ],
  );

  TaxGroupEntity _getTaxGroupForId(int? taxGroupId) {
    if (taxGroupId != null && taxGroupId > 0) {
      try {
        final groups = AppDatabase.instance.getAllTaxGroups();
        final match = groups.where((g) => g.id == taxGroupId).firstOrNull;
        if (match != null) return match;
      } catch (_) {}
    }
    return _defaultGstGroup;
  }

  @override
  CartState build() => const CartState();

  void addItem(ProductEntity product) {
    final existingIndex = state.items.indexWhere((i) => i.productId == product.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      updateQuantity(existing.id, existing.quantity + 1);
    } else {
      final taxGroup = _getTaxGroupForId(product.taxGroupId);

      final lineResult = TaxEngine.calculateLineItem(
        unitPrice: product.basePriceDecimal,
        quantity: 1,
        taxGroup: taxGroup,
        supplyCondition: state.supplyCondition,
        isTaxInclusive: false,
      );

      final newItem = CartItemEntity(
        id: _nextLocalId++,
        productId: product.id,
        productName: product.name,
        sku: product.sku,
        taxGroupId: product.taxGroupId,
        quantity: 1,
        unitPriceDecimal: product.basePriceDecimal,
        discountDecimal: Decimal.zero,
        taxBreakdown: lineResult.taxBreakdown,
        lineTaxDecimal: lineResult.totalTaxAmount,
        lineTotalDecimal: lineResult.grandTotal,
      );

      state = state.copyWith(items: [...state.items, newItem]);
    }
  }

  void removeItem(int id) {
    state = state.copyWith(
      items: state.items.where((item) => item.id != id).toList(),
    );
  }

  void updateQuantity(int id, int qty) {
    if (qty <= 0) {
      removeItem(id);
      return;
    }

    final updated = state.items.map((item) {
      if (item.id != id) return item;

      final taxGroup = _getTaxGroupForId(item.taxGroupId);

      final lineResult = TaxEngine.calculateLineItem(
        unitPrice: item.unitPriceDecimal,
        quantity: qty,
        discountAmount: item.discountDecimal,
        taxGroup: taxGroup,
        supplyCondition: state.supplyCondition,
        isTaxInclusive: false,
      );

      return item.copyWith(
        quantity: qty,
        taxBreakdown: lineResult.taxBreakdown,
        lineTaxDecimal: lineResult.totalTaxAmount,
        lineTotalDecimal: lineResult.grandTotal,
      );
    }).toList();

    state = state.copyWith(items: updated);
  }

  void applyLineDiscount(int id, Decimal discountAmount) {
    final updated = state.items.map((item) {
      if (item.id != id) return item;

      final taxGroup = _getTaxGroupForId(item.taxGroupId);

      final lineResult = TaxEngine.calculateLineItem(
        unitPrice: item.unitPriceDecimal,
        quantity: item.quantity,
        discountAmount: discountAmount,
        taxGroup: taxGroup,
        supplyCondition: state.supplyCondition,
        isTaxInclusive: false,
      );

      return item.copyWith(
        discountDecimal: discountAmount,
        taxBreakdown: lineResult.taxBreakdown,
        lineTaxDecimal: lineResult.totalTaxAmount,
        lineTotalDecimal: lineResult.grandTotal,
      );
    }).toList();

    state = state.copyWith(items: updated);
  }

  void setSupplyCondition(TaxCondition condition) {
    if (state.supplyCondition == condition) return;

    // Recalculate all line items with the new regional tax condition
    final recalculated = state.items.map((item) {
      final taxGroup = _getTaxGroupForId(item.taxGroupId);

      final lineResult = TaxEngine.calculateLineItem(
        unitPrice: item.unitPriceDecimal,
        quantity: item.quantity,
        discountAmount: item.discountDecimal,
        taxGroup: taxGroup,
        supplyCondition: condition,
        isTaxInclusive: false,
      );

      return item.copyWith(
        taxBreakdown: lineResult.taxBreakdown,
        lineTaxDecimal: lineResult.totalTaxAmount,
        lineTotalDecimal: lineResult.grandTotal,
      );
    }).toList();

    state = state.copyWith(
      supplyCondition: condition,
      items: recalculated,
    );
  }

  void setCustomer({String? id, String? name, String? phone}) {
    state = state.copyWith(
      selectedCustomerId: id,
      customerName: name,
      customerPhone: phone,
    );
  }

  void clearCart() {
    state = const CartState();
  }
}

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).items.length;
});

final cartSubtotalProvider = Provider<Decimal>((ref) {
  final items = ref.watch(cartProvider).items;
  return items.fold(
    Decimal.zero,
    (sum, item) => sum + (item.unitPriceDecimal * Decimal.fromInt(item.quantity)),
  );
});

final cartDiscountTotalProvider = Provider<Decimal>((ref) {
  final items = ref.watch(cartProvider).items;
  return items.fold(
    Decimal.zero,
    (sum, item) => sum + item.discountDecimal,
  );
});

final cartTaxTotalProvider = Provider<Decimal>((ref) {
  final items = ref.watch(cartProvider).items;
  return items.fold(
    Decimal.zero,
    (sum, item) => sum + item.lineTaxDecimal,
  );
});

final cartGrandTotalProvider = Provider<Decimal>((ref) {
  final items = ref.watch(cartProvider).items;
  return items.fold(
    Decimal.zero,
    (sum, item) => sum + item.lineTotalDecimal,
  );
});

final cartAggregatedTaxBreakdownProvider = Provider<List<TaxLineItem>>((ref) {
  final items = ref.watch(cartProvider).items;
  final breakdowns = items.map((i) => i.taxBreakdown).toList();
  return TaxEngine.aggregateTaxBreakdowns(breakdowns);
});
