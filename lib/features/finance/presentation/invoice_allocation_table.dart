import 'package:flutter/material.dart';

import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../invoices/data/invoice_summary.dart';

class InvoiceAllocationTable extends StatelessWidget {
  const InvoiceAllocationTable({
    super.key,
    required this.invoices,
    required this.currency,
    required this.manualMode,
    required this.manual,
    required this.preview,
    required this.onPageChanged,
    required this.onManualChanged,
  });
  final QueryPage<InvoiceSummary> invoices;
  final String currency;
  final bool manualMode;
  final Map<String, String> manual;
  final Map<String, int> preview;
  final ValueChanged<int> onPageChanged;
  final void Function(String id, String value) onManualChanged;

  @override
  Widget build(BuildContext context) => DeptAccountingDataTable(
    minWidth: 520,
    columns: const [
      DataColumn(label: Text('الفاتورة')),
      DataColumn(label: Text('المتبقي')),
      DataColumn(label: Text('التخصيص')),
    ],
    rows: [
      for (final invoice in invoices.items)
        DataRow(
          cells: [
            DataCell(Text(invoice.number)),
            DataCell(
              DeptAccountingAmount(
                Numbers.format(invoice.due),
                currency: currency,
              ),
            ),
            DataCell(
              manualMode
                  ? DeptAccountingField(
                      key: ValueKey(invoice.id),
                      label: 'تخصيص للفاتورة',
                      compact: true,
                      initialValue: manual[invoice.id] ?? '0',
                      numeric: true,
                      onChanged: (value) => onManualChanged(invoice.id, value),
                    )
                  : DeptAccountingAmount(
                      Numbers.format(preview[invoice.id] ?? 0),
                      currency: currency,
                    ),
            ),
          ],
        ),
    ],
    totalRows: invoices.total,
    page: invoices.page,
    pageSize: 5,
    onPageChanged: onPageChanged,
    emptyTitle: 'لا توجد فواتير غير مسددة',
    emptyMessage: 'اختر الطرف أو سجل الدفعة على الرصيد العام.',
  );
}
