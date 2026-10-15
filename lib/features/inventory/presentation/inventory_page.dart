import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'inventory_view_model.dart';

class InventoryPage extends StatefulWidget {
  const InventoryPage({
    super.key,
    required this.dependencies,
    required this.productId,
  });
  final AppDependencies dependencies;
  final String productId;
  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> {
  late final vm = InventoryViewModel(widget.dependencies, widget.productId);
  final quantity = TextEditingController(),
      cost = TextEditingController(),
      reason = TextEditingController();
  bool damaged = false;
  int page = 1;
  @override
  void dispose() {
    for (final c in [quantity, cost, reason]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = vm.d,
          p = d.catalog.get(vm.productId),
          stock = d.engine.stock(p.id),
          moves = d.inventory.movements(p.id),
          currency = d.store.shop!.currencyLabel;
      return WorkPage(
        title: 'مخزون ${p.name}',
        onBack: () => context.go('/catalog/${p.id}'),
        actions: [
          DeptAccountingButton(
            label: 'PDF',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: () => vm.export(),
          ),
          DeptAccountingButton(
            label: 'Excel',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: () => vm.export(pdf: false),
          ),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            FieldGrid(
              runSpacing: DeptAccountingSpace.xl,
              children: [
                DeptAccountingMetricCard(
                  label: 'الكمية المتاحة',
                  value: Numbers.format(stock.quantity, decimals: 3),
                  caption: p.unit,
                ),
                DeptAccountingMetricCard(
                  label: 'قيمة المخزون',
                  value: '${Numbers.format(stock.value)} $currency',
                  caption: 'التكلفة الدفترية',
                ),
                DeptAccountingMetricCard(
                  label: 'متوسط تكلفة الوحدة',
                  value: Numbers.format(stock.unitCost, decimals: 6),
                  caption: currency,
                ),
              ],
            ),
            DeptAccountingPanel(
              title: 'الجرد والتسوية',
              description: 'أدخل الكمية الفعلية المتبقية؛ الفرق يُسجّل بحركة وقيد مستقلين.',
              child: SectionStack.form(
                children: [
                  FieldGrid(
                    children: [
                      DeptAccountingField(
                        label: 'الكمية الفعلية بعد الجرد / التالف',
                        controller: quantity,
                        numeric: true,
                      ),
                      DeptAccountingField(
                        label: 'تكلفة الوحدات الزائدة (اختياري)',
                        controller: cost,
                        numeric: true,
                      ),
                      DeptAccountingField(
                        label: 'سبب التسوية',
                        controller: reason,
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تسوية تالف'),
                    value: damaged,
                    onChanged: (v) => setState(() => damaged = v),
                  ),
                  DeptAccountingButton(
                    label: 'اعتماد التسوية',
                    onPressed: () async {
                      if (await showDeptAccountingConfirmation(
                            context,
                            title: 'اعتماد تسوية المخزون؟',
                            message: 'سيُحدّث المخزون إلى الكمية الفعلية المدخلة ويُسجّل الفرق.',
                            confirmLabel: 'اعتماد',
                          ) &&
                          mounted) {
                        if (vm.adjust(
                              quantity.text,
                              cost.text,
                              reason.text,
                              damaged,
                            ) &&
                            context.mounted) {
                          showMessage(context, 'تم اعتماد التسوية');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            DeptAccountingPanel(
              title: 'حركة المخزون',
              child: DeptAccountingDataTable(
                columns: const [
                  DataColumn(label: Text('المرجع')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الكمية')),
                  DataColumn(label: Text('القيمة')),
                  DataColumn(label: Text('البيان')),
                ],
                rows: [
                  for (final m in moves.skip((page - 1) * 10).take(10))
                    DataRow(
                      cells: [
                        DataCell(
                          TextButton(
                            onPressed: () =>
                                context.go('/documents/${m['document_id']}'),
                            child: Text(m['number'] as String),
                          ),
                        ),
                        DataCell(
                          Text((m['posted_at'] as String).substring(0, 10)),
                        ),
                        DataCell(
                          Text(
                            Numbers.format(m['quantity'] as int, decimals: 3),
                          ),
                        ),
                        DataCell(
                          DeptAccountingAmount(
                            Numbers.format(m['value'] as int),
                            currency: currency,
                          ),
                        ),
                        DataCell(Text(m['note'] as String)),
                      ],
                    ),
                ],
                totalRows: moves.length,
                page: page,
                pageSize: 10,
                onPageChanged: (v) => setState(() => page = v),
              ),
            ),
          ],
        ),
      );
    },
  );
}
