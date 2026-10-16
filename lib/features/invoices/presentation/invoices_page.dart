import '../data/invoices_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/date_time.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'invoice_drafts_panel.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({
    super.key,
    required this.dependencies,
    required this.sale,
  });
  final AppDependencies dependencies;
  final bool sale;
  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  String search = '';
  int page = 1;
  @override
  Widget build(BuildContext context) {
    final d = widget.dependencies,
        kind = widget.sale ? 'sale' : 'purchase',
        path = widget.sale ? '/sales' : '/purchases';
    final currency = d.store.shop!.currencyLabel;
    return DatabaseQuery(
      store: d.store,
      task: InvoiceTasks.page(kind, search: search, page: page),
      queryKey: (kind, search, page),
      builder: (context, documents) {
        return SectionStack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DeptAccountingPageHeader(
                  title: widget.sale ? 'المبيعات' : 'المشتريات',
                  description: 'فواتير محفوظة مع أثر المخزون والحسابات',
                  actions: [
                    DeptAccountingButton(
                      label: widget.sale
                          ? 'فاتورة بيع جديدة'
                          : 'فاتورة شراء جديدة',
                      onPressed: () => context.go('$path/new/${d.store.id()}'),
                    ),
                  ],
                ),
                InvoiceDraftsPanel(
                  repository: d.invoices,
                  kind: kind,
                  title: 'مسوداتك المحفوظة',
                  onOpen: (draft) => context.go('$path/new/${draft.id}'),
                ),
              ],
            ),
            DeptAccountingPanel(
              child: DeptAccountingField(
                label: 'بحث برقم الفاتورة أو الملاحظات',
                onChanged: (v) => setState(() {
                  search = v;
                  page = 1;
                }),
              ),
            ),
            DeptAccountingPanel(
              padding: EdgeInsets.zero,
              child: DeptAccountingDataTable(
                columns: const [
                  DataColumn(label: Text('رقم الفاتورة')),
                  DataColumn(label: Text('التاريخ')),
                  DataColumn(label: Text('الطرف')),
                  DataColumn(label: Text('الإجمالي')),
                  DataColumn(label: Text('المتبقي')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (final doc in documents.items)
                    DataRow(
                      cells: [
                        DataCell(Text(doc.number)),
                        DataCell(Text(formatDocumentDateTime(doc.date))),
                        DataCell(
                          Text(
                            doc.partyId == null ? 'بيع نقدي' : doc.partyName,
                          ),
                        ),
                        DataCell(
                          DeptAccountingAmount(
                            Numbers.format(doc.total),
                            currency: currency,
                          ),
                        ),
                        DataCell(
                          DeptAccountingAmount(
                            Numbers.format(doc.due),
                            currency: currency,
                          ),
                        ),
                        DataCell(
                          TextButton(
                            onPressed: () => context.go('$path/view/${doc.id}'),
                            child: const Text('التفاصيل'),
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: documents.total,
                page: documents.page,
                pageSize: 10,
                onPageChanged: (v) => setState(() => page = v),
                emptyTitle: 'لا توجد فواتير',
                emptyMessage:
                    'أنشئ أول فاتورة؛ سيُحدّث المخزون والحسابات عند الاعتماد.',
              ),
            ),
          ],
        );
      },
    );
  }
}
