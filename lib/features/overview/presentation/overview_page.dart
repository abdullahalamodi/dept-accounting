import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../data/overview_repository.dart';
import 'overview_view_model.dart';

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
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies;
      final manage = d.store.user!.canManage;
      return SectionStack(
        children: [
          DukanPageHeader(
            title: 'نظرة على محلك',
            description:
                'مرحبًا ${d.store.user!.displayName}، إليك آخر حركة في ${d.store.shop!.name}.',
            actions: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  MaterialLocalizations.of(context)
                      .formatFullDate(DateTime.now()),
                  style: const TextStyle(color: DukanColors.muted),
                ),
              ),
            ],
          ),
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
              final actions = _QuickActions(d: d, wide: wide);
              final invoices = _RecentInvoices(
                d: d,
                invoices: vm.invoices,
                wide: wide,
              );
              final stock = _LowStock(items: vm.lowStock, wide: wide);
              if (!wide) {
                return SectionStack(
                  children: [actions, chart, invoices, stock],
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
                  const SizedBox(width: DukanSpace.xl),
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
    return DukanPanel(
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
            border: Border.all(color: DukanColors.border),
            borderRadius: BorderRadius.circular(DukanLayout.radius),
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
                  const _Legend('المبيعات', DukanColors.primary),
                  if (manage)
                    const _Legend('مجمل الربح', DukanColors.chartSecondary),
                ],
              ),
              Text(
                '${Numbers.format(sales)} $currency',
                style: const TextStyle(color: DukanColors.muted, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Stack(
            alignment: Alignment.center,
            children: [
              DukanLineChart(
                primaryLabel: 'المبيعات',
                secondaryLabel: manage ? 'مجمل الربح' : null,
                points: [
                  for (final day in vm.activity)
                    DukanChartPoint(
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
                    color: DukanColors.surface,
                    child: const Text(
                      'لا توجد حركة مبيعات خلال هذه الفترة',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: DukanColors.muted),
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
        style: const TextStyle(color: DukanColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.d, required this.wide});
  final AppDependencies d;
  final bool wide;
  @override
  Widget build(BuildContext context) => DukanPanel(
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
                    child: DukanActionCard(
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
  Widget build(BuildContext context) => DukanPanel(
    title: 'آخر فواتير البيع',
    minHeight: wide ? 486 : 0,
    showHeaderDivider: false,
    padding: EdgeInsets.zero,
    action: TextButton(
      onPressed: () => context.go('/sales'),
      child: const Text('كل الفواتير ←'),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: wide ? 360 : 0),
      child: DukanDataTable(
        minWidth: 680,
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
                  DukanStatusTag(
                    row.cancelled
                        ? 'ملغاة'
                        : row.due == 0
                        ? 'مسددة'
                        : row.paid > 0
                        ? 'دفع جزئي'
                        : 'آجلة',
                    tone: row.cancelled
                        ? DukanTone.neutral
                        : row.due == 0
                        ? DukanTone.success
                        : row.paid > 0
                        ? DukanTone.warning
                        : DukanTone.danger,
                  ),
                ),
                DataCell(
                  TextButton(
                    onPressed: () =>
                        context.go('/sales/view/${row.document.id}'),
                    child: const Text('عرض'),
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
  const _LowStock({required this.items, required this.wide});
  final List<OverviewStock> items;
  final bool wide;
  @override
  Widget build(BuildContext context) => DukanPanel(
    title: 'تحتاج إلى إعادة تزويد',
    minHeight: wide ? 486 : 0,
    showHeaderDivider: false,
    padding: EdgeInsets.zero,
    action: DukanStatusTag(
      '${items.length} منتجات',
      tone: items.isEmpty ? DukanTone.success : DukanTone.warning,
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
                const DukanStateView(
                  state: DukanViewState.empty,
                  title: 'مخزونك بخير',
                  message: 'لا توجد منتجات وصلت إلى حد التنبيه.',
                )
              else
                for (final item in items.take(4)) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(DukanLayout.radius),
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
                                      color: DukanColors.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            DukanStatusTag(
                              item.quantity <= 0
                                  ? 'نفد المخزون'
                                  : '${Numbers.format(item.quantity, decimals: 3)} متبقية',
                              tone: item.quantity <= 0
                                  ? DukanTone.danger
                                  : DukanTone.warning,
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
