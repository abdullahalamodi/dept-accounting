import '../data/finance_repository.dart';

import 'package:flutter/material.dart';

import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'finance_view_model.dart';

class OpeningReviewPanel extends StatelessWidget {
  const OpeningReviewPanel({
    super.key,
    required this.vm,
    required this.balances,
    required this.editable,
    required this.equity,
  });
  final FinanceViewModel vm;
  final List<OpeningBalance> balances;
  final Set<String> editable;
  final int equity;

  @override
  Widget build(BuildContext context) {
    final d = vm.d;
    final currency = d.store.shop!.currencyLabel;
    final closed = d.store.setting('opening_closed') == 'true';
    return DeptAccountingPanel(
      title: 'مراجعة أرصدة البداية',
      description: 'تظهر هنا الحسابات التي سُجل لها رصيد افتتاحي. لتعديل مبلغ، اختر الحساب في القسم الأول.',
      child: SectionStack.form(
        children: [
          if (balances.isEmpty)
            const Text(
              'لم تُضف أرصدة بداية بعد. يمكنك إقفال الافتتاح دون رصيد نقدي سابق.',
            )
          else ...[
            for (final balance in balances)
              Row(
                key: ValueKey('opening-${balance.code}'),
                children: [
                  Expanded(child: Text(balance.name)),
                  DeptAccountingAmount(
                    Numbers.format(balance.amount),
                    currency: currency,
                  ),
                  if (!closed) ...[
                    const SizedBox(width: DeptAccountingSpace.lg),
                    DeptAccountingIconButton.table(
                      tooltip: 'إزالة',
                      icon: Icons.close,
                      onPressed: !editable.contains(balance.code)
                          ? null
                          : () async {
                              final confirmed =
                                  await showDeptAccountingConfirmation(
                                    context,
                                    title: 'إزالة رصيد البداية؟',
                                    message:
                                        'سيُزال رصيد بداية ${balance.name} مع الاحتفاظ بسجل التصحيح. يبقى الحساب متاحًا للاستخدام.',
                                    confirmLabel: 'إزالة الرصيد',
                                    destructive: true,
                                  );
                              if (confirmed &&
                                  context.mounted &&
                                  await vm.removeOpening(balance.code) &&
                                  context.mounted) {
                                showMessage(context, 'تمت إزالة رصيد البداية');
                              }
                            },
                    ),
                  ],
                ],
              ),
            const Divider(),
            DeptAccountingSummaryLine(
              label: 'إجمالي أرصدة بداية الحسابات',
              value: Numbers.format(
                balances.fold<int>(0, (sum, a) => sum + a.amount),
              ),
              currency: currency,
              total: true,
            ),
          ],
          if (closed)
            const DeptAccountingStatusTag(
              'تمت مراجعة وإقفال الافتتاح',
              tone: DeptAccountingTone.success,
            )
          else ...[
            Text(
              'رصيد التسوية الافتتاحية: ${Numbers.format(equity)} $currency',
            ),
            const Text(
              'قبل الإقفال، راجع أيضًا المخزون الافتتاحي وأرصدة العملاء والموردين؛ الإقفال يشمل جميع أرصدة البداية.',
            ),
            DeptAccountingButton(
              label: 'اعتماد مراجعة الأرصدة وإقفال الافتتاح',
              variant: DeptAccountingButtonVariant.secondary,
              onPressed: () async {
                final confirmed = await showDeptAccountingConfirmation(
                  context,
                  title: 'إقفال الأرصدة الافتتاحية؟',
                  message: 'تأكد من مراجعة أرصدة الحسابات والمخزون والعملاء والموردين. ستُنقل التسوية الافتتاحية إلى رأس المال ويُقفل إدخال أرصدة البداية. التصحيحات اللاحقة تكون بتسويات موثقة.',
                  confirmLabel: 'إقفال الافتتاح',
                );
                if (confirmed &&
                    context.mounted &&
                    await vm.closeOpening() &&
                    context.mounted) {
                  showMessage(context, 'تمت مراجعة الأرصدة وإقفال الافتتاح');
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}
