import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'invoice_view_model.dart';

class InvoiceItemsTable extends StatefulWidget {
  const InvoiceItemsTable({super.key, required this.vm});
  final InvoiceViewModel vm;

  @override
  State<InvoiceItemsTable> createState() => _InvoiceItemsTableState();
}

class _InvoiceItemsTableState extends State<InvoiceItemsTable> {
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  Widget columns(List<Widget> cells) => Row(
    children: [
      Expanded(child: cells[0]),
      for (var i = 1; i < cells.length; i++) ...[
        const SizedBox(width: DeptAccountingSpace.sm),
        SizedBox(
          width: [0.0, 100.0, 76.0, 96.0, 100.0, 36.0][i],
          child: cells[i],
        ),
      ],
    ],
  );

  String lineTotal(InvoiceItemInput line) {
    try {
      return Numbers.format(
        Numbers.ratio(
          Numbers.parse(line.price),
          Numbers.parse(line.quantity, decimals: 3),
          1000,
        ),
      );
    } on BusinessException {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    if (vm.lines.isEmpty) {
      return const DeptAccountingStateView(
        state: DeptAccountingViewState.empty,
        title: 'أضف بنود الفاتورة',
        message: 'ابحث عن المنتج أو امسح الباركود لإضافته.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflow = constraints.maxWidth < 640;
        return Scrollbar(
          controller: scroll,
          thumbVisibility: overflow,
          child: SingleChildScrollView(
            controller: scroll,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.only(
              bottom: overflow ? DeptAccountingSpace.md : 0,
            ),
            child: SizedBox(
              width: math.max(640, constraints.maxWidth),
              child: Column(
                children: [
                  DefaultTextStyle(
                    style: DeptAccountingTypography.tableHeading,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DeptAccountingSpace.sm,
                      ),
                      child: columns([
                        const Text('المنتج / الخدمة'),
                        const Text('الوحدة'),
                        const Text('الكمية'),
                        const Text('سعر الوحدة'),
                        const Text('الإجمالي', textAlign: TextAlign.end),
                        const SizedBox.shrink(),
                      ]),
                    ),
                  ),
                  const Divider(),
                  for (final line in vm.lines)
                    Padding(
                      key: ObjectKey(line),
                      padding: const EdgeInsets.symmetric(
                        vertical: DeptAccountingSpace.sm,
                      ),
                      child: Builder(
                        builder: (context) {
                          final product = vm.d.catalog.get(line.productId);
                          return columns([
                            Tooltip(
                              message: product.name,
                              child: Text(
                                product.name,
                                style: DeptAccountingTypography.tableBody,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Semantics(
                              label: 'وحدة ${product.name}',
                              child: ChoiceField(
                                label: '',
                                compact: true,
                                enabled: vm.receiptId == null,
                                value: line.unit,
                                items: [
                                  (value: product.unit, label: product.unit),
                                  if (product.alternateUnit.isNotEmpty)
                                    (
                                      value: product.alternateUnit,
                                      label: product.alternateUnit,
                                    ),
                                ],
                                onChanged: (value) =>
                                    vm.changeUnit(line, value!),
                              ),
                            ),
                            Semantics(
                              label: 'كمية ${product.name}',
                              child: DeptAccountingField(
                                label: '',
                                compact: true,
                                enabled: vm.receiptId == null,
                                numeric: true,
                                initialValue: line.quantity,
                                onChanged: (value) {
                                  line.quantity = value;
                                  vm.edit();
                                },
                              ),
                            ),
                            Semantics(
                              label: 'سعر ${product.name}',
                              child: DeptAccountingField(
                                key: ValueKey(line.unit),
                                label: '',
                                compact: true,
                                numeric: true,
                                initialValue: line.price,
                                onChanged: (value) {
                                  line.price = value;
                                  vm.edit();
                                },
                              ),
                            ),
                            Text(
                              lineTotal(line),
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.end,
                              style: DeptAccountingTypography.tableBody,
                            ),
                            if (vm.receiptId == null)
                              IconButton(
                                tooltip: 'إزالة ${product.name}',
                                icon: const Icon(Icons.close, size: 16),
                                style: IconButton.styleFrom(
                                  minimumSize: const Size.square(36),
                                  padding: EdgeInsets.zero,
                                  foregroundColor: DeptAccountingColors.muted,
                                ),
                                onPressed: () {
                                  vm.lines.remove(line);
                                  vm.edit();
                                },
                              )
                            else
                              const SizedBox.shrink(),
                          ]);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
