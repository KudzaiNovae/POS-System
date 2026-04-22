import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'core/auth/auth_controller.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_spacing.dart';
import 'core/theme/app_typography.dart';

import 'features/analytics/analytics_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/fiscal/fdms_screen.dart';
import 'features/history/history_screen.dart';
import 'features/invoices/invoice_edit_screen.dart';
import 'features/invoices/invoices_list_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/products/products_screen.dart';
import 'features/receipt/receipt_screen.dart';
import 'features/reports/z_report_screen.dart';
import 'features/settings/settings_screen.dart';

class TillProApp extends ConsumerWidget {
  const TillProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    final router = GoRouter(
      initialLocation: auth.token == null ? '/login' : '/pos',
      redirect: (ctx, state) {
        final loggedIn = ref.read(authControllerProvider).token != null;
        final goingToLogin = state.matchedLocation == '/login';
        if (!loggedIn && !goingToLogin) return '/login';
        if (loggedIn && goingToLogin) return '/pos';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(
            path: '/receipt/:id',
            builder: (_, state) =>
                ReceiptScreen(saleId: state.pathParameters['id']!)),
        GoRoute(
            path: '/invoices/new',
            builder: (_, __) => const InvoiceEditScreen()),
        GoRoute(
            path: '/invoices/edit/:id',
            builder: (_, state) =>
                InvoiceEditScreen(invoiceId: state.pathParameters['id'])),
        GoRoute(path: '/customers', builder: (_, __) => const CustomersScreen()),
        GoRoute(path: '/reports/z', builder: (_, __) => const ZReportScreen()),
        GoRoute(path: '/fiscal', builder: (_, __) => const FdmsScreen()),
        ShellRoute(
          builder: (ctx, state, child) => _Shell(child: child),
          routes: [
            GoRoute(path: '/pos', builder: (_, __) => const PosScreen()),
            GoRoute(path: '/products', builder: (_, __) => const ProductsScreen()),
            GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
            GoRoute(path: '/invoices', builder: (_, __) => const InvoicesListScreen()),
            GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
            GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
            GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
          ],
        ),
      ],
    );

    return MaterialApp.router(
      title: 'TillPro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: router,
    );
  }
}

class _Shell extends ConsumerWidget {
  const _Shell({required this.child});
  final Widget child;

  int _indexOf(String loc) {
    if (loc.startsWith('/pos')) return 0;
    if (loc.startsWith('/products')) return 1;
    if (loc.startsWith('/history')) return 2;
    if (loc.startsWith('/invoices')) return 3;
    if (loc.startsWith('/analytics') || loc.startsWith('/dashboard')) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouter.of(context).routeInformationProvider.value.uri.toString();

    return Scaffold(
      appBar: _buildAppBar(context, ref),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexOf(loc),
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryVeryLight,
        height: AppSpacing.bottomNavHeight,
        onDestinationSelected: (i) {
          switch (i) {
            case 0: context.go('/pos'); break;
            case 1: context.go('/products'); break;
            case 2: context.go('/history'); break;
            case 3: context.go('/invoices'); break;
            case 4: context.go('/analytics'); break;
            case 5: context.go('/settings'); break;
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.point_of_sale_outlined), selectedIcon: Icon(Icons.point_of_sale), label: 'Sell'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Sales'),
          NavigationDestination(icon: Icon(Icons.request_quote_outlined), selectedIcon: Icon(Icons.request_quote), label: 'Invoices'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WidgetRef ref) {
    return AppBar(
      toolbarHeight: AppSpacing.appBarHeight,
      backgroundColor: AppColors.surface,
      elevation: 0.5,
      shadowColor: AppColors.shadow,
      flexibleSpace: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox.shrink(),
            _SyncStatusIndicator(ref: ref),
          ],
        ),
      ),
    );
  }
}

class _SyncStatusIndicator extends ConsumerWidget {
  final WidgetRef ref;
  const _SyncStatusIndicator({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StreamBuilder<ConnectivityResult>(
      stream: Connectivity().onConnectivityChanged,
      initialData: ConnectivityResult.wifi,
      builder: (ctx, connSnapshot) {
        final isOffline = connSnapshot.data == ConnectivityResult.none;
        final bgColor = isOffline ? AppColors.errorBg : AppColors.successBg;
        final borderColor = isOffline ? AppColors.error.withOpacity(0.3) : AppColors.success.withOpacity(0.3);
        final textColor = isOffline ? AppColors.error : AppColors.success;

        return GestureDetector(
          onTap: isOffline ? null : () => ref.read(syncServiceProvider).syncNow(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(AppSpacing.radiusRound),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOffline ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
                  size: AppSpacing.iconSizeSm,
                  color: textColor,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  isOffline ? 'Offline' : 'Synced',
                  style: AppTypography.labelSmall(
                    color: textColor,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
