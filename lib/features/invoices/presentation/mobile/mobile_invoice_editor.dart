import 'package:flutter/material.dart';

import '../../../../core/numbers.dart';
import '../../../../core/ui/form_widgets.dart';
import '../../../../design_system/dept_accounting_design_system.dart';
import '../../../parties/presentation/party_field.dart';
import '../invoice_summary_panel.dart';
import '../invoice_view_model.dart';

class MobileInvoiceEditor extends StatefulWidget {
  const MobileInvoiceEditor({
    super.key,
    required this.vm,
    required this.title,
    required this.onPick,
    required this.onConfirm,
    required this.onLeave,
    required this.barcode,
    required this.barcodeFocus,
  });
  final InvoiceViewModel vm;
  final String title;
  final VoidCallback onPick;
  final Future<void> Function() onConfirm;
  final Future<void> Function() onLeave;
  final TextEditingController barcode;
  final FocusNode barcodeFocus;

  @override
  State<MobileInvoiceEditor> createState() => _MobileInvoiceEditorState();
}

class _MobileInvoiceEditorState extends State<MobileInvoiceEditor> {
  bool payment = false;
  final messenger = GlobalKey<ScaffoldMessengerState>();
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  void step(bool value) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => payment = value);
    if (scroll.hasClients) scroll.jumpTo(0);
  }

  Future<void> submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await widget.onConfirm();
    if (mounted && widget.vm.error != null && scroll.hasClients) {
      await scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> back() async {
    if (widget.vm.busy) return;
    if (payment) {
      step(false);
    } else {
      await widget.onLeave();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final currency = vm.d.store.shop!.currencyLabel;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          back();
        }
      },
      child: ScaffoldMessenger(
        key: messenger,
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: IconButton(
              tooltip: 'العودة',
              icon: const Icon(Icons.arrow_back),
              onPressed: vm.busy ? null : back,
            ),
            title: Text(
              widget.title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            actions: [
              TextButton(
                onPressed: vm.busy
                    ? null
                    : () async {
                        await vm.saveDraft();
                        if (context.mounted) {
                          messenger.currentState?.showSnackBar(
                            SnackBar(
                              content: Text(
                                vm.draftError ?? 'حُفظت المسودة على الجهاز',
                              ),
                            ),
                          );
                        }
                      },
                child: const Text('حفظ مسودة'),
              ),
            ],
          ),
          bottomNavigationBar:
              MediaQuery.viewInsetsOf(context).bottom > 0 &&
                  MediaQuery.sizeOf(context).height -
                          MediaQuery.viewInsetsOf(context).bottom <
                      400
              ? null
              : SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(DeptAccountingSpace.lg),
                    decoration: const BoxDecoration(
                      color: DeptAccountingColors.surface,
                      border: Border(
                        top: BorderSide(color: DeptAccountingColors.border),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DeptAccountingSummaryLine(
                          label: 'الإجمالي',
                          value: Numbers.format(vm.total),
                          currency: currency,
                          total: true,
                        ),
                        DeptAccountingButton(
                          label: payment
                              ? vm.quick
                                    ? 'اعتماد الاستلام'
                                    : 'اعتماد الفاتورة'
                              : vm.quick
                              ? 'مراجعة الاستلام'
                              : 'متابعة إلى الدفع',
                          loading: vm.busy,
                          onPressed: vm.busy || vm.lines.isEmpty
                              ? null
                              : payment
                              ? submit
                              : () => step(true),
                        ),
                      ],
                    ),
                  ),
                ),
          body: AbsorbPointer(
            absorbing: vm.busy,
            child: SingleChildScrollView(
              controller: scroll,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(DeptAccountingSpace.lg),
              child: SectionStack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: vm.busy ? null : () => step(false),
                          child: Text(
                            '١  المنتجات',
                            style: TextStyle(
                              color: payment
                                  ? DeptAccountingColors.muted
                                  : DeptAccountingColors.primary,
                            ),
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.chevron_left,
                        color: DeptAccountingColors.muted,
                      ),
                      Expanded(
                        child: TextButton(
                          onPressed: vm.busy || vm.lines.isEmpty
                              ? null
                              : () => step(true),
                          child: Text(
                            vm.quick ? '٢  المراجعة' : '٢  الدفع',
                            style: TextStyle(
                              color: payment
                                  ? DeptAccountingColors.primary
                                  : DeptAccountingColors.muted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ?DeptAccountingPageBody.noticeOf(context),
                  if (vm.error != null) ErrorNotice(vm.error),
                  if (vm.draftError != null) ErrorNotice(vm.draftError),
                  if (payment) ...[
                    PartyField(
                      repository: vm.d.parties,
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
                      onChanged: (value) {
                        vm.date = value.toIso8601String();
                        vm.edit();
                      },
                    ),
                    InvoiceSummaryPanel(
                      vm: vm,
                      onConfirm: submit,
                      showConfirm: false,
                    ),
                  ] else ...[
                    if (vm.sale)
                      DeptAccountingField(
                        label: 'بحث بالباركود',
                        hint: 'امسح أو اكتب الباركود ثم Enter',
                        controller: widget.barcode,
                        focusNode: widget.barcodeFocus,
                        suffixIcon: const Icon(Icons.qr_code_scanner),
                        onSubmitted: (value) {
                          if (vm.addBarcode(value)) widget.barcode.clear();
                        },
                      ),
                    if (vm.lines.isEmpty)
                      const DeptAccountingStateView(
                        state: DeptAccountingViewState.empty,
                        title: 'أضف أول منتج',
                        message: 'ابحث عن منتجات محلك ثم عدّل الكمية والسعر.',
                      ),
                    for (final line in vm.lines)
                      DeptAccountingRecordTile(
                        key: ObjectKey(line),
                        title: vm.d.catalog.get(line.productId).name,
                        subtitle:
                            '${line.quantity} ${line.unit} × ${line.price} $currency',
                        leading: Icons.inventory_2_outlined,
                        onTap: () => showDeptAccountingAdaptiveDialog<void>(
                          context: context,
                          builder: (_) =>
                              _InvoiceItemEditor(vm: vm, line: line),
                        ),
                        trailing: Row(
                          children: [
                            const Icon(
                              Icons.edit_outlined,
                              size: 16,
                              color: DeptAccountingColors.muted,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'تعديل البند',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: DeptAccountingColors.muted,
                                ),
                              ),
                            ),
                            Flexible(
                              child: DeptAccountingAmount(
                                _lineTotal(line),
                                currency: currency,
                                emphasized: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (vm.receiptId == null)
                      DeptAccountingButton(
                        label: 'إضافة منتج',
                        icon: Icons.add,
                        variant: DeptAccountingButtonVariant.secondary,
                        onPressed: widget.onPick,
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _lineTotal(InvoiceItemInput line) {
    try {
      return Numbers.format(
        Numbers.ratio(
          Numbers.parse(line.price, emptyAsZero: true),
          Numbers.parse(line.quantity, decimals: 3),
          1000,
        ),
      );
    } on BusinessException {
      return '—';
    }
  }
}

class _InvoiceItemEditor extends StatefulWidget {
  const _InvoiceItemEditor({required this.vm, required this.line});
  final InvoiceViewModel vm;
  final InvoiceItemInput line;
  @override
  State<_InvoiceItemEditor> createState() => _InvoiceItemEditorState();
}

class _InvoiceItemEditorState extends State<_InvoiceItemEditor> {
  late final quantity = TextEditingController(text: widget.line.quantity);
  late final price = TextEditingController(text: widget.line.price);
  late String unit = widget.line.unit;
  String? error;

  @override
  void dispose() {
    quantity.dispose();
    price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm, line = widget.line;
    final product = vm.d.catalog.get(line.productId);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(DeptAccountingSpace.lg),
      child: SectionStack.form(
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          ChoiceField(
            label: 'الوحدة',
            value: unit,
            enabled: vm.receiptId == null,
            items: [
              (value: product.unit, label: product.unit),
              if (product.alternateUnit.isNotEmpty)
                (value: product.alternateUnit, label: product.alternateUnit),
            ],
            onChanged: (value) => setState(() {
              unit = value!;
              price.text = vm.priceForUnit(product, unit);
            }),
          ),
          DeptAccountingField(
            label: 'الكمية',
            numeric: true,
            controller: quantity,
            enabled: vm.receiptId == null,
          ),
          DeptAccountingField(
            label: 'سعر الوحدة',
            numeric: true,
            controller: price,
            enabled:
                vm.d.store.user!.canManage || vm.d.store.user!.canChangePrice,
          ),
          ErrorNotice(error),
          DeptAccountingButton(
            label: 'حفظ البند',
            onPressed: () {
              try {
                if (Numbers.parse(quantity.text, decimals: 3) <= 0 ||
                    Numbers.parse(price.text, emptyAsZero: true) < 0) {
                  throw const BusinessException(
                    'أدخل كمية أكبر من صفر وسعرًا صحيحًا.',
                  );
                }
                line.unit = unit;
                line.quantity = quantity.text;
                line.price = price.text;
                vm.edit();
                Navigator.pop(context);
              } on BusinessException catch (e) {
                setState(() => error = e.message);
              }
            },
          ),
          if (vm.receiptId == null)
            TextButton.icon(
              onPressed: () {
                vm.lines.remove(line);
                vm.edit();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline),
              label: const Text('إزالة البند'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }
}
