import 'package:flutter/material.dart';

import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';

class DocumentCancellationDialog extends StatefulWidget {
  const DocumentCancellationDialog({
    super.key,
    required this.documentNumber,
    this.allocationsOnly = false,
  });

  final String documentNumber;
  final bool allocationsOnly;

  @override
  State<DocumentCancellationDialog> createState() =>
      _DocumentCancellationDialogState();
}

class _DocumentCancellationDialogState
    extends State<DocumentCancellationDialog> {
  final reason = TextEditingController();
  final formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(
      widget.allocationsOnly ? 'إلغاء تخصيص الفواتير' : 'إلغاء المستند',
    ),
    content: SizedBox(
      width: 450,
      child: Form(
        key: formKey,
        child: SectionStack.form(
          children: [
            Text('المستند: ${widget.documentNumber}'),
            Text(
              widget.allocationsOnly
                  ? 'سيُفك ارتباط هذا السند بالفواتير المخصصة له، وتُحدّث المبالغ المتبقية عليها. يبقى السند وحركته المالية محفوظين.'
                  : 'سيُنشأ مستند عكسي لإلغاء الأثر المحاسبي مع حفظ الأصل. قد تمنع الحركات اللاحقة الإلغاء؛ عندها استخدم المرتجع المرتبط.',
            ),
            DeptAccountingField(
              label: 'سبب الإلغاء',
              controller: reason,
              maxLines: 2,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'أدخل سبب الإلغاء للمتابعة'
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      DeptAccountingButton(
        label: 'تراجع',
        variant: DeptAccountingButtonVariant.secondary,
        onPressed: () => Navigator.pop(context),
      ),
      DeptAccountingButton(
        label: widget.allocationsOnly
            ? 'تأكيد إلغاء التخصيص'
            : 'تأكيد إلغاء المستند',
        variant: DeptAccountingButtonVariant.danger,
        onPressed: () {
          if (formKey.currentState!.validate()) {
            Navigator.pop(context, reason.text.trim());
          }
        },
      ),
    ],
  );
}
