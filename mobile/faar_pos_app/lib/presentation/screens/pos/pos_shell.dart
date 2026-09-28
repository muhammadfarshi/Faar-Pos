import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/common/sync_status_indicator.dart';
import 'cart_pane.dart';

class PosShell extends ConsumerStatefulWidget {
  final Widget child;
  const PosShell({super.key, required this.child});

  @override
  ConsumerState<PosShell> createState() => _PosShellState();
}

class _PosShellState extends ConsumerState<PosShell> {
  static const _routes = ['/dashboard', '/pos/catalog', '/pos/cart', '/reports', '/admin'];

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/dashboard')) return 0;
    if (location.startsWith('/pos/catalog')) return 1;
    if (location.startsWith('/pos/cart') || location.startsWith('/pos/checkout') || location.startsWith('/pos/receipt')) return 2;
    if (location.startsWith('/reports')) return 3;
    if (location.startsWith('/admin')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider).valueOrNull;
    final cartItems = ref.watch(cartProvider).items;
    final branchName = authState?.branch?.name ?? 'FAAR POS';
    final isDemoMode = authState?.isDemoMode ?? false;
    final isTablet = MediaQuery.of(context).size.width >= 768;
    final selectedIndex = _calculateSelectedIndex(context);

    if (isTablet) {
      return _buildTabletLayout(branchName, cartItems.length, isDemoMode, selectedIndex);
    }
    return _buildPhoneLayout(branchName, cartItems.length, isDemoMode, selectedIndex);
  }

  Widget _buildTabletLayout(String branchName, int cartCount, bool isDemoMode, int selectedIndex) {
    return Scaffold(
      appBar: _buildAppBar(branchName, isDemoMode),
      body: Column(
        children: [
          if (isDemoMode) _buildDemoBanner(),
          Expanded(
            child: Row(
              children: [
                _buildNavigationRail(selectedIndex),
                const VerticalDivider(width: 1, thickness: 1, color: FaarPosTheme.kDivider),
                Expanded(child: widget.child),
                if (GoRouterState.of(context).matchedLocation == '/pos/catalog') ...[
                  const VerticalDivider(width: 1, thickness: 1, color: FaarPosTheme.kDivider),
                  const SizedBox(width: 380, child: CartPane()),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneLayout(String branchName, int cartCount, bool isDemoMode, int selectedIndex) {
    return Scaffold(
      appBar: _buildAppBar(branchName, isDemoMode),
      body: Column(
        children: [
          if (isDemoMode) _buildDemoBanner(),
          Expanded(child: widget.child),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: (index) {
          context.go(_routes[index]);
        },
        selectedItemColor: FaarPosTheme.kPrimary,
        unselectedItemColor: FaarPosTheme.kTextSecondary,
        backgroundColor: FaarPosTheme.kSurface,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.storefront_outlined),
            activeIcon: Icon(Icons.storefront),
            label: 'POS',
          ),
          BottomNavigationBarItem(
            icon: Badge(
              label: cartCount > 0 ? Text('$cartCount') : null,
              isLabelVisible: cartCount > 0,
              child: const Icon(Icons.shopping_cart_outlined),
            ),
            activeIcon: const Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings_outlined),
            activeIcon: Icon(Icons.admin_panel_settings),
            label: 'Admin',
          ),
        ],
      ),
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      color: FaarPosTheme.kPrimary.withValues(alpha: 0.12),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt, size: 14, color: FaarPosTheme.kPrimary),
          SizedBox(width: 8),
          Text(
            'OFFLINE-FIRST MODE — Local SQLite storage active. Transactions persist automatically.',
            style: TextStyle(
              fontSize: 11,
              color: FaarPosTheme.kPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(String branchName, bool isDemoMode) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: FaarPosTheme.kPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.flash_on_rounded, color: FaarPosTheme.kPrimary, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'FAAR POS',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: FaarPosTheme.kPrimary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: FaarPosTheme.kPrimary.withValues(alpha: 0.4)),
            ),
            child: Text(
              branchName,
              style: const TextStyle(fontSize: 11, color: FaarPosTheme.kPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      actions: [
        if (!isDemoMode)
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: SyncStatusIndicator(),
          )
        else
          const Padding(
            padding: EdgeInsets.only(right: 8),
            child: Icon(Icons.wifi_off_rounded,
                color: FaarPosTheme.kWarning, size: 20),
          ),
        // Cashier Profile & Quick Switch Menu
        PopupMenuButton<String>(
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: FaarPosTheme.kPrimary.withValues(alpha: 0.2),
            child: const Icon(Icons.person, size: 18, color: FaarPosTheme.kPrimary),
          ),
          tooltip: 'Cashier Account',
          onSelected: (value) {
            if (value == 'lock') {
              _showPinLockDialog(context);
            } else if (value == 'logout') {
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              enabled: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Active Shift', style: TextStyle(fontSize: 11, color: FaarPosTheme.kTextSecondary)),
                  Text('Cashier Counter 1', style: TextStyle(fontWeight: FontWeight.bold, color: FaarPosTheme.kTextPrimary)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'lock',
              child: Row(
                children: [
                  Icon(Icons.lock_outline, size: 18),
                  SizedBox(width: 8),
                  Text('Lock Screen / Switch PIN'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 18, color: FaarPosTheme.kDanger),
                  SizedBox(width: 8),
                  Text('Sign Out', style: TextStyle(color: FaarPosTheme.kDanger)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  void _showPinLockDialog(BuildContext context) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: FaarPosTheme.kPrimary),
            SizedBox(width: 8),
            Text('Register Locked'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your 4-digit cashier PIN to unlock the terminal.',
              style: TextStyle(color: FaarPosTheme.kTextSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: '••••',
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(authProvider.notifier).logout();
              context.go('/login');
            },
            child: const Text('Sign Out', style: TextStyle(color: FaarPosTheme.kDanger)),
          ),
          ElevatedButton(
            onPressed: () {
              if (pinCtrl.text.length == 4) {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Terminal unlocked!'),
                    backgroundColor: FaarPosTheme.kSuccess,
                  ),
                );
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  NavigationRail _buildNavigationRail(int selectedIndex) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        context.go(_routes[index]);
      },
      backgroundColor: FaarPosTheme.kSurface,
      selectedIconTheme: const IconThemeData(color: FaarPosTheme.kPrimary),
      unselectedIconTheme: const IconThemeData(color: FaarPosTheme.kTextSecondary),
      labelType: NavigationRailLabelType.all,
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.storefront_outlined),
          selectedIcon: Icon(Icons.storefront),
          label: Text('POS'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.shopping_cart_outlined),
          selectedIcon: Icon(Icons.shopping_cart),
          label: Text('Cart'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.bar_chart_outlined),
          selectedIcon: Icon(Icons.bar_chart),
          label: Text('Reports'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: Icon(Icons.admin_panel_settings),
          label: Text('Admin'),
        ),
      ],
    );
  }
}
