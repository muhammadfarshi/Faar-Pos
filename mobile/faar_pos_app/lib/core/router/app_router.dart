import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/providers/auth_provider.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/pos/pos_shell.dart';
import '../../presentation/screens/pos/catalog_pane.dart';
import '../../presentation/screens/pos/cart_pane.dart';
import '../../presentation/screens/pos/checkout_screen.dart';
import '../../presentation/screens/pos/receipt_screen.dart';
import '../../presentation/screens/admin/admin_shell.dart';
import '../../presentation/screens/reports/reports_shell.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../domain/entities/transaction_entity.dart';

// ─── RouterNotifier ─────────────────────────────────────────────────────────
// Bridges Riverpod auth state into GoRouter's refreshListenable.
// The GoRouter instance is created ONCE and told to re-evaluate its redirect
// whenever this notifier calls notifyListeners().
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    // Listen to auth changes and propagate to GoRouter via notifyListeners
    _ref.listen<AsyncValue<AuthState>>(
      authProvider,
      (previous, next) {
        final wasAuth = previous?.valueOrNull?.isAuthenticated ?? false;
        final isAuth = next.valueOrNull?.isAuthenticated ?? false;
        // Only notify when the authentication status actually changes,
        // not on every loading/error intermediate state change.
        if (wasAuth != isAuth || next.hasError) {
          notifyListeners();
        }
      },
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    // During async loading, don't redirect anywhere
    final authAsync = _ref.read(authProvider);
    if (authAsync.isLoading) return null;

    final isAuth = authAsync.valueOrNull?.isAuthenticated ?? false;
    final isLoginPage = state.matchedLocation == '/login';

    if (!isAuth && !isLoginPage) return '/login';
    if (isAuth && isLoginPage) return '/dashboard';
    return null;
  }
}

// ─── Router Provider ─────────────────────────────────────────────────────────
// keepAlive: true ensures the GoRouter is created ONCE and never disposed.
final routerProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,   // ← GoRouter re-runs redirect when notifier fires
    redirect: notifier.redirect,
    debugLogDiagnostics: true,     // helpful during development
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => PosShell(child: child),
        routes: [
          GoRoute(
            path: '/pos',
            redirect: (context, state) => '/dashboard',
          ),
          GoRoute(
            path: '/dashboard',
            name: 'dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/pos/catalog',
            name: 'catalog',
            builder: (context, state) => const CatalogPane(),
          ),
          GoRoute(
            path: '/pos/cart',
            name: 'cart',
            builder: (context, state) => const CartPane(),
          ),
          GoRoute(
            path: '/pos/checkout',
            name: 'checkout',
            builder: (context, state) => const CheckoutScreen(),
          ),
          GoRoute(
            path: '/pos/receipt',
            name: 'receipt',
            builder: (context, state) {
              final tx = state.extra as TransactionEntity?;
              return ReceiptScreen(transaction: tx);
            },
          ),
          GoRoute(
            path: '/admin',
            name: 'admin',
            builder: (context, state) => const AdminShell(),
          ),
          GoRoute(
            path: '/reports',
            name: 'reports',
            builder: (context, state) => const ReportsShell(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Page not found: ${state.matchedLocation}'),
          ],
        ),
      ),
    ),
  );

  // Dispose the notifier when the provider is disposed
  ref.onDispose(() {
    notifier.dispose();
    router.dispose();
  });

  return router;
});
