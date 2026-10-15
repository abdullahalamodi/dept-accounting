import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'finance_view_model.dart';

class CashAccountDialog extends StatefulWidget {
  const CashAccountDialog({super.key, required this.d});
  final AppDependencies d;

  @override
  State<CashAccountDialog> createState() => _CashAccountDialogState();
}

class _CashAccountDialogState extends State<CashAccountDialog> {
  late final vm = FinanceViewModel(widget.d);
  final name = TextEditingController();

  void save() {
    if (vm.addAccount(name.text)) Navigator.pop(context);
  }

  @override
  void dispose() {
    name.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => AlertDialog(
      title: const Text('إضافة حساب نقدي أو بنكي'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: SectionStack.form(
            children: [
              ErrorNotice(vm.error),
              DeptAccountingField(
                label: 'اسم الحساب',
                controller: name,
                autofocus: true,
                onSubmitted: (_) => save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        DeptAccountingButton(
          label: 'إلغاء',
          variant: DeptAccountingButtonVariant.quiet,
          onPressed: () => Navigator.pop(context),
        ),
        DeptAccountingButton(label: 'إضافة الحساب', onPressed: save),
      ],
    ),
  );
}
