import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import 'account_actions_view_model.dart';

class CreditPanel extends StatefulWidget {
  const CreditPanel({
    super.key,
    required this.d,
    required this.partyId,
    required this.customer,
  });
  final AppDependencies d;
  final String partyId;
  final bool customer;
  @override
  State<CreditPanel> createState() => _CreditPanelState();
}

class _CreditPanelState extends State<CreditPanel> {
  late final vm = AccountActionsViewModel(widget.d);
  String? sourceId, account;
  bool automatic = true;
  final amount = TextEditingController(), reason = TextEditingController();
  final manual = <String, String>{};
  @override
  void dispose() {
    vm.dispose();
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.d,
          sources = d.credits.sources(widget.partyId, widget.customer),
          currency = d.store.shop!.currencyLabel;
      final selected = sources
          .where((s) => s.document.id == sourceId)
          .firstOrNull;
      final invoices = d.invoices
          .list(widget.customer ? 'sale' : 'purchase')
          .where((i) => i.partyId == widget.partyId && d.invoices.due(i.id) > 0)
          .toList();
      final preview = selected == null
          ? <String, int>{}
          : d.finance.allocationPreview(
              widget.partyId,
              widget.customer,
              selected.available,
            );
      return DukanPanel(
        title: 'الأرصدة غير المخصصة',
        description: 'تخصيص دفعة موجودة يغيّر ربطها بالفواتير فقط؛ لا يتحرك الصندوق مرة ثانية.',
        child: SectionStack.form(
          children: [
            ErrorNotice(vm.error),
            if (sources.isEmpty)
              const Text('لا يوجد رصيد غير مخصص لهذا الحساب.')
            else ...[
              ChoiceField(
                label: 'مصدر الرصيد',
                value: selected?.document.id ?? '',
                items: [
                  (value: '', label: 'اختر دفعة أو رصيدًا'),
                  ...sources.map(
                    (s) => (
                      value: s.document.id,
                      label:
                          '${s.document.number} · ${Numbers.format(s.available)} $currency',
                    ),
                  ),
                ],
                onChanged: (v) => setState(() {
                  sourceId = v == '' ? null : v;
                  manual.clear();
                }),
              ),
              if (selected != null) ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تلقائي للأقدم أولًا'),
                  value: automatic,
                  onChanged: (v) => setState(() => automatic = v),
                ),
                for (final invoice in invoices)
                  FieldGrid(
                    children: [
                      Text(
                        '${invoice.number} · متبقٍ ${Numbers.format(d.invoices.due(invoice.id))} $currency',
                      ),
                      automatic
                          ? Text(
                              'سيخصص ${Numbers.format(preview[invoice.id] ?? 0)} $currency',
                            )
                          : DukanField(
                              key: ValueKey(invoice.id),
                              label: 'التخصيص',
                              initialValue: manual[invoice.id] ?? '0',
                              numeric: true,
                              onChanged: (v) => manual[invoice.id] = v,
                            ),
                    ],
                  ),
                DukanButton(
                  label: 'اعتماد تخصيص الرصيد',
                  onPressed: () {
                    if (vm.allocate(
                      selected.document.id,
                      preview,
                      automatic ? null : manual,
                    )) {
                      setState(() => sourceId = null);
                    }
                  },
                ),
              ],
            ],
            if (d.store.user!.canManage) ...[
              const Divider(),
              const Text('رد الرصيد لصالح الطرف'),
              FieldGrid(
                children: [
                  DukanField(
                    label: 'مبلغ الرد',
                    controller: amount,
                    numeric: true,
                  ),
                  ChoiceField(
                    label: 'الحساب النقدي',
                    value: account ?? '',
                    items: [
                      (value: '', label: 'اختر الحساب'),
                      ...d.finance.accounts().map(
                        (a) => (value: a.code, label: a.name),
                      ),
                    ],
                    onChanged: (v) =>
                        setState(() => account = v == '' ? null : v),
                  ),
                  DukanField(label: 'سبب الرد', controller: reason),
                ],
              ),
              DukanButton(
                label: widget.customer
                    ? 'رد رصيد العميل'
                    : 'استرداد رصيد المورد',
                variant: DukanButtonVariant.secondary,
                onPressed: () {
                  if (vm.refund(
                    widget.partyId,
                    widget.customer,
                    account,
                    amount.text,
                    reason.text,
                  )) {
                    amount.clear();
                    showMessage(context, 'تم اعتماد رد الرصيد');
                  }
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
