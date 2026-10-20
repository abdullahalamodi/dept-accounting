import '../data/receiving_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/date_time.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../invoices/presentation/invoice_drafts_panel.dart';
import 'receiving_view_model.dart';

class ReceivingPage extends StatefulWidget {
  const ReceivingPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<ReceivingPage> createState() => _ReceivingPageState();
}

class _ReceivingPageState extends State<ReceivingPage> {
  bool drafts = false;
  late final vm = ReceivingViewModel(widget.dependencies.receiving);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.dependencies.store]),
    builder: (context, _) {
      final d = widget.dependencies, currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: widget.dependencies.store,
        task: ReceivingTasks.pending(page: vm.page),
        queryKey: vm.page,
        builder: (context, docs) {
          final compact =
              MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact;
          return SectionStack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DeptAccountingPageHeader(
                    title: 'الاستلام قبل الفاتورة',
                    description: 'استلم البضاعة بتكلفة تقديرية، ثم سوّها عند وصول فاتورة المورد.',
                    actions: [
                      DeptAccountingButton(
                        label: 'استلام سريع',
                        onPressed: () =>
                            context.go('/receiving/new/${d.store.id()}'),
                      ),
                    ],
                  ),
                  if (!compact)
                    DeptAccountingSectionTabs<bool>(
                      value: drafts,
                      items: const [
                        (value: false, label: 'بانتظار الفاتورة'),
                        (value: true, label: 'المسودات'),
                      ],
                      onChanged: (value) => setState(() => drafts = value),
                    ),
                  if (compact || drafts)
                    InvoiceDraftsPanel(
                      showEmpty: !compact,
                      repository: d.invoices,
                      kind: 'quick_receipt',
                      title: 'مسودات الاستلام',
                      onOpen: (draft) =>
                          context.go('/receiving/new/${draft.id}'),
                    ),
                  if (compact || drafts)
                    InvoiceDraftsPanel(
                      showEmpty: !compact,
                      repository: d.invoices,
                      kind: 'receipt_invoice',
                      title: 'مسودات فواتير المورد',
                      onOpen: (draft) => context.go(
                        '/receiving/finalize/${draft.receiptId}/${draft.id}',
                      ),
                    ),
                ],
              ),
              if (compact || !drafts)
                DeptAccountingPanel(
                  title: 'استلامات تنتظر فاتورة المورد',
                  child: DeptAccountingDataTable(
                    compactRowBuilder: (context, index) {
                      final doc = docs.items[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: DeptAccountingRecordTile(
                          title: doc.number,
                          subtitle:
                              '${doc.partyName} · ${formatDocumentDateTime(doc.date)}',
                          leading: Icons.local_shipping_outlined,
                          onTap: () => context.go(
                            '/receiving/finalize/${doc.id}/${d.store.id()}',
                          ),
                          details: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              DeptAccountingAmount(
                                Numbers.format(doc.total),
                                currency: currency,
                              ),
                              const DeptAccountingStatusTag(
                                'بانتظار فاتورة المورد',
                                tone: DeptAccountingTone.warning,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    columns: const [
                      DataColumn(label: Text('الاستلام')),
                      DataColumn(label: Text('المورد')),
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('القيمة التقديرية')),
                      DataColumn(label: Text('الإجراء')),
                    ],
                    rows: [
                      for (final doc in docs.items)
                        DataRow(
                          cells: [
                            DataCell(Text(doc.number)),
                            DataCell(Text(doc.partyName)),
                            DataCell(Text(formatDocumentDateTime(doc.date))),
                            DataCell(
                              DeptAccountingAmount(
                                Numbers.format(doc.total),
                                currency: currency,
                              ),
                            ),
                            DataCell(
                              DeptAccountingButton.table(
                                onPressed: () => context.go(
                                  '/receiving/finalize/${doc.id}/${d.store.id()}',
                                ),
                                label: 'فاتورة المورد وتسوية التكلفة',
                              ),
                            ),
                          ],
                        ),
                    ],
                    totalRows: docs.total,
                    page: docs.page,
                    pageSize: 10,
                    onPageChanged: vm.go,
                    emptyTitle: 'لا توجد استلامات معلقة',
                    emptyMessage: 'تظهر هنا البضائع المستلمة التي لم تصل فاتورتها النهائية.',
                  ),
                ),
              const DeptAccountingNotice(
                title: 'فوتر الاستلام من هذه الشاشة',
                message: 'الاعتماد النهائي يسوي التكلفة وحساب المورد دون تكرار الكمية. يبقى كل مستند سابق وتكلفته الأصلية محفوظين.',
                tone: DeptAccountingTone.info,
              ),
            ],
          );
        },
      );
    },
  );
}
