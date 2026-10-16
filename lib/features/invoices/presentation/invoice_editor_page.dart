import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/ui/paged_selection_dialog.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../parties/presentation/party_field.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'invoice_view_model.dart';
import 'invoice_items_table.dart';
import 'invoice_summary_panel.dart';

class InvoiceEditorPage extends StatefulWidget {
  const InvoiceEditorPage({
    super.key,
    required this.dependencies,
    required this.sale,
    required this.id,
    this.quick = false,
    this.receiptId,
    this.pos = false,
  });
  final AppDependencies dependencies;
  final bool sale, quick, pos;
  final String? receiptId;
  final String id;
  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final barcode = TextEditingController();
  final barcodeFocus = FocusNode();
  late final vm = InvoiceViewModel(
    widget.dependencies,
    sale: widget.sale,
    id: widget.id,
    quick: widget.quick,
    receiptId: widget.receiptId,
  );
  @override
  void dispose() {
    barcode.dispose();
    barcodeFocus.dispose();
    vm.dispose();
    super.dispose();
  }

  Future<void> picker() async {
    await showDialog<void>(
      context: context,
      builder: (context) => _ProductPicker(vm: vm),
    );
  }

  Future<void> confirm() async {
    if (!await showDeptAccountingConfirmation(
      context,
      title: 'اعتماد الفاتورة؟',
      message: 'سيُحدّث المخزون والصندوق وحساب الطرف. الفاتورة المعتمدة لا تُعدّل مباشرة.',
      confirmLabel: 'اعتماد',
    )) {
      return;
    }
    final doc = await vm.post();
    if (doc != null && mounted) {
      context.go('/documents/${doc.id}');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = vm.d,
          path = vm.quick || vm.receiptId != null
              ? '/receiving'
              : vm.sale
              ? '/sales'
              : '/purchases';
      return WorkPage(
        busy: vm.busy,
        title: widget.pos
            ? 'نقطة البيع'
            : vm.quick
            ? 'استلام سريع بتكلفة تقديرية'
            : vm.receiptId != null
            ? 'فاتورة المورد وتسوية تكلفة الاستلام'
            : vm.sale
            ? 'فاتورة بيع جديدة'
            : 'فاتورة شراء جديدة',
        onBack: () async {
          await vm.saveDraft();
          if (context.mounted) context.go(path);
        },
        actions: [
          DeptAccountingButton(
            label: 'حفظ مسودة',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: () async {
              await vm.saveDraft();
              if (context.mounted) {
                showMessage(
                  context,
                  vm.draftError ?? 'حُفظت المسودة على الجهاز',
                );
              }
            },
          ),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            if (vm.sale)
              DeptAccountingPanel(
                child: DeptAccountingField(
                  label: 'إضافة بالباركود — امسح ثم Enter',
                  controller: barcode,
                  focusNode: barcodeFocus,
                  autofocus: widget.pos,
                  onSubmitted: (v) {
                    if (vm.addBarcode(v)) barcode.clear();
                    barcodeFocus.requestFocus();
                  },
                ),
              ),
            if (vm.draftError != null) ErrorNotice(vm.draftError),
            DeptAccountingEditorLayout(
              minFormWidth: 688,
              form: SectionStack(
                children: [
                  DeptAccountingPanel(
                    title: 'بيانات الفاتورة',
                    child: FieldGrid(
                      children: [
                        PartyField(
                          repository: d.parties,
                          customer: vm.sale,
                          label: vm.sale ? 'العميل' : 'المورد',
                          emptyLabel: vm.sale
                              ? 'بدون عميل — نقدي فقط'
                              : 'اختر المورد',
                          enabled: vm.receiptId == null,
                          value: vm.partyId,
                          onChanged: (value) {
                            vm.partyId = value;
                            vm.edit();
                          },
                        ),
                        DeptAccountingDateTimeField(
                          value: DateTime.tryParse(vm.date) ?? DateTime.now(),
                          onChanged: (v) {
                            vm.date = v.toIso8601String();
                            vm.edit();
                          },
                        ),
                      ],
                    ),
                  ),
                  DeptAccountingPanel(
                    title: 'بنود الفاتورة',
                    action: vm.receiptId != null
                        ? null
                        : DeptAccountingButton(
                            label: 'إضافة منتجات وخدمات',
                            variant: DeptAccountingButtonVariant.secondary,
                            onPressed: picker,
                          ),
                    child: InvoiceItemsTable(vm: vm),
                  ),
                ],
              ),
              summary: InvoiceSummaryPanel(vm: vm, onConfirm: confirm),
            ),
          ],
        ),
      );
    },
  );
}

class _ProductPicker extends StatelessWidget {
  const _ProductPicker({required this.vm});
  final InvoiceViewModel vm;
  @override
  Widget build(BuildContext context) => PagedSelectionDialog<CatalogRow>(
    title: 'اختيار المنتجات',
    searchLabel: 'الاسم أو الباركود',
    selectLabel: 'إضافة',
    width: 820,
    minWidth: 600,
    load: (search, page) => vm.searchProducts(search, page),
    columns: const [
      DataColumn(label: Text('المنتج')),
      DataColumn(label: Text('الباركود')),
      DataColumn(label: Text('السعر')),
    ],
    cells: (row) => [
      DataCell(Text(row.product.name)),
      DataCell(Text(row.product.barcode)),
      DataCell(
        DeptAccountingAmount(
          Numbers.format(
            vm.sale ? row.product.salePrice : row.product.purchasePrice,
          ),
          currency: vm.d.store.shop!.currencyLabel,
        ),
      ),
    ],
    onSelected: (row) {
      vm.add(row.product);
      Navigator.pop(context);
    },
  );
}
