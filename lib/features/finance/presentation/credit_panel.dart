import '../data/credit_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'credit_view_model.dart';
import '../data/credit_repository.dart';
import '../../../core/ui/paged_selection_dialog.dart';
import 'invoice_allocation_table.dart';

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
  late var vm = CreditViewModel(
    widget.d,
    partyId: widget.partyId,
    customer: widget.customer,
  );
  String? account;
  @override
  void didUpdateWidget(covariant CreditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.d != widget.d ||
        oldWidget.partyId != widget.partyId ||
        oldWidget.customer != widget.customer) {
      vm.dispose();
      vm = CreditViewModel(
        widget.d,
        partyId: widget.partyId,
        customer: widget.customer,
      );
    }
  }

  final amount = TextEditingController(), reason = TextEditingController();
  @override
  void dispose() {
    vm.dispose();
    amount.dispose();
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.d.store]),
    builder: (context, _) {
      final d = widget.d, currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: widget.d.store,
        task: CreditTasks.context(
          vm.partyId,
          vm.customer,
          vm.sourceId,
          vm.invoicePage,
          vm.automatic,
        ),
        queryKey: (
          vm.partyId,
          vm.customer,
          vm.sourceId,
          vm.invoicePage,
          vm.automatic,
        ),
        builder: (context, data) {
          final selected = data.selected;
          return DeptAccountingPanel(
            title: 'الأرصدة غير المخصصة',
            description: 'تخصيص دفعة موجودة يغيّر ربطها بالفواتير فقط؛ لا يتحرك الصندوق مرة ثانية.',
            child: SectionStack.form(
              children: [
                ErrorNotice(vm.error),
                if (!data.hasSources)
                  const Text('لا يوجد رصيد غير مخصص لهذا الحساب.')
                else ...[
                  DeptAccountingField(
                    key: ValueKey((selected?.id, selected?.available)),
                    label: 'مصدر الرصيد',
                    readOnly: true,
                    initialValue: selected == null
                        ? 'اختر دفعة أو رصيدًا'
                        : '${selected.number} · ${Numbers.format(selected.available)} $currency',
                    suffixIcon: const Icon(Icons.expand_more),
                    onTap: () async {
                      final id = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) =>
                            PagedSelectionDialog<CreditSummary>(
                              title: 'اختيار مصدر الرصيد',
                              searchLabel: 'بحث بالمرجع أو الملاحظات',
                              load: vm.searchSources,
                              columns: const [
                                DataColumn(label: Text('المرجع')),
                                DataColumn(label: Text('المتاح')),
                              ],
                              cells: (source) => [
                                DataCell(Text(source.number)),
                                DataCell(
                                  DeptAccountingAmount(
                                    Numbers.format(source.available),
                                    currency: currency,
                                  ),
                                ),
                              ],
                              onSelected: (source) =>
                                  Navigator.pop(dialogContext, source.id),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, ''),
                                  child: const Text('بدون اختيار'),
                                ),
                              ],
                            ),
                      );
                      if (context.mounted && id != null) {
                        vm.chooseSource(id.isEmpty ? null : id);
                      }
                    },
                  ),
                  if (selected != null) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تلقائي للأقدم أولًا'),
                      value: vm.automatic,
                      onChanged: vm.changeAutomatic,
                    ),
                    InvoiceAllocationTable(
                      invoices: data.invoices,
                      currency: currency,
                      manualMode: !vm.automatic,
                      manual: vm.manual,
                      preview: data.preview,
                      onPageChanged: vm.goInvoices,
                      onManualChanged: vm.changeManual,
                    ),
                    DeptAccountingButton(
                      label: 'اعتماد تخصيص الرصيد',
                      onPressed: () async {
                        if (await vm.allocate(
                              selected.id,
                              data.preview,
                              vm.automatic ? null : vm.manual,
                            ) &&
                            context.mounted) {
                          vm.chooseSource(null);
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
                      DeptAccountingField(
                        label: 'مبلغ الرد',
                        controller: amount,
                        numeric: true,
                      ),
                      ChoiceField(
                        label: 'الحساب النقدي',
                        value: account ?? '',
                        items: [
                          (value: '', label: 'اختر الحساب'),
                          ...data.accounts.map(
                            (a) => (value: a.code, label: a.name),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => account = v == '' ? null : v),
                      ),
                      DeptAccountingField(
                        label: 'سبب الرد',
                        controller: reason,
                      ),
                    ],
                  ),
                  DeptAccountingButton(
                    label: widget.customer
                        ? 'رد رصيد العميل'
                        : 'استرداد رصيد المورد',
                    variant: DeptAccountingButtonVariant.secondary,
                    onPressed: () async {
                      if (await vm.refund(
                            widget.partyId,
                            widget.customer,
                            account,
                            amount.text,
                            reason.text,
                          ) &&
                          context.mounted) {
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
    },
  );
}
