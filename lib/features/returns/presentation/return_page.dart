import '../data/returns_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'return_view_model.dart';

class ReturnPage extends StatefulWidget {
  const ReturnPage({
    super.key,
    required this.dependencies,
    required this.invoiceId,
  });
  final AppDependencies dependencies;
  final String invoiceId;
  @override
  State<ReturnPage> createState() => _ReturnPageState();
}

class _ReturnPageState extends State<ReturnPage> {
  late final vm = ReturnViewModel(widget.dependencies, widget.invoiceId);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = vm.d,
          original = vm.original,
          currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: d.store,
        task: ReturnTasks.context(original),
        queryKey: original.id,
        builder: (context, data) {
          vm.accept(data);
          return WorkPage(
            busy: vm.busy,
            pinDesktopActions: true,
            title: 'مرتجع ${original.number}',
            onBack: () => context.go(
              '/${original.isSale ? 'sales' : 'purchases'}/view/${original.id}',
            ),
            actions: [
              DeptAccountingButton(
                label: 'اعتماد المرتجع',
                loading: vm.busy,
                onPressed: () async {
                  if (!await showDeptAccountingConfirmation(
                    context,
                    title: 'اعتماد المرتجع؟',
                    message: 'سيتم تخفيض غير المسدد أولًا، ثم رد الفائض أو إبقاؤه رصيدًا للطرف.',
                    confirmLabel: 'اعتماد',
                  )) {
                    return;
                  }
                  final result = await vm.post();
                  if (result != null && context.mounted) {
                    context.go('/documents/${result.id}');
                  }
                },
              ),
            ],
            child: SectionStack(
              children: [
                ErrorNotice(vm.error),
                DeptAccountingEditorLayout(
                  form: SectionStack(
                    children: [
                      DeptAccountingPanel(
                        title: 'البنود القابلة للإرجاع',
                        child:
                            MediaQuery.sizeOf(context).width >=
                                DeptAccountingLayout.compact
                            ? _DesktopReturnItems(vm: vm, currency: currency)
                            : SectionStack(
                                children: [
                                  for (
                                    var i = 0;
                                    i < original.lines.length;
                                    i++
                                  )
                                    DeptAccountingPanel(
                                      child: SectionStack.form(
                                        children: [
                                          CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text(original.lines[i].name),
                                            value: vm.inputs[i].selected,
                                            onChanged: (v) {
                                              vm.inputs[i].selected = v!;
                                              vm.changed();
                                            },
                                          ),
                                          Text(
                                            'المتبقي: ${original.lines[i].service ? '${Numbers.format(d.returns.lineValue(original, i) - vm.history.returned[i].value)} $currency' : '${Numbers.format(original.lines[i].quantity - vm.history.returned[i].quantity, decimals: 3)} ${original.lines[i].unit}'}',
                                          ),
                                          if (vm.inputs[i].selected) ...[
                                            if (original.lines[i].service)
                                              DeptAccountingField(
                                                label: 'مبلغ رد الخدمة',
                                                initialValue:
                                                    vm.inputs[i].amount,
                                                numeric: true,
                                                onChanged: (v) {
                                                  vm.inputs[i].amount = v;
                                                  vm.changed();
                                                },
                                              )
                                            else
                                              DeptAccountingField(
                                                label:
                                                    'الكمية المرتجعة (${original.lines[i].unit})',
                                                initialValue:
                                                    vm.inputs[i].quantity,
                                                numeric: true,
                                                onChanged: (v) {
                                                  vm.inputs[i].quantity = v;
                                                  vm.changed();
                                                },
                                              ),
                                            if (original.isSale &&
                                                !original.lines[i].service)
                                              SwitchListTile(
                                                contentPadding: EdgeInsets.zero,
                                                title: const Text(
                                                  'تالف — يُستلم ويُتلف دون إتاحته للبيع',
                                                ),
                                                value: vm.inputs[i].damaged,
                                                onChanged: (v) {
                                                  vm.inputs[i].damaged = v;
                                                  vm.changed();
                                                },
                                              ),
                                          ],
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      DeptAccountingPanel(
                        title: 'سبب المرتجع والرد النقدي',
                        child: SectionStack.form(
                          children: [
                            DeptAccountingField(
                              label: 'سبب المرتجع (إلزامي)',
                              onChanged: (v) {
                                vm.reason = v;
                                vm.changed();
                              },
                            ),
                            ChoiceField(
                              label: 'حساب الرد النقدي',
                              value: vm.account ?? '',
                              items: [
                                (
                                  value: '',
                                  label: 'بدون رد نقدي — رصيد لصالح الطرف',
                                ),
                                ...d.finance.accountOptions().map(
                                  (a) => (value: a.code, label: a.name),
                                ),
                              ],
                              onChanged: (v) {
                                vm.account = v == '' ? null : v;
                                vm.changed();
                              },
                            ),
                            DeptAccountingField(
                              label: 'المبلغ النقدي من الفائض',
                              initialValue: vm.refund,
                              numeric: true,
                              onChanged: (v) {
                                vm.refund = v;
                                vm.changed();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  summary: DeptAccountingPanel(
                    title: 'ملخص المرتجع',
                    child: SectionStack(
                      children: [
                        DeptAccountingSummaryLine(
                          label: 'قيمة المرتجع',
                          value: Numbers.format(vm.total),
                          currency: currency,
                          total: true,
                        ),
                        DeptAccountingSummaryLine(
                          label: 'غير المسدد',
                          value: Numbers.format(data.due),
                          currency: currency,
                        ),
                        DeptAccountingSummaryLine(
                          label: 'الفائض القابل للرد',
                          value: Numbers.format(vm.excess),
                          currency: currency,
                        ),
                        const Text(
                          'المبالغ تراعي الخصومات الأصلية. رد الخدمة لا يحرك المخزون.',
                          style: TextStyle(color: DeptAccountingColors.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DesktopReturnItems extends StatelessWidget {
  const _DesktopReturnItems({required this.vm, required this.currency});
  final ReturnViewModel vm;
  final String currency;

  @override
  Widget build(BuildContext context) => DeptAccountingDataTable(
    minWidth: 620,
    showPagination: false,
    totalRows: vm.original.lines.length,
    page: 1,
    pageSize: vm.original.lines.length.clamp(1, 1 << 30),
    onPageChanged: (_) {},
    columns: [
      const DataColumn(label: Text('البند')),
      const DataColumn(label: Text('المتبقي للإرجاع')),
      const DataColumn(label: Text('الكمية / مبلغ الخدمة')),
      if (vm.original.isSale) const DataColumn(label: Text('تالف')),
    ],
    rows: [
      for (var i = 0; i < vm.original.lines.length; i++)
        DataRow(
          cells: [
            DataCell(
              SizedBox(
                width: 220,
                child: CheckboxListTile(
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    vm.original.lines[i].name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  value: vm.inputs[i].selected,
                  onChanged: (value) {
                    vm.inputs[i].selected = value!;
                    vm.changed();
                  },
                ),
              ),
            ),
            DataCell(
              Text(
                vm.original.lines[i].service
                    ? '${Numbers.format(vm.d.returns.lineValue(vm.original, i) - vm.history.returned[i].value)} $currency'
                    : '${Numbers.format(vm.original.lines[i].quantity - vm.history.returned[i].quantity, decimals: 3)} ${vm.original.lines[i].unit}',
              ),
            ),
            DataCell(
              SizedBox(
                width: 150,
                child: DeptAccountingField(
                  key: ValueKey('return-value-$i'),
                  label: vm.original.lines[i].service
                      ? 'مبلغ رد الخدمة'
                      : 'الكمية المرتجعة',
                  compact: true,
                  numeric: true,
                  enabled: vm.inputs[i].selected,
                  initialValue: vm.original.lines[i].service
                      ? vm.inputs[i].amount
                      : vm.inputs[i].quantity,
                  onChanged: (value) {
                    if (vm.original.lines[i].service) {
                      vm.inputs[i].amount = value;
                    } else {
                      vm.inputs[i].quantity = value;
                    }
                    vm.changed();
                  },
                ),
              ),
            ),
            if (vm.original.isSale)
              DataCell(
                vm.original.lines[i].service
                    ? const Text('—')
                    : Tooltip(
                        message: 'يُستلم ويُتلف دون إتاحته للبيع',
                        child: Checkbox(
                          semanticLabel: 'تالف: ${vm.original.lines[i].name}',
                          value: vm.inputs[i].damaged,
                          onChanged: vm.inputs[i].selected
                              ? (value) {
                                  vm.inputs[i].damaged = value!;
                                  vm.changed();
                                }
                              : null,
                        ),
                      ),
              ),
          ],
        ),
    ],
  );
}
