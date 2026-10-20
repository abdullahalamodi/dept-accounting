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
    this.showConfirm = true,
  });
  final InvoiceViewModel vm;
  final VoidCallback onConfirm;
  final bool showConfirm;

  @override
  Widget build(BuildContext context) {
    final currency = vm.d.store.shop!.currencyLabel;
    final accounts = vm.d.finance.accountOptions();
    return DeptAccountingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('ملخص الفاتورة', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: DeptAccountingSpace.lg),
          DeptAccountingSummaryLine(
            label: 'مجموع البنود',
            value: Numbers.format(vm.subtotal),
            currency: currency,
          ),
          if (!vm.quick && vm.receiptId == null) ...[
            const SizedBox(height: DeptAccountingSpace.sm),
            _SummaryAmountField(
              fieldKey: const ValueKey('invoice-discount'),
              label: 'خصم الفاتورة',
              currency: currency,
              initialValue: vm.discount,
              onChanged: (value) {
                vm.discount = value;
                vm.edit();
              },
            ),
          ],
          if (!vm.sale && !vm.quick) ...[
            const SizedBox(height: DeptAccountingSpace.md),
            _SummaryAmountField(
              label: 'شحن يضاف لتكلفة المنتجات',
              currency: currency,
              initialValue: vm.shipping,
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
                    const SizedBox(width: DeptAccountingSpace.sm),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(
                          0,
                          DeptAccountingLayout.compactControlHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        visualDensity: VisualDensity.standard,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      onPressed: vm.canUsePaymentMode(mode)
                          ? () => vm.changePaymentMode(mode)
                          : null,
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
            if (vm.cashOnly) ...[
              const SizedBox(height: DeptAccountingSpace.sm),
              const Text(
                'اختر عميلًا لتفعيل البيع الآجل أو الدفع الجزئي.',
                style: DeptAccountingTypography.label,
              ),
            ],
            if (vm.paymentMode != InvoicePaymentMode.credit) ...[
              const SizedBox(height: DeptAccountingSpace.lg),
              for (final payment
                  in vm.paymentMode == InvoicePaymentMode.cash
                      ? vm.payments.take(1)
                      : vm.payments)
                Padding(
                  key: ObjectKey(payment),
                  padding: const EdgeInsets.only(
                    bottom: DeptAccountingSpace.formGap,
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
                        const SizedBox(height: DeptAccountingSpace.formGap),
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
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  start: DeptAccountingSpace.sm,
                                ),
                                child: DeptAccountingIconButton(
                                  compact: true,
                                  tooltip: 'إزالة الدفعة',
                                  onPressed: () {
                                    vm.payments.remove(payment);
                                    vm.edit();
                                  },
                                  icon: Icons.close,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              if (vm.paymentMode == InvoicePaymentMode.partial)
                Builder(
                  builder: (context) {
                    final action = DeptAccountingButton(
                      label: 'إضافة حساب للدفع',
                      variant:
                          MediaQuery.sizeOf(context).width <
                              DeptAccountingLayout.compact
                          ? DeptAccountingButtonVariant.primary
                          : DeptAccountingButtonVariant.secondary,
                      compact: true,
                      onPressed: vm.addPayment,
                    );
                    return MediaQuery.sizeOf(context).width <
                            DeptAccountingLayout.compact
                        ? action
                        : Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: action,
                          );
                  },
                ),
            ],
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
          if (showConfirm)
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

class _SummaryAmountField extends StatelessWidget {
  const _SummaryAmountField({
    this.fieldKey,
    required this.label,
    required this.currency,
    required this.initialValue,
    required this.onChanged,
  });

  final Key? fieldKey;
  final String label;
  final String currency;
  final String initialValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(color: DeptAccountingColors.muted),
        ),
      ),
      const SizedBox(width: DeptAccountingSpace.lg),
      SizedBox(
        width: 112,
        child: Semantics(
          label: '$label ($currency)',
          child: DeptAccountingField(
            key: fieldKey,
            label: '',
            hint: '0',
            compact: true,
            numeric: true,
            initialValue: initialValue,
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );
}
