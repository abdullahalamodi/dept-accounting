import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../../catalog/data/product.dart';
import 'invoice_view_model.dart';

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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = vm.d,
          currency = d.store.shop!.currencyLabel,
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
          DukanButton(
            label: 'حفظ مسودة',
            variant: DukanButtonVariant.secondary,
            onPressed: () {
              vm.saveDraft();
              showMessage(context, vm.draftError ?? 'حُفظت المسودة على الجهاز');
            },
          ),
          DukanButton(
            label: 'اعتماد الفاتورة',
            loading: vm.busy,
            onPressed: () async {
              if (!await showDukanConfirmation(
                context,
                title: 'اعتماد الفاتورة؟',
                message: 'سيُحدّث المخزون والصندوق وحساب الطرف. الفاتورة المعتمدة لا تُعدّل مباشرة.',
                confirmLabel: 'اعتماد',
              )) {
                return;
              }
              final doc = await vm.post();
              if (doc != null && context.mounted) {
                context.go('/documents/${doc.id}');
              }
            },
          ),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            if (vm.sale)
              DukanPanel(
                child: DukanField(
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
            DukanEditorLayout(
              form: SectionStack(
                children: [
                  DukanPanel(
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
                        DukanField(
                          label: 'تاريخ الورقة',
                          initialValue: vm.date,
                          hint: 'YYYY-MM-DD',
                          onChanged: (v) {
                            vm.date = v;
                            vm.edit();
                          },
                        ),
                        DukanField(
                          label: 'ملاحظات',
                          initialValue: vm.notes,
                          onChanged: (v) {
                            vm.notes = v;
                            vm.edit();
                          },
                        ),
                      ],
                    ),
                  ),
                  DukanPanel(
                    title: 'بنود الفاتورة',
                    action: vm.receiptId != null
                        ? null
                        : DukanButton(
                            label: 'إضافة منتجات وخدمات',
                            variant: DukanButtonVariant.secondary,
                            onPressed: picker,
                          ),
                    child: SectionStack(
                      children: [
                        if (vm.lines.isEmpty)
                          const DukanStateView(
                            state: DukanViewState.empty,
                            title: 'أضف بنود الفاتورة',
                            message: 'ابحث عن المنتج أو امسح الباركود لإضافته.',
                          ),
                        for (final line in vm.lines)
                          DukanPanel(
                            key: ObjectKey(line),
                            padding: const EdgeInsets.all(16),
                            child: SectionStack.form(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        d.catalog.get(line.productId).name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall,
                                      ),
                                    ),
                                    if (vm.receiptId == null)
                                      TextButton(
                                        onPressed: () {
                                          vm.lines.remove(line);
                                          vm.edit();
                                        },
                                        child: const Text('إزالة'),
                                      ),
                                  ],
                                ),
                                FieldGrid(
                                  minWidth: 170,
                                  children: [
                                    ChoiceField(
                                      label: 'الوحدة',
                                      enabled: vm.receiptId == null,
                                      value: line.unit,
                                      items: [
                                        (
                                          value: d.catalog
                                              .get(line.productId)
                                              .unit,
                                          label: d.catalog
                                              .get(line.productId)
                                              .unit,
                                        ),
                                        if (d.catalog
                                            .get(line.productId)
                                            .alternateUnit
                                            .isNotEmpty)
                                          (
                                            value: d.catalog
                                                .get(line.productId)
                                                .alternateUnit,
                                            label: d.catalog
                                                .get(line.productId)
                                                .alternateUnit,
                                          ),
                                      ],
                                      onChanged: (v) => vm.changeUnit(line, v!),
                                    ),
                                    DukanField(
                                      label: 'الكمية',
                                      enabled: vm.receiptId == null,
                                      initialValue: line.quantity,
                                      numeric: true,
                                      onChanged: (v) {
                                        line.quantity = v;
                                        vm.edit();
                                      },
                                    ),
                                    DukanField(
                                      key: ValueKey('${line.unit}-price'),
                                      label: 'سعر الوحدة',
                                      initialValue: line.price,
                                      numeric: true,
                                      onChanged: (v) {
                                        line.price = v;
                                        vm.edit();
                                      },
                                    ),
                                    if (!vm.quick && vm.receiptId == null)
                                      DukanField(
                                        label: 'خصم البند ($currency)',
                                        initialValue: line.discount,
                                        numeric: true,
                                        onChanged: (v) {
                                          line.discount = v;
                                          vm.edit();
                                        },
                                      ),
                                    DukanField(
                                      label: 'وصف البند (اختياري)',
                                      initialValue: line.description,
                                      onChanged: (v) {
                                        line.description = v;
                                        vm.edit();
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!vm.quick)
                    DukanPanel(
                      title: 'الدفعات',
                      description: 'اتركها فارغة للبيع الآجل، أو وزّع المبلغ بين عدة حسابات.',
                      action: DukanButton(
                        label: 'إضافة دفعة',
                        variant: DukanButtonVariant.secondary,
                        onPressed: () {
                          vm.payments.add(
                            PaymentInput(
                              account: d.finance.accounts().first.code,
                            ),
                          );
                          vm.edit();
                        },
                      ),
                      child: SectionStack.form(
                        children: [
                          for (final p in vm.payments)
                            FieldGrid(
                              key: ObjectKey(p),
                              minWidth: 170,
                              children: [
                                ChoiceField(
                                  label: 'الحساب',
                                  value: p.account,
                                  items: d.finance
                                      .accounts()
                                      .map(
                                        (a) => (value: a.code, label: a.name),
                                      )
                                      .toList(),
                                  onChanged: (v) {
                                    p.account = v!;
                                    vm.edit();
                                  },
                                ),
                                DukanField(
                                  label: 'المدفوع ($currency)',
                                  initialValue: p.amount,
                                  numeric: true,
                                  onChanged: (v) {
                                    p.amount = v;
                                    vm.edit();
                                  },
                                ),
                                TextButton(
                                  onPressed: () {
                                    vm.payments.remove(p);
                                    vm.edit();
                                  },
                                  child: const Text('إزالة الدفعة'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              summary: DukanPanel(
                title: 'ملخص الفاتورة',
                child: SectionStack(
                  children: [
                    DukanSummaryLine(
                      label: 'قيمة البنود',
                      value: Numbers.format(vm.subtotal),
                      currency: currency,
                    ),
                    if (!vm.quick && vm.receiptId == null)
                      DukanField(
                        label: 'خصم الفاتورة ($currency)',
                        initialValue: vm.discount,
                        numeric: true,
                        onChanged: (v) {
                          vm.discount = v;
                          vm.edit();
                        },
                      ),
                    if (!vm.sale && !vm.quick)
                      DukanField(
                        label: 'شحن يضاف لتكلفة المنتجات',
                        initialValue: vm.shipping,
                        numeric: true,
                        onChanged: (v) {
                          vm.shipping = v;
                          vm.edit();
                        },
                      ),
                    DukanSummaryLine(
                      label: 'الإجمالي',
                      value: Numbers.format(vm.total),
                      currency: currency,
                      total: true,
                    ),
                    DukanSummaryLine(
                      label: 'المدفوع',
                      value: Numbers.format(vm.paid),
                      currency: currency,
                    ),
                    DukanSummaryLine(
                      label: 'المتبقي',
                      value: Numbers.format(vm.total - vm.paid),
                      currency: currency,
                    ),
                    const Text(
                      'المسودة تحفظ تلقائيًا. تاريخ الورقة مرجعي؛ حركة المخزون والتكلفة تحدث وقت الاعتماد.',
                      style: TextStyle(color: DukanColors.muted),
                    ),
                  ],
                ),
              ),
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
      title: const Text('اختيار الأصناف'),
      content: SizedBox(
        width: 820,
        child: SingleChildScrollView(
          child: SectionStack(
            children: [
              DukanField(
                label: 'الاسم أو الباركود',
                onChanged: (v) => setState(() {
                  search = v;
                  page = 1;
                }),
              ),
              DukanDataTable(
                minWidth: 600,
                columns: const [
                  DataColumn(label: Text('الصنف')),
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
                          DukanAmount(
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
