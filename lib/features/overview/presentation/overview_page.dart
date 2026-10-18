import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/overview_repository.dart';
import 'overview_view_model.dart';
import '../../startup/presentation/startup_guide.dart';

class OverviewPage extends StatefulWidget {
  const OverviewPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  late final vm = OverviewViewModel(widget.dependencies.overview);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, vm.query]),
    builder: (context, _) {
      if (vm.query.error != null) {
        return DeptAccountingStateView(
          state: DeptAccountingViewState.error,
          title: 'تعذر تحميل البيانات',
          message: vm.query.error!,
          actionLabel: 'إعادة المحاولة',
          onAction: vm.refresh,
        );
      }
      if (vm.query.value == null) {
        return const DeptAccountingStateView(
          state: DeptAccountingViewState.loading,
          title: 'جارٍ تحميل البيانات',
          message: '',
        );
      }
      final d = widget.dependencies;
      final manage = d.store.user!.canManage;
      final compact =
          MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact;
      return SectionStack(
        children: [
          DeptAccountingPageHeader(
            title: 'نظرة على محلك',
            description:
                'مرحبًا ${d.store.user!.displayName}، إليك آخر حركة في ${d.store.shop!.name}.',
            actions: [
              if (!compact)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatFullDate(DateTime.now()),
                    style: const TextStyle(color: DeptAccountingColors.muted),
                  ),
                ),
            ],
          ),
          if (manage) StartupGuide(dependencies: d),
          LayoutBuilder(
            builder: (context, size) {
              final wide =
                  size.maxWidth >= 1050 &&
                  MediaQuery.textScalerOf(context).scale(14) < 22;
              final chart = _ActivityPanel(
                vm: vm,
                currency: d.store.shop!.currencyLabel,
                manage: manage,
                wide: wide,
              );
              final actions = compact
                  ? _MobileQuickActions(d: d)
                  : _QuickActions(d: d, wide: wide);
              final invoices = _RecentInvoices(
                d: d,
                invoices: vm.invoices,
                wide: wide,
              );
              final stock = _LowStock(
                items: vm.lowStock,
                total: vm.lowStockCount,
                wide: wide,
              );
              if (!wide) {
                return SectionStack(
                  children: [
                    if (compact)
                      DeptAccountingPanel(
                        title: 'مبيعات اليوم',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${Numbers.format(vm.activity.lastOrNull?.sales ?? 0)} ${d.store.shop!.currencyLabel}',
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: DeptAccountingColors.primary,
                                  ),
                            ),
                            if (manage)
                              Text(
                                'مجمل الربح ${Numbers.format(vm.activity.lastOrNull?.profit ?? 0)} ${d.store.shop!.currencyLabel}',
                                style: const TextStyle(
                                  color: DeptAccountingColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                    actions,
                    chart,
                    invoices,
                    stock,
                  ],
                );
              }
              Widget row(
                Widget first,
                Widget second, {
                int firstFlex = 7,
                int secondFlex = 4,
              }) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: firstFlex, child: first),
                  const SizedBox(width: DeptAccountingSpace.xl),
                  Expanded(flex: secondFlex, child: second),
                ],
              );
              return SectionStack(
                children: [
                  row(actions, chart, firstFlex: 4, secondFlex: 7),
                  row(invoices, stock),
                ],
              );
            },
          ),
        ],
      );
    },
  );
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({
    required this.vm,
    required this.currency,
    required this.manage,
    required this.wide,
  });
  final OverviewViewModel vm;
  final String currency;
  final bool manage;
  final bool wide;
  static const weekdays = [
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];

  @override
  Widget build(BuildContext context) {
    final sales = vm.activity.fold<int>(0, (sum, day) => sum + day.sales);
    return DeptAccountingPanel(
      title: 'حركة المبيعات',
      minHeight: wide ? 440 : 0,
      showHeaderDivider: false,
      action: PopupMenuButton<int>(
        tooltip: 'فترة حركة المبيعات',
        initialValue: vm.days,
        onSelected: vm.changePeriod,
        itemBuilder: (_) => const [
          PopupMenuItem(value: 7, child: Text('آخر ٧ أيام')),
          PopupMenuItem(value: 30, child: Text('آخر ٣٠ يومًا')),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: DeptAccountingColors.border),
            borderRadius: BorderRadius.circular(DeptAccountingLayout.radius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(vm.days == 7 ? 'آخر ٧ أيام' : 'آخر ٣٠ يومًا'),
              const SizedBox(width: 8),
              const Icon(Icons.keyboard_arrow_down, size: 18),
            ],
          ),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            runSpacing: 8,
            spacing: 12,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  const _Legend('المبيعات', DeptAccountingColors.primary),
                  if (manage)
                    const _Legend(
                      'مجمل الربح',
                      DeptAccountingColors.chartSecondary,
                    ),
                ],
              ),
              Text(
                '${Numbers.format(sales)} $currency',
                style: const TextStyle(
                  color: DeptAccountingColors.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              DeptAccountingLineChart(
                primaryLabel: 'المبيعات',
                secondaryLabel: manage ? 'مجمل الربح' : null,
                points: [
                  for (final day in vm.activity)
                    DeptAccountingChartPoint(
                      label: vm.days == 7
                          ? weekdays[day.date.weekday - 1]
                          : '${day.date.day}/${day.date.month}',
                      value: day.sales / 100,
                      secondary: day.profit == null ? null : day.profit! / 100,
                    ),
                ],
                formatValue: (value) {
                  if (value.abs() >= 1000000) {
                    return '${(value / 1000000).toStringAsFixed(1)} م';
                  }
                  if (value.abs() >= 1000) {
                    return '${(value / 1000).toStringAsFixed(1)} ألف';
                  }
                  return Numbers.format((value * 100).round());
                },
              ),
              if (vm.activity.every(
                (day) => day.sales == 0 && (day.profit ?? 0) == 0,
              ))
                IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: DeptAccountingColors.surface,
                    child: const Text(
                      'لا توجد حركة مبيعات خلال هذه الفترة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DeptAccountingColors.muted),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend(this.label, this.color);
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: const SizedBox.square(dimension: 7),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(color: DeptAccountingColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _MobileQuickActions extends StatelessWidget {
  const _MobileQuickActions({required this.d});
  final AppDependencies d;
  @override
  Widget build(BuildContext context) => FieldGrid(
    key: const ValueKey('overview-quick-actions'),
    minWidth: 130,
    children: [
      DeptAccountingButton(
        label: 'فاتورة بيع',
        icon: Icons.receipt_long_outlined,
        onPressed: () => context.go('/sales/new/${d.store.id()}'),
      ),
      if (d.store.user!.canManage)
        DeptAccountingButton(
          label: 'فاتورة شراء',
          icon: Icons.shopping_bag_outlined,
          variant: DeptAccountingButtonVariant.secondary,
          onPressed: () => context.go('/purchases/new/${d.store.id()}'),
        ),
      DeptAccountingButton(
        label: 'سند قبض',
        icon: Icons.south_west,
        variant: DeptAccountingButtonVariant.secondary,
        onPressed: () => context.go('/finance/new?kind=receipt'),
      ),
      if (d.store.user!.canManage)
        DeptAccountingButton(
          label: 'تسجيل مصروف',
          icon: Icons.north_east,
          variant: DeptAccountingButtonVariant.secondary,
          onPressed: () => context.go('/finance/new?kind=expense'),
        ),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.d, required this.wide});
  final AppDependencies d;
  final bool wide;
  @override
  Widget build(BuildContext context) => DeptAccountingPanel(
    key: const ValueKey('overview-quick-actions'),
    title: 'خطوة سريعة',
    minHeight: wide ? 440 : 0,
    showHeaderDivider: false,
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 330 : 0),
      child: LayoutBuilder(
        builder: (context, size) {
          final columns =
              size.maxWidth >= 280 &&
                  MediaQuery.textScalerOf(context).scale(14) < 22
              ? 2
              : 1;
          final width = (size.maxWidth - (columns - 1) * 12) / columns;
          final actions = [
            (
              title: 'فاتورة بيع',
              description: 'نقدي أو آجل',
              icon: Icons.receipt_long_outlined,
              path: '/sales/new/${d.store.id()}',
            ),
            if (d.store.user!.canManage)
              (
                title: 'فاتورة شراء',
                description: 'إضافة بضاعة للمخزون',
                icon: Icons.inventory_2_outlined,
                path: '/purchases/new/${d.store.id()}',
              ),
            (
              title: 'سند قبض',
              description: 'تحصيل دفعة عميل',
              icon: Icons.south_west,
              path: '/finance/new?kind=receipt',
            ),
            if (d.store.user!.canManage)
              (
                title: 'تسجيل مصروف',
                description: 'متابعة تكاليف المحل',
                icon: Icons.north_east,
                path: '/finance/new?kind=expense',
              ),
          ];
          return Align(
            alignment: AlignmentDirectional.topStart,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final action in actions)
                  SizedBox(
                    width: width,
                    child: DeptAccountingActionCard(
                      title: action.title,
                      description: action.description,
                      icon: action.icon,
                      onTap: () => context.go(action.path),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _RecentInvoices extends StatelessWidget {
  const _RecentInvoices({
    required this.d,
    required this.invoices,
    required this.wide,
  });
  final AppDependencies d;
  final List<OverviewInvoice> invoices;
  final bool wide;
  @override
  Widget build(BuildContext context) => DeptAccountingPanel(
    title: 'آخر فواتير البيع',
    minHeight: wide ? 486 : 0,
    showHeaderDivider: false,
    padding: EdgeInsets.zero,
    action: DeptAccountingButton.table(
      onPressed: () => context.go('/sales'),
      label: 'كل الفواتير ←',
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 360 : 0),
      child: DeptAccountingDataTable(
        minWidth: 680,
        compactRowBuilder: (context, index) {
          final row = invoices[index];
          return Padding(
            padding: const EdgeInsets.all(8),
            child: DeptAccountingRecordTile(
              title: row.document.number,
              subtitle: row.customer,
              leading: Icons.receipt_long_outlined,
              onTap: () => context.go('/sales/view/${row.document.id}'),
              details: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  DeptAccountingAmount(
                    Numbers.format(row.document.total),
                    currency: d.store.shop!.currencyLabel,
                  ),
                  DeptAccountingStatusTag(
                    row.cancelled
                        ? 'ملغاة'
                        : row.due == 0
                        ? 'مسددة'
                        : 'متبقي ${Numbers.format(row.due)}',
                    tone: row.cancelled
                        ? DeptAccountingTone.neutral
                        : row.due == 0
                        ? DeptAccountingTone.success
                        : DeptAccountingTone.warning,
                  ),
                ],
              ),
            ),
          );
        },
        columnSpacing: 12,
        horizontalMargin: 20,
        showPagination: false,
        columns: [
          const DataColumn(label: Text('رقم الفاتورة')),
          const DataColumn(label: Text('التاريخ')),
          const DataColumn(label: Text('الاسم')),
          DataColumn(label: Text('الإجمالي · ${d.store.shop!.currencyLabel}')),
          const DataColumn(label: Text('المدفوع')),
          const DataColumn(label: Text('المتبقي')),
          const DataColumn(label: Text('الحالة')),
          const DataColumn(label: Text('')),
        ],
        rows: [
          for (final row in invoices)
            DataRow(
              cells: [
                DataCell(
                  Text(row.document.number, textDirection: TextDirection.ltr),
                ),
                DataCell(Text(row.document.date)),
                DataCell(Text(row.customer)),
                DataCell(
                  Text(
                    Numbers.format(row.document.total),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    Numbers.format(row.paid),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  Text(
                    Numbers.format(row.due),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                DataCell(
                  DeptAccountingStatusTag(
                    row.cancelled
                        ? 'ملغاة'
                        : row.due == 0
                        ? 'مسددة'
                        : row.paid > 0
                        ? 'دفع جزئي'
                        : 'آجلة',
                    tone: row.cancelled
                        ? DeptAccountingTone.neutral
                        : row.due == 0
                        ? DeptAccountingTone.success
                        : row.paid > 0
                        ? DeptAccountingTone.warning
                        : DeptAccountingTone.danger,
                  ),
                ),
                DataCell(
                  DeptAccountingIconButton.table(
                    onPressed: () =>
                        context.go('/sales/view/${row.document.id}'),
                    tooltip: 'عرض',
                    icon: Icons.visibility_outlined,
                  ),
                ),
              ],
            ),
        ],
        totalRows: invoices.length,
        page: 1,
        pageSize: 5,
        onPageChanged: (_) {},
        emptyTitle: 'لا توجد فواتير بيع بعد',
        emptyMessage: 'ابدأ بفاتورة بيع، وستجد آخر فواتيرك هنا.',
      ),
    ),
  );
}

class _LowStock extends StatelessWidget {
  const _LowStock({
    required this.items,
    required this.total,
    required this.wide,
  });
  final List<OverviewStock> items;
  final bool wide;
  final int total;
  @override
  Widget build(BuildContext context) => DeptAccountingPanel(
    title: 'تحتاج إلى إعادة تزويد',
    minHeight: wide ? 486 : 0,
    showHeaderDivider: false,
    padding: EdgeInsets.zero,
    action: DeptAccountingStatusTag(
      '$total منتجات',
      tone: total == 0
          ? DeptAccountingTone.success
          : DeptAccountingTone.warning,
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 412 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty)
                const DeptAccountingStateView(
                  state: DeptAccountingViewState.empty,
                  title: 'مخزونك بخير',
                  message: 'لا توجد منتجات وصلت إلى حد التنبيه.',
                )
              else
                for (final item in items.take(4)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(
                        DeptAccountingLayout.radius,
                      ),
                      onTap: () => context.go('/catalog/${item.id}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'حد التنبيه: ${Numbers.format(item.minimum, decimals: 3)} ${item.unit}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: DeptAccountingColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DeptAccountingStatusTag(
                              item.quantity <= 0
                                  ? 'نفد المخزون'
                                  : '${Numbers.format(item.quantity, decimals: 3)} متبقية',
                              tone: item.quantity <= 0
                                  ? DeptAccountingTone.danger
                                  : DeptAccountingTone.warning,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Divider(),
                  ),
                ],
            ],
          ),
          TextButton(
            onPressed: () => context.go('/catalog?stock=low'),
            child: const Text('عرض المنتجات منخفضة المخزون ←'),
          ),
        ],
      ),
    ),
  );
}
