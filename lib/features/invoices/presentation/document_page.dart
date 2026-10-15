import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'document_view_model.dart';

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
      return WorkPage(
        title: '${doc.label} · ${doc.number}',
        actions: [
          if (d.store.user!.canManage &&
              vm.cancelled &&
              ['sale', 'purchase'].contains(doc.kind))
            DeptAccountingButton(
              label: 'إنشاء نسخة مصححة',
              onPressed: () {
                final draft = vm.correctionDraft();
                if (draft != null) {
                  context.go(
                    '/${doc.isSale ? 'sales' : 'purchases'}/new/$draft',
                  );
                }
              },
            ),
          if (d.store.user!.canManage &&
              !vm.cancelled &&
              ['sale', 'purchase'].contains(doc.kind))
            DeptAccountingButton(
              label: 'إرجاع منتجات أو خدمة',
              variant: DeptAccountingButtonVariant.secondary,
              onPressed: () => context.go('/returns/${doc.id}'),
            ),
        ],
        onBack: () => context.go(
          doc.kind == 'sale'
              ? '/sales'
              : doc.kind == 'purchase'
              ? '/purchases'
              : '/finance',
        ),
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            DeptAccountingPanel(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('A4'),
                    selected: !thermal,
                    onSelected: (_) => setState(() => thermal = false),
                  ),
                  ChoiceChip(
                    label: const Text('حراري 80 مم'),
                    selected: thermal,
                    onSelected: (_) => setState(() => thermal = true),
                  ),
                  DeptAccountingButton(
                    label: 'طباعة',
                    loading: vm.busy,
                    onPressed: () => vm.printDocument(thermal),
                  ),
                  DeptAccountingButton(
                    label: 'حفظ PDF',
                    variant: DeptAccountingButtonVariant.secondary,
                    onPressed: vm.saveDocument,
                  ),
                  DeptAccountingButton(
                    label: 'مشاركة',
                    variant: DeptAccountingButtonVariant.secondary,
                    onPressed: vm.shareDocument,
                  ),
                  if (d.store.user!.canManage &&
                      ['receipt', 'payment'].contains(doc.kind))
                    DeptAccountingButton(
                      label: 'إلغاء تخصيص الفواتير',
                      variant: DeptAccountingButtonVariant.secondary,
                      onPressed: () async {
                        final reason = await showDialog<String>(
                          context: context,
                          builder: (context) => const _CancelDialog(),
                        );
                        if (reason != null) vm.clearAllocations(reason);
                      },
                    ),
                  if (d.store.user!.canManage &&
                      !vm.cancelled &&
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
                    DeptAccountingButton(
                      label: 'إلغاء المستند',
                      variant: DeptAccountingButtonVariant.danger,
                      onPressed: () async {
                        final reason = await showDialog<String>(
                          context: context,
                          builder: (context) => const _CancelDialog(),
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
              title: vm.cancelled ? 'ملغى بمستند عكسي' : 'مستند معتمد',
              message:
                  'تاريخ الورقة: ${doc.date} · الاعتماد: ${doc.postedAt.substring(0, 16).replaceAll('T', ' ')} UTC',
              tone: vm.cancelled
                  ? DeptAccountingTone.warning
                  : DeptAccountingTone.success,
            ),
            if (doc.partyId != null)
              Text('الطرف: ${d.parties.get(doc.partyId!).name}'),
            if (doc.lines.isNotEmpty)
              DeptAccountingPanel(
                title: 'البنود المعتمدة',
                child: DeptAccountingDataTable(
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
                                    ? doc.extra['returns'][i]['value'] as int
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
              child: SectionStack(
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
                          .accounts()
                          .firstWhere((a) => a.code == payment.account)
                          .name,
                      value: Numbers.format(payment.amount),
                      currency: currency,
                    ),
                  if (['sale', 'purchase'].contains(doc.kind))
                    DeptAccountingSummaryLine(
                      label: 'المتبقي حاليًا',
                      value: Numbers.format(d.invoices.due(doc.id)),
                      currency: currency,
                    ),
                  if (doc.notes.isNotEmpty) Text(doc.notes),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _CancelDialog extends StatefulWidget {
  const _CancelDialog();
  @override
  State<_CancelDialog> createState() => _CancelDialogState();
}

class _CancelDialogState extends State<_CancelDialog> {
  final reason = TextEditingController();
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('إلغاء المستند'),
    content: SizedBox(
      width: 450,
      child: SectionStack(
        children: [
          const Text(
            'يُنشأ مستند عكسي ويحفظ الأصل. قد تمنع الحركات اللاحقة الإلغاء؛ عندها استخدم المرتجع المرتبط.',
          ),
          DeptAccountingField(label: 'سبب الإلغاء', controller: reason),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('العودة'),
      ),
      DeptAccountingButton(
        label: 'اعتماد الإلغاء',
        variant: DeptAccountingButtonVariant.danger,
        onPressed: () {
          if (reason.text.trim().isNotEmpty) {
            Navigator.pop(context, reason.text.trim());
          }
        },
      ),
    ],
  );
}
