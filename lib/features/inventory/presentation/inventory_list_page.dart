import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/database_query.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../catalog/data/catalog_tasks.dart';
import '../../catalog/presentation/catalog_view_model.dart';

class InventoryListPage extends StatefulWidget {
  const InventoryListPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<InventoryListPage> createState() => _InventoryListPageState();
}

class _InventoryListPageState extends State<InventoryListPage> {
  late final vm = CatalogViewModel(widget.dependencies.catalog);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => DatabaseQuery(
      store: widget.dependencies.store,
      task: CatalogTasks.page(
        search: vm.search,
        lowOnly: vm.lowOnly,
        excludeServices: true,
        page: vm.page,
      ),
      queryKey: (vm.search, vm.lowOnly, vm.page),
      builder: (context, results) => SectionStack(
        children: [
          DeptAccountingPageHeader(
            title: 'المخزون',
            description: 'الكميات المتاحة، حركة المنتجات، والجرد',
            actions: [
              DeptAccountingButton(
                label: 'استلام سريع',
                icon: Icons.local_shipping_outlined,
                onPressed: () => context.go('/receiving'),
              ),
            ],
          ),
          DeptAccountingListToolbar(
            search: DeptAccountingField(
              label: 'بحث عن منتج',
              onChanged: vm.filter,
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: DeptAccountingFilterChip(
              label: const Text('مخزون منخفض'),
              selected: vm.lowOnly,
              onSelected: (value) {
                vm.lowOnly = value;
                vm.filter(vm.search);
              },
            ),
          ),
          DeptAccountingPanel(
            padding: EdgeInsets.zero,
            child: DeptAccountingDataTable(
              compactRowBuilder: (context, index) {
                final row = results.items[index];
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: DeptAccountingRecordTile(
                    title: row.product.name,
                    subtitle: row.product.category,
                    leading: Icons.inventory_2_outlined,
                    onTap: () => context.go('/inventory/${row.product.id}'),
                    details: Text(
                      '${Numbers.format(row.quantity, decimals: 3)} ${row.product.unit} متاح',
                    ),
                  ),
                );
              },
              columns: const [
                DataColumn(label: Text('المنتج')),
                DataColumn(label: Text('المتوفر')),
                DataColumn(label: Text('الحركة')),
              ],
              rows: [
                for (final row in results.items)
                  DataRow(
                    cells: [
                      DataCell(Text(row.product.name)),
                      DataCell(
                        Text(
                          '${Numbers.format(row.quantity, decimals: 3)} ${row.product.unit}',
                        ),
                      ),
                      DataCell(
                        DeptAccountingButton.table(
                          label: 'حركة المخزون والجرد',
                          onPressed: () =>
                              context.go('/inventory/${row.product.id}'),
                        ),
                      ),
                    ],
                  ),
              ],
              totalRows: results.total,
              page: vm.page,
              pageSize: 10,
              onPageChanged: vm.go,
              emptyTitle: 'لا توجد منتجات مطابقة',
              emptyMessage: 'أضف منتجات مخزنية أو غيّر البحث والتصفية.',
            ),
          ),
        ],
      ),
    ),
  );
}
