import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../../invoices/presentation/invoice_view_model.dart';
import '../../invoices/data/document.dart';
import 'finance_view_model.dart';
import 'reconciliation_panel.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  late final vm = FinanceViewModel(widget.dependencies);
  final name = TextEditingController(), opening = TextEditingController();
  String? openingAccount;
  int page = 1;
  @override
  void dispose() {
    vm.dispose();
    name.dispose();
    opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies,
          currency = d.store.shop!.currencyLabel,
          manage = d.store.user!.canManage;
      final docs = d.finance.documents(), accounts = d.finance.accounts();
      return SectionStack(
        children: [
          DukanPageHeader(
            title: 'الصندوق والمالية',
            description: 'قبض وصرف وتحويلات، بعملة محلك الواحدة',
            actions: [
              DukanButton(
                label: 'عملية مالية جديدة',
                onPressed: () => context.go('/finance/new'),
              ),
            ],
          ),
          ErrorNotice(vm.error),
          FieldGrid(
            runSpacing: DukanSpace.xl,
            children: [
              for (final a in accounts)
                DukanMetricCard(
                  label: a.name,
                  value: '${Numbers.format(a.balance)} $currency',
                  caption: 'الرصيد المتاح',
                ),
            ],
          ),
          if (manage)
            DukanPanel(
              title: 'إعداد الحسابات وأرصدة البداية',
              child: SectionStack.form(
                children: [
                  FieldGrid(
                    children: [
                      DukanField(
                        label: 'اسم حساب نقدي أو بنكي جديد',
                        controller: name,
                      ),
                      DukanButton(
                        label: 'إضافة الحساب',
                        variant: DukanButtonVariant.secondary,
                        onPressed: () {
                          if (vm.addAccount(name.text)) name.clear();
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  FieldGrid(
                    children: [
                      ChoiceField(
                        label: 'حساب الافتتاح',
                        value: openingAccount ?? accounts.first.code,
                        items: accounts
                            .map((a) => (value: a.code, label: a.name))
                            .toList(),
                        onChanged: (v) => setState(() => openingAccount = v),
                      ),
                      DukanField(
                        label: 'الرصيد الافتتاحي',
                        controller: opening,
                        numeric: true,
                      ),
                      DukanButton(
                        label: 'اعتماد رصيد البداية',
                        variant: DukanButtonVariant.secondary,
                        onPressed: () {
                          if (vm.opening(
                            openingAccount ?? accounts.first.code,
                            opening.text,
                          )) {
                            opening.clear();
                            showMessage(context, 'تم اعتماد رصيد البداية');
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          if (manage) ReconciliationPanel(d: d),
          DukanPanel(
            title: 'الحركات المالية',
            padding: EdgeInsets.zero,
            child: DukanDataTable(
              columns: const [
                DataColumn(label: Text('المرجع')),
                DataColumn(label: Text('النوع')),
                DataColumn(label: Text('التاريخ')),
                DataColumn(label: Text('المبلغ')),
                DataColumn(label: Text('البيان')),
              ],
              rows: [
                for (final doc in docs.skip((page - 1) * 10).take(10))
                  DataRow(
                    cells: [
                      DataCell(
                        TextButton(
                          onPressed: () =>
                              context.go('/finance/view/${doc.id}'),
                          child: Text(doc.number),
                        ),
                      ),
                      DataCell(Text(doc.label)),
                      DataCell(Text(doc.date)),
                      DataCell(
                        DukanAmount(
                          Numbers.format(doc.total),
                          currency: currency,
                        ),
                      ),
                      DataCell(Text(doc.notes)),
                    ],
                  ),
              ],
              totalRows: docs.length,
              page: page,
              pageSize: 10,
              onPageChanged: (v) => setState(() => page = v),
            ),
          ),
        ],
      );
    },
  );
}

class FinanceEditorPage extends StatefulWidget {
  const FinanceEditorPage({
    super.key,
    required this.dependencies,
    this.initialKind = 'receipt',
  });
  final AppDependencies dependencies;
  final String initialKind;
  @override
  State<FinanceEditorPage> createState() => _FinanceEditorPageState();
}

class _FinanceEditorPageState extends State<FinanceEditorPage> {
  late final vm = FinanceViewModel(widget.dependencies)
    ..changeKind(widget.initialKind);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = vm.d,
          currency = d.store.shop!.currencyLabel,
          manage = d.store.user!.canManage,
          accounts = d.finance.accounts();
      final parties = d.parties.all().where(
        (p) => p.active && (vm.kind == 'receipt' ? p.customer : p.supplier),
      );
      final outstanding = !vm.voucher || vm.partyId == null
          ? <Document>[]
          : d.invoices
                .list(vm.kind == 'receipt' ? 'sale' : 'purchase')
                .where(
                  (r) => r.partyId == vm.partyId && d.invoices.due(r.id) > 0,
                )
                .toList();
      final preview = vm.safePreview;
      return WorkPage(
        title: 'عملية مالية جديدة',
        onBack: () => context.go('/finance'),
        actions: [
          DukanButton(
            label: 'اعتماد العملية',
            loading: vm.busy,
            onPressed: () async {
              if (!await showDukanConfirmation(
                context,
                title: 'اعتماد العملية المالية؟',
                message: 'تحقق من الحسابات والمبالغ والتخصيص المعروض.',
                confirmLabel: 'اعتماد',
              )) {
                return;
              }
              final doc = await vm.post();
              if (doc != null && context.mounted) {
                context.go('/finance/view/${doc.id}');
              }
            },
          ),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            DukanEditorLayout(
              form: SectionStack(
                children: [
                  DukanPanel(
                    title: 'بيانات العملية',
                    child: FieldGrid(
                      children: [
                        ChoiceField(
                          label: 'نوع العملية',
                          value: vm.kind,
                          items: [
                            (value: 'receipt', label: 'قبض من عميل'),
                            if (manage) ...[
                              (value: 'payment', label: 'سداد مورد'),
                              (value: 'expense', label: 'مصروف'),
                              (value: 'transfer', label: 'تحويل بين الحسابات'),
                              (value: 'capital', label: 'إضافة رأس مال'),
                              (value: 'drawing', label: 'مسحوبات شخصية'),
                            ],
                          ],
                          onChanged: (v) => vm.changeKind(v!),
                        ),
                        if (vm.voucher)
                          ChoiceField(
                            label: 'الطرف',
                            value: vm.partyId ?? '',
                            items: [
                              (value: '', label: 'اختر الطرف'),
                              ...parties.map(
                                (p) => (value: p.id, label: p.name),
                              ),
                            ],
                            onChanged: (v) {
                              vm.partyId = v == '' ? null : v;
                              vm.manual.clear();
                              vm.changed();
                            },
                          ),
                        if (vm.kind == 'expense')
                          DukanField(
                            label: 'تصنيف المصروف',
                            onChanged: (v) {
                              vm.category = v;
                              vm.changed();
                            },
                          ),
                        if (vm.kind == 'transfer')
                          ChoiceField(
                            label: 'الحساب المستلم',
                            value: vm.toAccount ?? '',
                            items: [
                              (value: '', label: 'اختر الحساب'),
                              ...accounts.map(
                                (a) => (value: a.code, label: a.name),
                              ),
                            ],
                            onChanged: (v) {
                              vm.toAccount = v == '' ? null : v;
                              vm.changed();
                            },
                          ),
                        DukanField(
                          label: 'البيان / الملاحظات',
                          onChanged: (v) {
                            vm.notes = v;
                            vm.changed();
                          },
                        ),
                      ],
                    ),
                  ),
                  DukanPanel(
                    title: 'الحسابات والمبالغ',
                    action: DukanButton(
                      label: 'إضافة حساب للدفع',
                      variant: DukanButtonVariant.secondary,
                      onPressed: () {
                        vm.payments.add(
                          PaymentInput(account: accounts.first.code),
                        );
                        vm.changed();
                      },
                    ),
                    child: SectionStack.form(
                      children: [
                        for (final p in vm.payments)
                          FieldGrid(
                            key: ObjectKey(p),
                            minWidth: 180,
                            children: [
                              ChoiceField(
                                label: 'الحساب',
                                value: p.account,
                                items: accounts
                                    .map(
                                      (a) => (
                                        value: a.code,
                                        label:
                                            '${a.name} — ${Numbers.format(a.balance)}',
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) {
                                  p.account = v!;
                                  vm.changed();
                                },
                              ),
                              DukanField(
                                label: 'المبلغ ($currency)',
                                initialValue: p.amount,
                                numeric: true,
                                onChanged: (v) {
                                  p.amount = v;
                                  vm.changed();
                                },
                              ),
                              if (vm.payments.length > 1)
                                TextButton(
                                  onPressed: () {
                                    vm.payments.remove(p);
                                    vm.changed();
                                  },
                                  child: const Text('إزالة'),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  if (vm.voucher)
                    DukanPanel(
                      title: 'تخصيص الدفعة',
                      description:
                          'التخصيص يوزع الدفعة نفسها ولا ينشئ حركة نقدية أخرى.',
                      child: SectionStack.form(
                        children: [
                          ChoiceField(
                            label: 'طريقة التخصيص',
                            value: vm.allocationMode,
                            items: const [
                              (value: 'auto', label: 'تلقائي — الأقدم أولًا'),
                              (value: 'manual', label: 'اختيار يدوي'),
                              (value: 'none', label: 'على الرصيد العام'),
                            ],
                            onChanged: (v) {
                              vm.allocationMode = v!;
                              vm.changed();
                            },
                          ),
                          for (final invoice in outstanding)
                            FieldGrid(
                              children: [
                                Text(
                                  '${invoice.number} · المتبقي ${Numbers.format(d.invoices.due(invoice.id))} $currency',
                                ),
                                if (vm.allocationMode == 'manual')
                                  DukanField(
                                    key: ValueKey(invoice.id),
                                    label: 'تخصيص للفاتورة',
                                    initialValue: vm.manual[invoice.id] ?? '0',
                                    numeric: true,
                                    onChanged: (v) {
                                      vm.manual[invoice.id] = v;
                                      vm.changed();
                                    },
                                  )
                                else
                                  Text(
                                    'التخصيص: ${Numbers.format(preview[invoice.id] ?? 0)} $currency',
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              summary: DukanPanel(
                title: 'ملخص العملية',
                child: SectionStack(
                  children: [
                    DukanSummaryLine(
                      label: 'الإجمالي',
                      value: Numbers.format(vm.total),
                      currency: currency,
                      total: true,
                    ),
                    if (vm.voucher) ...[
                      DukanSummaryLine(
                        label: 'المخصص للفواتير',
                        value: Numbers.format(
                          preview.values.fold<int>(0, (a, b) => a + b),
                        ),
                        currency: currency,
                      ),
                      DukanSummaryLine(
                        label: 'غير مخصص / دفعة مقدمة',
                        value: Numbers.format(
                          vm.total -
                              preview.values.fold<int>(0, (a, b) => a + b),
                        ),
                        currency: currency,
                      ),
                    ],
                    const Text(
                      'سيُرفض الصرف إذا تجاوز الرصيد المتاح للحساب.',
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
