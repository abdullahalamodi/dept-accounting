import '../data/invoices_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/date_time.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'document_view_model.dart';
import 'document_cancellation_dialog.dart';
import 'mobile/mobile_document_item_card.dart';

class DocumentPage extends StatefulWidget {
  const DocumentPage({super.key, required this.dependencies, required this.id});
  final AppDependencies dependencies;
  final String id;
  @override
  State<DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<DocumentPage> {
  late final vm = DocumentViewModel(widget.dependencies, widget.id);
  bool thermal = false;
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies,
          doc = vm.document,
          currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: d.store,
        task: InvoiceTasks.details(widget.id),
        queryKey: widget.id,
        builder: (context, data) {
          return WorkPage(
            busy: vm.busy,
            title: '${doc.label} · ${doc.number}',
            onBack: () => context.go(
              doc.kind == 'sale'
                  ? '/sales'
                  : doc.kind == 'purchase'
                  ? '/purchases'
                  : doc.kind == 'quick_receipt'
                  ? '/receiving'
                  : '/finance',
            ),
            child: SectionStack(
              children: [
                ErrorNotice(vm.error),
                DeptAccountingPanel(
                  padding: const EdgeInsets.all(DeptAccountingSpace.lg),
                  child: DeptAccountingExportToolbar(
                    busy: vm.busy,
                    onPrint: () => vm.printDocument(thermal),
                    onSavePdf: vm.saveDocument,
                    onShare: vm.shareDocument,
                    printOptions: SizedBox(
                      width: 180,
                      child: ChoiceField<bool>(
                        label: 'مقاس الطباعة',
                        value: thermal,
                        enabled: !vm.busy,
                        items: const [
                          (value: false, label: 'ورق B5'),
                          (value: true, label: 'حراري 80 مم'),
                        ],
                        onChanged: (value) => setState(() => thermal = value!),
                      ),
                    ),
                    actions: [
                      if (d.store.user!.canManage &&
                          data.cancelled &&
                          ['sale', 'purchase'].contains(doc.kind))
                        DeptAccountingToolbarAction(
                          label: 'إنشاء نسخة مصححة',
                          icon: Icons.edit_document,
                          onPressed: () async {
                            final draft = await vm.correctionDraft();
                            if (draft != null && context.mounted) {
                              context.go(
                                '/${doc.isSale ? 'sales' : 'purchases'}/new/$draft',
                              );
                            }
                          },
                        ),
                      if (d.store.user!.canManage &&
                          !data.cancelled &&
                          ['sale', 'purchase'].contains(doc.kind))
                        DeptAccountingToolbarAction(
                          label: 'إرجاع منتجات أو خدمة',
                          icon: Icons.assignment_return_outlined,
                          onPressed: () => context.go('/returns/${doc.id}'),
                        ),
                      if (d.store.user!.canManage &&
                          !data.cancelled &&
                          ['receipt', 'payment'].contains(doc.kind))
                        DeptAccountingToolbarAction(
                          label: 'إلغاء تخصيص الفواتير',
                          icon: Icons.link_off_outlined,
                          onPressed: () async {
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (context) => DocumentCancellationDialog(
                                documentNumber: doc.number,
                                allocationsOnly: true,
                              ),
                            );
                            if (reason != null) {
                              await vm.clearAllocations(reason);
                            }
                          },
                        ),
                      if (d.store.user!.canManage &&
                          !data.cancelled &&
                          [
                            'sale',
                            'purchase',
                            'receipt',
                            'payment',
                            'expense',
                            'transfer',
                            'capital',
                            'drawing',
                          ].contains(doc.kind))
                        DeptAccountingToolbarAction(
                          label: 'إلغاء المستند',
                          icon: Icons.cancel_outlined,
                          destructive: true,
                          onPressed: () async {
                            final reason = await showDialog<String>(
                              context: context,
                              builder: (context) => DocumentCancellationDialog(
                                documentNumber: doc.number,
                              ),
                            );
                            if (reason == null) return;
                            final result = await vm.cancel(reason);
                            if (result != null && context.mounted) {
                              context.go('/documents/${result.id}');
                            }
                          },
                        ),
                    ],
                  ),
                ),
                DeptAccountingNotice(
                  title: data.cancelled ? 'ملغى بمستند عكسي' : 'مستند معتمد',
                  message:
                      'التاريخ: ${formatDocumentDateTime(doc.date)} · الاعتماد: ${doc.postedAt.substring(0, 16).replaceAll('T', ' ')} UTC',
                  tone: data.cancelled
                      ? DeptAccountingTone.warning
                      : DeptAccountingTone.success,
                ),
                if (doc.partyId != null)
                  Text('الطرف: ${d.parties.get(doc.partyId!).name}'),
                if (doc.lines.isNotEmpty)
                  DeptAccountingPanel(
                    title: 'البنود المعتمدة',
                    child: DeptAccountingDataTable(
                      compactRowBuilder: (context, index) =>
                          MobileDocumentItemCard(
                            line: doc.lines[index],
                            currency: currency,
                            total:
                                [
                                  'sale_return',
                                  'purchase_return',
                                ].contains(doc.kind)
                                ? doc.extra['returns'][index]['value'] as int
                                : doc.lines[index].total,
                          ),
                      columns: const [
                        DataColumn(label: Text('المنتج')),
                        DataColumn(label: Text('الوحدة')),
                        DataColumn(label: Text('الكمية')),
                        DataColumn(label: Text('السعر')),
                        DataColumn(label: Text('خصم البند')),
                        DataColumn(label: Text('القيمة')),
                      ],
                      rows: [
                        for (var i = 0; i < doc.lines.length; i++)
                          DataRow(
                            cells: [
                              DataCell(Text(doc.lines[i].name)),
                              DataCell(Text(doc.lines[i].unit)),
                              DataCell(
                                Text(
                                  Numbers.format(
                                    doc.lines[i].quantity,
                                    decimals: 3,
                                  ),
                                ),
                              ),
                              DataCell(
                                DeptAccountingAmount(
                                  Numbers.format(doc.lines[i].price),
                                  currency: currency,
                                ),
                              ),
                              DataCell(
                                DeptAccountingAmount(
                                  Numbers.format(doc.lines[i].discount),
                                  currency: currency,
                                ),
                              ),
                              DataCell(
                                DeptAccountingAmount(
                                  Numbers.format(
                                    ([
                                          'sale_return',
                                          'purchase_return',
                                        ].contains(doc.kind)
                                        ? doc.extra['returns'][i]['value']
                                              as int
                                        : doc.lines[i].total),
                                  ),
                                  currency: currency,
                                ),
                              ),
                            ],
                          ),
                      ],
                      totalRows: doc.lines.length,
                      page: 1,
                      pageSize: doc.lines.length,
                      onPageChanged: (_) {},
                    ),
                  ),
                DeptAccountingPanel(
                  title: 'الإجمالي والدفع',
                  padding: const EdgeInsets.symmetric(
                    horizontal: DeptAccountingSpace.xl,
                    vertical: DeptAccountingSpace.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (doc.discount > 0)
                        DeptAccountingSummaryLine(
                          label: 'خصم الفاتورة',
                          value: Numbers.format(doc.discount),
                          currency: currency,
                        ),
                      if (doc.shipping > 0)
                        DeptAccountingSummaryLine(
                          label: 'الشحن المضاف للتكلفة',
                          value: Numbers.format(doc.shipping),
                          currency: currency,
                        ),
                      DeptAccountingSummaryLine(
                        label: 'الإجمالي',
                        value: Numbers.format(doc.total),
                        currency: currency,
                        total: true,
                      ),
                      for (final payment in doc.payments)
                        DeptAccountingSummaryLine(
                          label: d.finance
                              .accountOptions()
                              .firstWhere((a) => a.code == payment.account)
                              .name,
                          value: Numbers.format(payment.amount),
                          currency: currency,
                        ),
                      if (['sale', 'purchase'].contains(doc.kind))
                        DeptAccountingSummaryLine(
                          label: 'المتبقي حاليًا',
                          value: Numbers.format(data.due),
                          currency: currency,
                        ),
                      if (doc.notes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: DeptAccountingSpace.sm,
                          ),
                          child: Text(doc.notes),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
