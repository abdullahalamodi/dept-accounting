import 'package:flutter/material.dart';

import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
    final accounts = vm.d.finance.accounts();
    return DukanPanel(
      title: 'ملخص الفاتورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DukanSummaryLine(
            label: 'مجموع البنود',
            value: Numbers.format(vm.subtotal),
            currency: currency,
          ),
          if (!vm.quick && vm.receiptId == null) ...[
            const SizedBox(height: DukanSpace.sm),
            DukanField(
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
            const SizedBox(height: DukanSpace.lg),
            DukanField(
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
          const SizedBox(height: DukanSpace.lg),
          const Divider(),
          DukanSummaryLine(
            label: 'الإجمالي',
            value: Numbers.format(vm.total),
            currency: currency,
            total: true,
          ),
          if (!vm.quick) ...[
            const SizedBox(height: DukanSpace.lg),
            Text('طريقة الدفع', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: DukanSpace.md),
            Row(
              children: [
                for (final mode in InvoicePaymentMode.values) ...[
                  if (mode != InvoicePaymentMode.values.first)
                    const SizedBox(width: DukanSpace.xs),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 8,
                        ),
                        textStyle: DukanTypography.compactControl,
                        backgroundColor: vm.paymentMode == mode
                            ? DukanColors.primarySoft
                            : null,
                        side: BorderSide(
                          color: vm.paymentMode == mode
                              ? DukanColors.chartSecondary
                              : DukanColors.border,
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
              const SizedBox(height: DukanSpace.xl),
              for (final payment
                  in vm.paymentMode == InvoicePaymentMode.cash
                      ? vm.payments.take(1)
                      : vm.payments)
                Padding(
                  key: ObjectKey(payment),
                  padding: const EdgeInsets.only(bottom: DukanSpace.lg),
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
                        const SizedBox(height: DukanSpace.lg),
                        Row(
                          children: [
                            Expanded(
                              child: DukanField(
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
                DukanButton(
                  label: 'إضافة حساب للدفع',
                  variant: DukanButtonVariant.quiet,
                  onPressed: vm.addPayment,
                ),
            ],
            const SizedBox(height: DukanSpace.sm),
            DukanSummaryLine(
              label: 'المدفوع',
              value: Numbers.format(vm.paid),
              currency: currency,
            ),
            DukanSummaryLine(
              label: vm.sale ? 'المتبقي على العميل' : 'المتبقي للمورد',
              value: Numbers.format(vm.total - vm.paid),
              currency: currency,
            ),
          ],
          const SizedBox(height: DukanSpace.lg),
          DukanButton(
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
