import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'account_actions_view_model.dart';

class CashReconciliationDialog extends StatefulWidget {
  const CashReconciliationDialog({super.key, required this.d});
  final AppDependencies d;
  @override
  State<CashReconciliationDialog> createState() =>
      _CashReconciliationDialogState();
}

class _CashReconciliationDialogState extends State<CashReconciliationDialog> {
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
      return AlertDialog(
        title: const Text('مطابقة الصندوق'),
        content: SizedBox(
          width: 720,
          child: SingleChildScrollView(
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
                  label: 'اعتماد المطابقة',
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
                    if (!context.mounted) return;
                    if (vm.reconcile(
                      selected.code,
                      counted.text,
                      reason.text,
                    )) {
                      showMessage(context, 'تم اعتماد مطابقة الحساب');
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          DeptAccountingButton(
            label: 'إغلاق',
            variant: DeptAccountingButtonVariant.quiet,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      );
    },
  );
}
