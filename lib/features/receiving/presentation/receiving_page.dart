import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';

class ReceivingPage extends StatelessWidget {
  const ReceivingPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  Widget build(BuildContext context) {
    final d = dependencies,
        docs = d.receiving.pending(),
        finalDrafts = d.invoices.drafts('receipt_invoice'),
        drafts = d.invoices.drafts('quick_receipt'),
        currency = d.store.shop!.currencyLabel;
    return SectionStack(
      children: [
        DukanPageHeader(
          title: 'الاستلام قبل الفاتورة',
          description:
              'استلم البضاعة بتكلفة تقديرية، ثم سوّها عند وصول فاتورة المورد.',
          actions: [
            DukanButton(
              label: 'استلام سريع',
              onPressed: () => context.go('/receiving/new/${d.store.id()}'),
            ),
          ],
        ),
        if (drafts.isNotEmpty)
          DukanPanel(
            title: 'مسودات الاستلام',
            child: Wrap(
              spacing: 12,
              children: [
                for (final draft in drafts)
                  TextButton(
                    onPressed: () =>
                        context.go('/receiving/new/${draft['id']}'),
                    child: Text(
                      'استكمال ${(draft['updated_at'] as String).substring(0, 16)}',
                    ),
                  ),
              ],
            ),
          ),
        if (finalDrafts.isNotEmpty)
          DukanPanel(
            title: 'مسودات فواتير المورد',
            child: Wrap(
              spacing: 12,
              children: [
                for (final draft in finalDrafts)
                  TextButton(
                    onPressed: () => context.go(
                      '/receiving/finalize/${d.invoices.loadDraft(draft['id'] as String)?['receiptId']}/${draft['id']}',
                    ),
                    child: Text(
                      'استكمال ${(draft['updated_at'] as String).substring(0, 16)}',
                    ),
                  ),
              ],
            ),
          ),
        DukanPanel(
          title: 'استلامات تنتظر فاتورة المورد',
          child: DukanDataTable(
            columns: const [
              DataColumn(label: Text('الاستلام')),
              DataColumn(label: Text('المورد')),
              DataColumn(label: Text('التاريخ')),
              DataColumn(label: Text('القيمة التقديرية')),
              DataColumn(label: Text('الإجراء')),
            ],
            rows: [
              for (final doc in docs)
                DataRow(
                  cells: [
                    DataCell(Text(doc.number)),
                    DataCell(Text(d.parties.get(doc.partyId!).name)),
                    DataCell(Text(doc.date)),
                    DataCell(
                      DukanAmount(
                        Numbers.format(doc.total),
                        currency: currency,
                      ),
                    ),
                    DataCell(
                      TextButton(
                        onPressed: () => context.go(
                          '/receiving/finalize/${doc.id}/${d.store.id()}',
                        ),
                        child: const Text('فاتورة المورد وتسوية التكلفة'),
                      ),
                    ),
                  ],
                ),
            ],
            totalRows: docs.length,
            page: 1,
            pageSize: docs.isEmpty ? 1 : docs.length,
            onPageChanged: (_) {},
            emptyTitle: 'لا توجد استلامات معلقة',
            emptyMessage:
                'تظهر هنا البضائع المستلمة التي لم تصل فاتورتها النهائية.',
          ),
        ),
        const DukanNotice(
          title: 'فوتر الاستلام من هذه الشاشة',
          message: 'الاعتماد النهائي يسوي التكلفة وحساب المورد دون تكرار الكمية. يبقى كل مستند سابق وتكلفته الأصلية محفوظين.',
          tone: DukanTone.info,
        ),
      ],
    );
  }
}
