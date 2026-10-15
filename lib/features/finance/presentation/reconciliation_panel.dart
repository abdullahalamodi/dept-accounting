import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'account_actions_view_model.dart';

class ReconciliationPanel extends StatefulWidget {
  const ReconciliationPanel({super.key, required this.d});
  final AppDependencies d;
  @override
  State<ReconciliationPanel> createState() => _ReconciliationPanelState();
}

class _ReconciliationPanelState extends State<ReconciliationPanel> {
  late final vm = AccountActionsViewModel(widget.d);
  final reason = TextEditingController(), counted = TextEditingController();
  String? account;
  @override
  void dispose() {
    vm.dispose();
    reason.dispose();
    counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.d,
          accounts = d.finance.accounts(),
          selected = accounts.firstWhere(
            (a) => a.code == (account ?? accounts.first.code),
          );
      return DeptAccountingPanel(
        title: 'مطابقة الصندوق ومراجعة الافتتاح',
        child: SectionStack.form(
          children: [
            ErrorNotice(vm.error),
            FieldGrid(
              children: [
                ChoiceField(
                  label: 'الحساب',
                  value: selected.code,
                  items: accounts
                      .map((a) => (value: a.code, label: a.name))
                      .toList(),
                  onChanged: (v) => setState(() => account = v),
                ),
                DeptAccountingField(
                  label: 'الرصيد الفعلي',
                  controller: counted,
                  numeric: true,
                ),
                DeptAccountingField(
                  label: 'سبب الفرق / ملاحظة المراجعة',
                  controller: reason,
                ),
              ],
            ),
            Text(
              'الرصيد الدفتري: ${Numbers.format(selected.balance)} ${d.store.shop!.currencyLabel}',
            ),
            DeptAccountingButton(
              label: 'مطابقة وإغلاق الصندوق',
              variant: DeptAccountingButtonVariant.secondary,
              onPressed: () async {
                if (!await showDeptAccountingConfirmation(
                  context,
                  title: 'اعتماد مطابقة الحساب؟',
                  message: 'سيُسجل فرق الرصيد الفعلي كمصروف أو زيادة موثقة. يبقى الحساب متاحًا للعمل بعد المطابقة.',
                  confirmLabel: 'اعتماد',
                )) {
                  return;
                }
                vm.reconcile(selected.code, counted.text, reason.text);
              },
            ),
            if (d.store.setting('opening_closed') != 'true') ...[
              const Divider(),
              Text(
                'رصيد التسوية الافتتاحية: ${Numbers.format(d.engine.balance('3900'))} ${d.store.shop!.currencyLabel}',
              ),
              DeptAccountingButton(
                label: 'اعتماد مراجعة الأرصدة وإقفال الافتتاح',
                variant: DeptAccountingButtonVariant.secondary,
                onPressed: () async {
                  if (!await showDeptAccountingConfirmation(
                    context,
                    title: 'إقفال الأرصدة الافتتاحية؟',
                    message: 'بعد مراجعة الأرصدة، ستُنقل التسوية الافتتاحية إلى رأس المال. الإضافات اللاحقة ستكون بتسويات موثقة.',
                    confirmLabel: 'إقفال الافتتاح',
                  )) {
                    return;
                  }
                  vm.closeOpening(reason.text);
                },
              ),
            ] else
              const DeptAccountingStatusTag(
                'تمت مراجعة وإقفال الافتتاح',
                tone: DeptAccountingTone.success,
              ),
          ],
        ),
      );
    },
  );
}
