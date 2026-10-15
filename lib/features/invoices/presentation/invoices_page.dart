import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';

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
    final documents = d.invoices
        .list(kind)
        .where(
          (r) => '${r.number} ${r.notes}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    final drafts = d.invoices.drafts(kind),
        currency = d.store.shop!.currencyLabel;
    return SectionStack(
      children: [
        DukanPageHeader(
          title: widget.sale ? 'المبيعات' : 'المشتريات',
          description: 'فواتير محفوظة مع أثر المخزون والحسابات',
          actions: [
            DukanButton(
              label: widget.sale ? 'فاتورة بيع جديدة' : 'فاتورة شراء جديدة',
              onPressed: () => context.go('$path/new/${d.store.id()}'),
            ),
          ],
        ),
        if (drafts.isNotEmpty)
          DukanPanel(
            title: 'مسوداتك المحفوظة',
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                for (final draft in drafts)
                  TextButton(
                    onPressed: () => context.go('$path/new/${draft['id']}'),
                    child: Text(
                      'استكمال ${(draft['updated_at'] as String).substring(0, 16).replaceAll('T', ' ')}',
                    ),
                  ),
              ],
            ),
          ),
        DukanPanel(
          child: DukanField(
            label: 'بحث برقم الفاتورة أو الملاحظات',
            onChanged: (v) => setState(() {
              search = v;
              page = 1;
            }),
          ),
        ),
        DukanPanel(
          padding: EdgeInsets.zero,
          child: DukanDataTable(
            columns: const [
              DataColumn(label: Text('رقم الفاتورة')),
              DataColumn(label: Text('تاريخ الورقة')),
              DataColumn(label: Text('الطرف')),
              DataColumn(label: Text('الإجمالي')),
              DataColumn(label: Text('المتبقي')),
              DataColumn(label: Text('الإجراء')),
            ],
            rows: [
              for (final doc in documents.skip((page - 1) * 10).take(10))
                DataRow(
                  cells: [
                    DataCell(Text(doc.number)),
                    DataCell(Text(doc.date)),
                    DataCell(
                      Text(
                        doc.partyId == null
                            ? 'بيع نقدي'
                            : d.parties.get(doc.partyId!).name,
                      ),
                    ),
                    DataCell(
                      DukanAmount(
                        Numbers.format(doc.total),
                        currency: currency,
                      ),
                    ),
                    DataCell(
                      DukanAmount(
                        Numbers.format(d.invoices.due(doc.id)),
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
            totalRows: documents.length,
            page: page,
            pageSize: 10,
            onPageChanged: (v) => setState(() => page = v),
            emptyTitle: 'لا توجد فواتير',
            emptyMessage:
                'أنشئ أول فاتورة؛ سيُحدّث المخزون والحسابات عند الاعتماد.',
          ),
        ),
      ],
    );
  }
}
