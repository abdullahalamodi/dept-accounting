import 'package:flutter/material.dart';

import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'invoice_view_model.dart';

class InvoiceSummaryPanel extends StatelessWidget {
  const InvoiceSummaryPanel({
    super.key,
    required this.vm,
    required this.onConfirm,
  });
  final InvoiceViewModel vm;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final currency = vm.d.store.shop!.currencyLabel;
    final accounts = vm.d.finance.accountOptions();
    return DeptAccountingPanel(
      title: 'ملخص الفاتورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DeptAccountingSummaryLine(
            label: 'مجموع البنود',
            value: Numbers.format(vm.subtotal),
            currency: currency,
          ),
          if (!vm.quick && vm.receiptId == null) ...[
            const SizedBox(height: DeptAccountingSpace.sm),
            DeptAccountingField(
              label: 'خصم الفاتورة ($currency)',
              compact: true,
              initialValue: vm.discount,
              numeric: true,
              onChanged: (value) {
                vm.discount = value;
                vm.edit();
              },
            ),
          ],
          if (!vm.sale && !vm.quick) ...[
            const SizedBox(height: DeptAccountingSpace.lg),
            DeptAccountingField(
              label: 'شحن يضاف لتكلفة المنتجات',
              compact: true,
              initialValue: vm.shipping,
              numeric: true,
              onChanged: (value) {
                vm.shipping = value;
                vm.edit();
              },
            ),
          ],
          const SizedBox(height: DeptAccountingSpace.lg),
          const Divider(),
          DeptAccountingSummaryLine(
            label: 'الإجمالي',
            value: Numbers.format(vm.total),
            currency: currency,
            total: true,
          ),
          if (!vm.quick) ...[
            const SizedBox(height: DeptAccountingSpace.lg),
            Text('طريقة الدفع', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: DeptAccountingSpace.md),
            Row(
              children: [
                for (final mode in InvoicePaymentMode.values) ...[
                  if (mode != InvoicePaymentMode.values.first)
                    const SizedBox(width: DeptAccountingSpace.xs),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        textStyle: DeptAccountingTypography.compactControl,
                        backgroundColor: vm.paymentMode == mode
                            ? DeptAccountingColors.primarySoft
                            : null,
                        side: BorderSide(
                          color: vm.paymentMode == mode
                              ? DeptAccountingColors.chartSecondary
                              : DeptAccountingColors.border,
                        ),
                      ),
                      onPressed: () => vm.changePaymentMode(mode),
                      child: Semantics(
                        selected: vm.paymentMode == mode,
                        child: Text(switch (mode) {
                          InvoicePaymentMode.cash => 'نقدي',
                          InvoicePaymentMode.credit => 'آجل',
                          InvoicePaymentMode.partial => 'دفع جزئي',
                        }),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (vm.paymentMode != InvoicePaymentMode.credit) ...[
              const SizedBox(height: DeptAccountingSpace.xl),
              for (final payment
                  in vm.paymentMode == InvoicePaymentMode.cash
                      ? vm.payments.take(1)
                      : vm.payments)
                Padding(
                  key: ObjectKey(payment),
                  padding: const EdgeInsets.only(
                    bottom: DeptAccountingSpace.lg,
                  ),
                  child: Column(
                    children: [
                      ChoiceField(
                        label: 'الحساب',
                        compact: true,
                        value: payment.account,
                        items: accounts
                            .map((a) => (value: a.code, label: a.name))
                            .toList(),
                        onChanged: (value) {
                          payment.account = value!;
                          vm.edit();
                        },
                      ),
                      if (vm.paymentMode == InvoicePaymentMode.partial) ...[
                        const SizedBox(height: DeptAccountingSpace.lg),
                        Row(
                          children: [
                            Expanded(
                              child: DeptAccountingField(
                                label: 'المدفوع ($currency)',
                                compact: true,
                                numeric: true,
                                initialValue: payment.amount,
                                onChanged: (value) {
                                  payment.amount = value;
                                  vm.edit();
                                },
                              ),
                            ),
                            if (vm.payments.length > 1)
                              IconButton(
                                tooltip: 'إزالة الدفعة',
                                onPressed: () {
                                  vm.payments.remove(payment);
                                  vm.edit();
                                },
                                icon: const Icon(Icons.close, size: 16),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              if (vm.paymentMode == InvoicePaymentMode.partial)
                DeptAccountingButton(
                  label: 'إضافة حساب للدفع',
                  variant: DeptAccountingButtonVariant.quiet,
                  onPressed: vm.addPayment,
                ),
            ],
            const SizedBox(height: DeptAccountingSpace.sm),
            DeptAccountingSummaryLine(
              label: 'المدفوع',
              value: Numbers.format(vm.paid),
              currency: currency,
            ),
            DeptAccountingSummaryLine(
              label: vm.sale ? 'المتبقي على العميل' : 'المتبقي للمورد',
              value: Numbers.format(vm.total - vm.paid),
              currency: currency,
            ),
          ],
          const SizedBox(height: DeptAccountingSpace.lg),
          DeptAccountingButton(
            label: vm.quick
                ? 'اعتماد الاستلام'
                : vm.sale
                ? 'اعتماد فاتورة بيع'
                : 'اعتماد فاتورة شراء',
            loading: vm.busy,
            onPressed: onConfirm,
          ),
        ],
      ),
    );
  }
}
