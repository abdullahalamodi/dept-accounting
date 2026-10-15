import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../design_system/dukan_design_system.dart';
import '../design_system/gallery/design_system_gallery.dart';
import '../features/auth/presentation/auth_page.dart';
import '../features/backup/presentation/backup_status_notice.dart';
import '../features/catalog/presentation/catalog_page.dart';
import '../features/finance/presentation/finance_page.dart';
import '../features/invoices/presentation/document_page.dart';
import '../features/invoices/presentation/invoice_editor_page.dart';
import '../features/invoices/presentation/invoices_page.dart';
import '../features/parties/presentation/parties_page.dart';
import '../features/reports/presentation/reports_page.dart';
import '../features/overview/presentation/overview_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'dependencies.dart';
import '../features/returns/presentation/return_page.dart';
import '../features/receiving/presentation/receiving_page.dart';
import '../features/inventory/presentation/inventory_page.dart';

GoRouter createRouter(AppDependencies d) => GoRouter(
  refreshListenable: d.store,
  redirect: (context, state) {
    final path = state.uri.path;
    if (d.store.shop == null) return path == '/setup' ? null : '/setup';
    if (d.store.user == null) return path == '/login' ? null : '/login';
    if (path == '/setup' || path == '/login') return '/';
    if (!d.store.user!.isOwner && path == '/settings') return '/';
    if (!d.store.user!.canManage &&
        (path.startsWith('/purchases') ||
            path == '/reports' ||
            path.startsWith('/receiving') ||
            path.startsWith('/inventory') ||
            path.startsWith('/returns') ||
            path == '/catalog/new')) {
      return '/';
    }
    return null;
  },
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: DukanStateView(
        state: DukanViewState.error,
        title: 'تعذر فتح الصفحة',
        message: 'تحقق من المسار ثم عد إلى البداية.',
        actionLabel: 'الرئيسية',
        onAction: () => context.go('/'),
      ),
    ),
  ),
  routes: [
    GoRoute(
      path: '/setup',
      builder: (context, state) => AuthPage(dependencies: d, setup: true),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => AuthPage(dependencies: d, setup: false),
    ),
    ShellRoute(
      builder: (context, state, child) =>
          _AppWorkspace(d: d, path: state.uri.path, child: child),
      routes: [
        _featureRoute(
          path: '/',
          builder: (context, state) => OverviewPage(dependencies: d),
        ),
        _featureRoute(
          path: '/catalog',
          builder: (context, state) => CatalogPage(
            key: ValueKey(state.uri),
            dependencies: d,
            lowStockOnly: state.uri.queryParameters['stock'] == 'low',
          ),
        ),
        _featureRoute(
          path: '/catalog/:id',
          builder: (context, state) => ProductPage(
            key: ValueKey(state.uri),
            dependencies: d,
            id: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/parties',
          builder: (context, state) => PartiesPage(dependencies: d),
        ),
        _featureRoute(
          path: '/parties/:id',
          builder: (context, state) => PartyPage(
            key: ValueKey(state.uri),
            dependencies: d,
            id: state.pathParameters['id']!,
          ),
        ),
        for (final sale in [true, false]) ...[
          _featureRoute(
            path: sale ? '/sales' : '/purchases',
            builder: (context, state) =>
                InvoicesPage(key: ValueKey(sale), dependencies: d, sale: sale),
          ),
          _featureRoute(
            path: '${sale ? '/sales' : '/purchases'}/new/:id',
            builder: (context, state) => InvoiceEditorPage(
              key: ValueKey(state.uri),
              dependencies: d,
              sale: sale,
              id: state.pathParameters['id']!,
            ),
          ),
          _featureRoute(
            path: '${sale ? '/sales' : '/purchases'}/view/:id',
            builder: (context, state) =>
                DocumentPage(dependencies: d, id: state.pathParameters['id']!),
          ),
        ],
        _featureRoute(
          path: '/finance',
          builder: (context, state) => FinancePage(dependencies: d),
        ),
        _featureRoute(
          path: '/finance/new',
          builder: (context, state) => FinanceEditorPage(
            key: ValueKey(state.uri),
            dependencies: d,
            initialKind:
                state.uri.queryParameters['kind'] == 'expense' &&
                    d.store.user!.canManage
                ? 'expense'
                : 'receipt',
          ),
        ),
        _featureRoute(
          path: '/finance/view/:id',
          builder: (context, state) =>
              DocumentPage(dependencies: d, id: state.pathParameters['id']!),
        ),
        _featureRoute(
          path: '/pos/:id',
          builder: (context, state) => InvoiceEditorPage(
            key: ValueKey(state.uri),
            dependencies: d,
            sale: true,
            pos: true,
            id: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/receiving',
          builder: (context, state) => ReceivingPage(dependencies: d),
        ),
        _featureRoute(
          path: '/receiving/new/:id',
          builder: (context, state) => InvoiceEditorPage(
            key: ValueKey(state.uri),
            dependencies: d,
            sale: false,
            quick: true,
            id: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/receiving/finalize/:receipt/:id',
          builder: (context, state) => InvoiceEditorPage(
            key: ValueKey(state.uri),
            dependencies: d,
            sale: false,
            receiptId: state.pathParameters['receipt'],
            id: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/inventory/:id',
          builder: (context, state) => InventoryPage(
            key: ValueKey(state.uri),
            dependencies: d,
            productId: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/returns/:id',
          builder: (context, state) => ReturnPage(
            key: ValueKey(state.uri),
            dependencies: d,
            invoiceId: state.pathParameters['id']!,
          ),
        ),
        _featureRoute(
          path: '/documents/:id',
          builder: (context, state) =>
              DocumentPage(dependencies: d, id: state.pathParameters['id']!),
        ),
        _featureRoute(
          path: '/reports',
          builder: (context, state) => ReportsPage(dependencies: d),
        ),
        _featureRoute(
          path: '/settings',
          builder: (context, state) => SettingsPage(dependencies: d),
        ),
      ],
    ),
    GoRoute(
      path: '/design-system',
      builder: (context, state) => const DesignSystemGallery(),
    ),
  ],
);

class _AppWorkspace extends StatelessWidget {
  const _AppWorkspace({
    required this.d,
    required this.path,
    required this.child,
  });
  final AppDependencies d;
  final String path;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (d.store.user == null || d.store.shop == null) {
      return const SizedBox.shrink();
    }
    final items = <({String path, String label, IconData icon})>[
      (path: '/', label: 'الرئيسية', icon: Icons.grid_view_outlined),
      (path: '/sales', label: 'المبيعات', icon: Icons.receipt_long_outlined),
      if (d.store.user!.canManage)
        (
          path: '/purchases',
          label: 'المشتريات',
          icon: Icons.shopping_bag_outlined,
        ),
      if (d.store.setting('pos_enabled') == 'true')
        (path: '/pos', label: 'نقطة البيع', icon: Icons.point_of_sale_outlined),
      if (d.store.user!.canManage)
        (
          path: '/receiving',
          label: 'الاستلام السريع',
          icon: Icons.local_shipping_outlined,
        ),
      (
        path: '/catalog',
        label: 'المنتجات والخدمات',
        icon: Icons.inventory_2_outlined,
      ),
      (
        path: '/parties',
        label: 'العملاء والموردون',
        icon: Icons.people_outline,
      ),
      (
        path: '/finance',
        label: 'الصندوق والمالية',
        icon: Icons.account_balance_wallet_outlined,
      ),
      if (d.store.user!.canManage)
        (
          path: '/reports',
          label: 'التقارير والمحاسبة',
          icon: Icons.bar_chart_outlined,
        ),
      if (d.store.user!.isOwner)
        (
          path: '/settings',
          label: 'الإعدادات والنسخ',
          icon: Icons.settings_outlined,
        ),
      (path: '/logout', label: 'قفل الجلسة', icon: Icons.lock_outline),
    ];
    final selected = items.indexWhere(
      (item) => item.path == '/' ? path == '/' : path.startsWith(item.path),
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () =>
            context.go('/sales/new/${d.store.id()}'),
        const SingleActivator(LogicalKeyboardKey.f3): () =>
            context.go('/catalog'),
        const SingleActivator(LogicalKeyboardKey.f4): () =>
            context.go('/parties'),
        if (d.store.user!.canManage)
          const SingleActivator(LogicalKeyboardKey.f6): () =>
              context.go('/purchases/new/${d.store.id()}'),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            d.store.logout,
      },
      child: DukanWorkspace(
        libraryMode: false,
        scrollBody: false,
        notice: d.store.user!.canManage
            ? BackupStatusNotice(
                backups: d.backups,
                padding: const EdgeInsets.all(12),
              )
            : null,
        destinations: items.map((i) => (label: i.label, icon: i.icon)).toList(),
        selectedIndex: selected < 0 ? 0 : selected,
        title: items[selected < 0 ? 0 : selected].label,
        footer: '${d.store.shop!.name} · ${d.store.user!.roleLabel}',
        onSelected: (index) {
          if (items[index].path == '/logout') {
            d.store.logout();
          } else {
            context.go(
              items[index].path == '/pos'
                  ? '/pos/${d.store.id()}'
                  : items[index].path,
            );
          }
        },
        child: child,
      ),
    );
  }
}

GoRoute _featureRoute({
  required String path,
  required Widget Function(BuildContext, GoRouterState) builder,
}) => GoRoute(
  path: path,
  builder: (context, state) => DukanPageBody(child: builder(context, state)),
);
