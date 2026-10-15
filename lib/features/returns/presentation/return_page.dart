import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
      return WorkPage(
        title: 'مرتجع ${original.number}',
        onBack: () => context.go(
          '/${original.isSale ? 'sales' : 'purchases'}/view/${original.id}',
        ),
        actions: [
          DukanButton(
            label: 'اعتماد المرتجع',
            loading: vm.busy,
            onPressed: () async {
              if (!await showDukanConfirmation(
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
            DukanEditorLayout(
              form: SectionStack(
                children: [
                  DukanPanel(
                    title: 'البنود القابلة للإرجاع',
                    child: SectionStack(
                      children: [
                        for (var i = 0; i < original.lines.length; i++)
                          DukanPanel(
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
                                  'المتبقي: ${original.lines[i].service ? '${Numbers.format(d.returns.lineValue(original, i) - d.returns.alreadyReturned(original.id, i).value)} $currency' : '${Numbers.format(original.lines[i].quantity - d.returns.alreadyReturned(original.id, i).quantity, decimals: 3)} ${original.lines[i].unit}'}',
                                ),
                                if (vm.inputs[i].selected) ...[
                                  if (original.lines[i].service)
                                    DukanField(
                                      label: 'مبلغ رد الخدمة',
                                      initialValue: vm.inputs[i].amount,
                                      numeric: true,
                                      onChanged: (v) {
                                        vm.inputs[i].amount = v;
                                        vm.changed();
                                      },
                                    )
                                  else
                                    DukanField(
                                      label:
                                          'الكمية المرتجعة (${original.lines[i].unit})',
                                      initialValue: vm.inputs[i].quantity,
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
                  DukanPanel(
                    title: 'سبب المرتجع والرد النقدي',
                    child: SectionStack.form(
                      children: [
                        DukanField(
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
                            ...d.finance.accounts().map(
                              (a) => (value: a.code, label: a.name),
                            ),
                          ],
                          onChanged: (v) {
                            vm.account = v == '' ? null : v;
                            vm.changed();
                          },
                        ),
                        DukanField(
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
              summary: DukanPanel(
                title: 'ملخص المرتجع',
                child: SectionStack(
                  children: [
                    DukanSummaryLine(
                      label: 'قيمة المرتجع',
                      value: Numbers.format(vm.total),
                      currency: currency,
                      total: true,
                    ),
                    DukanSummaryLine(
                      label: 'غير المسدد',
                      value: Numbers.format(d.invoices.due(original.id)),
                      currency: currency,
                    ),
                    DukanSummaryLine(
                      label: 'الفائض القابل للرد',
                      value: Numbers.format(vm.excess),
                      currency: currency,
                    ),
                    const Text(
                      'المبالغ تراعي الخصومات الأصلية. رد الخدمة لا يحرك المخزون.',
                      style: TextStyle(color: DukanColors.muted),
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
}
