import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../catalog/data/product.dart';
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
      builder: (context) => _ProductPicker(
        products: vm.products,
        currency: vm.d.store.shop!.currencyLabel,
        onAdd: vm.add,
        sale: vm.sale,
      ),
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
      final parties = d.parties.all().where(
        (p) => p.active && (vm.sale ? p.customer : p.supplier),
      );
      return WorkPage(
        title: widget.pos
            ? 'نقطة البيع'
            : vm.quick
            ? 'استلام سريع بتكلفة تقديرية'
            : vm.receiptId != null
            ? 'فاتورة المورد وتسوية تكلفة الاستلام'
            : vm.sale
            ? 'فاتورة بيع جديدة'
            : 'فاتورة شراء جديدة',
        onBack: () {
          vm.saveDraft();
          context.go(path);
        },
        actions: [
          DeptAccountingButton(
            label: 'حفظ مسودة',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: () {
              vm.saveDraft();
              showMessage(context, vm.draftError ?? 'حُفظت المسودة على الجهاز');
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
                        ChoiceField(
                          label: vm.sale ? 'العميل' : 'المورد',
                          enabled: vm.receiptId == null,
                          value: vm.partyId ?? '',
                          items: [
                            (
                              value: '',
                              label: vm.sale
                                  ? 'بدون عميل — نقدي فقط'
                                  : 'اختر المورد',
                            ),
                            ...parties.map((p) => (value: p.id, label: p.name)),
                          ],
                          onChanged: (v) {
                            vm.partyId = v == '' ? null : v;
                            vm.edit();
                          },
                        ),
                        DeptAccountingField(
                          label: 'تاريخ الورقة',
                          initialValue: vm.date,
                          hint: 'YYYY-MM-DD',
                          onChanged: (v) {
                            vm.date = v;
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

class _ProductPicker extends StatefulWidget {
  const _ProductPicker({
    required this.products,
    required this.currency,
    required this.onAdd,
    required this.sale,
  });
  final List<Product> products;
  final String currency;
  final ValueChanged<Product> onAdd;
  final bool sale;
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String search = '';
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final products = widget.products
        .where(
          (p) => '${p.name} ${p.barcode}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return AlertDialog(
      title: const Text('اختيار المنتجات'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: SectionStack(
            children: [
              DeptAccountingField(
                label: 'الاسم أو الباركود',
                onChanged: (v) => setState(() {
                  search = v;
                  page = 1;
                }),
              ),
              DeptAccountingDataTable(
                minWidth: 600,
                columns: const [
                  DataColumn(label: Text('المنتج')),
                  DataColumn(label: Text('الباركود')),
                  DataColumn(label: Text('السعر')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (final p in products.skip((page - 1) * 5).take(5))
                    DataRow(
                      cells: [
                        DataCell(Text(p.name)),
                        DataCell(Text(p.barcode)),
                        DataCell(
                          DeptAccountingAmount(
                            Numbers.format(
                              widget.sale ? p.salePrice : p.purchasePrice,
                            ),
                            currency: widget.currency,
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () {
                              widget.onAdd(p);
                              Navigator.pop(context);
                            },
                            child: const Text('إضافة'),
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: products.length,
                page: page,
                pageSize: 5,
                onPageChanged: (v) => setState(() => page = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إغلاق'),
        ),
      ],
    );
  }
}
