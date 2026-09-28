import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/entities/session_entity.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/entities/branch_entity.dart';


/// Simple in-memory + SharedPreferences local store for MVP.
/// Replace with Drift after running build_runner.
class LocalStore {
  static LocalStore? _instance;
  static LocalStore get instance => _instance ??= LocalStore._();
  LocalStore._();

  // In-memory state
  final List<ProductEntity> _products = [];
  final List<CartItemEntity> _cartItems = [];
  SessionEntity? _session;
  int _nextCartId = 1;

  // ─── Products ──────────────────────────────────────────────────────────────
  List<ProductEntity> get products => List.unmodifiable(_products);

  List<ProductEntity> searchProducts(String query) {
    if (query.isEmpty) return products;
    final q = query.toLowerCase();
    return _products.where((p) =>
      p.name.toLowerCase().contains(q) ||
      p.sku.toLowerCase().contains(q) ||
      (p.barcode?.contains(q) ?? false)
    ).toList();
  }

  void setProducts(List<ProductEntity> products) {
    _products
      ..clear()
      ..addAll(products);
  }

  // ─── Cart ──────────────────────────────────────────────────────────────────
  List<CartItemEntity> get cartItems => List.unmodifiable(_cartItems);

  void addCartItem(CartItemEntity item) {
    // If same product exists, increment qty
    final idx = _cartItems.indexWhere((c) => c.productId == item.productId);
    if (idx >= 0) {
      final existing = _cartItems[idx];
      final newQty = existing.quantity + 1;
      final newTotal = existing.unitPriceDecimal * Decimal.parse(newQty.toString());
      _cartItems[idx] = CartItemEntity(
        id: existing.id,
        productId: existing.productId,
        productName: existing.productName,
        sku: existing.sku,
        quantity: newQty,
        unitPriceDecimal: existing.unitPriceDecimal,
        discountDecimal: existing.discountDecimal,
        taxBreakdown: existing.taxBreakdown,
        lineTaxDecimal: existing.lineTaxDecimal,
        lineTotalDecimal: newTotal,
      );
    } else {
      _cartItems.add(item.copyWith(id: _nextCartId++));
    }
  }

  void removeCartItem(int id) {
    _cartItems.removeWhere((c) => c.id == id);
  }

  void updateCartItemQty(int id, int qty) {
    final idx = _cartItems.indexWhere((c) => c.id == id);
    if (idx < 0) return;
    if (qty <= 0) { removeCartItem(id); return; }
    final item = _cartItems[idx];
    final newTotal = item.unitPriceDecimal * Decimal.parse(qty.toString());
    _cartItems[idx] = item.copyWith(
      quantity: qty,
      lineTotalDecimal: newTotal,
    );
  }

  void clearCart() => _cartItems.clear();

  // ─── Session ───────────────────────────────────────────────────────────────
  SessionEntity? get session => _session;

  Future<void> saveSession(SessionEntity session) async {
    _session = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_user', jsonEncode(session.user.toJson()));
    // branch is nullable for org_admin users
    if (session.branch != null) {
      await prefs.setString('session_branch', jsonEncode(session.branch!.toJson()));
    } else {
      await prefs.remove('session_branch');
    }
    await prefs.setString('session_access_token', session.accessToken);
    await prefs.setString('session_refresh_token', session.refreshToken);
    await prefs.setString('session_at_expires', session.accessTokenExpiresAt.toIso8601String());
    await prefs.setString('session_rt_expires', session.refreshTokenExpiresAt.toIso8601String());
  }

  Future<SessionEntity?> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('session_user');
    final accessToken = prefs.getString('session_access_token');
    final refreshToken = prefs.getString('session_refresh_token');
    final atExpires = prefs.getString('session_at_expires');
    final rtExpires = prefs.getString('session_rt_expires');

    // user + tokens are mandatory
    if (userJson == null || accessToken == null ||
        refreshToken == null || atExpires == null || rtExpires == null) {
      return null;
    }

    final rtExpiresAt = DateTime.parse(rtExpires);
    if (DateTime.now().isAfter(rtExpiresAt)) {
      await clearSession();
      return null;
    }

    // branch is optional (org_admin may not have one)
    final branchJson = prefs.getString('session_branch');
    final branch = branchJson != null
        ? BranchEntity.fromJson(jsonDecode(branchJson) as Map<String, dynamic>)
        : null;

    _session = SessionEntity(
      user: UserEntity.fromJson(jsonDecode(userJson) as Map<String, dynamic>),
      branch: branch,
      accessToken: accessToken,
      refreshToken: refreshToken,
      accessTokenExpiresAt: DateTime.parse(atExpires),
      refreshTokenExpiresAt: rtExpiresAt,
    );
    return _session;
  }

  Future<void> clearSession() async {
    _session = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_user');
    await prefs.remove('session_branch');
    await prefs.remove('session_access_token');
    await prefs.remove('session_refresh_token');
    await prefs.remove('session_at_expires');
    await prefs.remove('session_rt_expires');
  }
}
