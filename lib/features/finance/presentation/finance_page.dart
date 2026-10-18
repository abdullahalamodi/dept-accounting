import '../data/finance_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/date_time.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../../invoices/presentation/invoice_view_model.dart';
import 'finance_view_model.dart';
import 'invoice_allocation_table.dart';
import '../../parties/presentation/party_field.dart';
import 'opening_review_panel.dart';
import 'reconciliation_panel.dart';
import 'cash_account_dialog.dart';

class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  bool showOpening = false;
  late final vm = FinanceViewModel(widget.dependencies);
  final opening = TextEditingController();
  bool _openingInitialized = false;

  String? openingAccount;
  int page = 1;
  @override
  void dispose() {
    vm.dispose();
    opening.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.dependencies.store]),
    builder: (context, _) {
      final d = widget.dependencies,
          currency = d.store.shop!.currencyLabel,
          manage = d.store.user!.canManage;
      return DatabaseQuery(
        store: d.store,
        task: FinanceTasks.snapshot(page),
        queryKey: page,
        builder: (context, data) {
          final docs = data.documents, accounts = data.accounts;
          final compact =
              MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact;
          final closed = d.store.setting('opening_closed') == 'true',
              selectedCode = openingAccount ?? accounts.first.code;
          final existing = data.opening
              .where((a) => a.code == selectedCode)
              .firstOrNull;
          final editable = manage && data.editable.contains(selectedCode);
          if (!_openingInitialized) {
            opening.text = existing == null
                ? ''
                : Numbers.input(existing.amount);
            _openingInitialized = true;
          }
          return SectionStack(
            children: [
              DeptAccountingPageHeader(
                title: 'الصندوق والمالية',
                description: 'قبض وصرف وتحويلات، بعملة محلك الواحدة',
                actions: [
                  DeptAccountingButton(
                    label: 'عملية مالية جديدة',
                    onPressed: () => context.go('/finance/new'),
                  ),
                  if (manage)
                    DeptAccountingButton(
                      label: 'مطابقة الصندوق',
                      variant: DeptAccountingButtonVariant.secondary,
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => CashReconciliationDialog(d: d),
                      ),
                    ),
                ],
              ),
              ErrorNotice(vm.error),
              if (compact)
                DeptAccountingPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (final account in accounts)
                        DeptAccountingSummaryLine(
                          label: account.name,
                          value: Numbers.format(account.balance),
                          currency: currency,
                        ),
                    ],
                  ),
                ),
              if (!compact)
                FieldGrid(
                  runSpacing: DeptAccountingSpace.xl,
                  children: [
                    for (final a in accounts)
                      DeptAccountingMetricCard(
                        label: a.name,
                        value: '${Numbers.format(a.balance)} $currency',
                        caption: 'الرصيد المتاح',
                      ),
                  ],
                ),
              if (compact && manage)
                Wrap(
                  spacing: 8,
                  children: [
                    DeptAccountingFilterChip(
                      label: const Text('الحركات'),
                      selected: !showOpening,
                      onSelected: (_) => setState(() => showOpening = false),
                    ),
                    DeptAccountingFilterChip(
                      label: const Text('أرصدة البداية'),
                      selected: showOpening,
                      onSelected: (_) => setState(() => showOpening = true),
                    ),
                  ],
                ),
              if (manage && (!compact || showOpening))
                DeptAccountingPanel(
                  title: 'إعداد الحسابات وأرصدة البداية',
                  action: DeptAccountingButton.table(
                    label: 'إضافة حساب',
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => CashAccountDialog(d: d),
                    ),
                  ),
                  child: SectionStack.form(
                    children: [
                      if (closed)
                        const DeptAccountingStatusTag(
                          'تمت مراجعة وإقفال الافتتاح',
                          tone: DeptAccountingTone.success,
                        )
                      else ...[
                        const Text(
                          'اختر الحساب لإضافة رصيد البداية أو تعديل المبلغ المسجل. الحساب ذو الرصيد الصفري لا يحتاج إلى إضافة.',
                        ),
                        FieldGrid(
                          children: [
                            ChoiceField(
                              label: 'حساب الافتتاح',
                              value: selectedCode,
                              items: accounts
                                  .map((a) => (value: a.code, label: a.name))
                                  .toList(),
                              onChanged: (v) => setState(() {
                                openingAccount = v;
                                final saved = data.opening
                                    .where((a) => a.code == v)
                                    .firstOrNull;
                                opening.text = saved == null
                                    ? ''
                                    : Numbers.input(saved.amount);
                                vm.changed();
                              }),
                            ),
                            DeptAccountingField(
                              label: 'الرصيد الافتتاحي ($currency)',
                              controller: opening,
                              numeric: true,
                              enabled: editable,
                            ),
                            DeptAccountingButton(
                              label: existing == null
                                  ? 'إضافة رصيد البداية'
                                  : 'حفظ تعديل رصيد البداية',
                              variant: DeptAccountingButtonVariant.secondary,
                              onPressed: !editable
                                  ? null
                                  : () async {
                                      if (await vm.opening(
                                            selectedCode,
                                            opening.text,
                                          ) &&
                                          context.mounted) {
                                        showMessage(
                                          context,
                                          'تم حفظ رصيد البداية',
                                        );
                                      }
                                    },
                            ),
                          ],
                        ),
                        if (!editable)
                          const Text(
                            'بدأت حركة هذا الحساب؛ استخدم عملية مالية أو مطابقة موثقة لتصحيح الرصيد.',
                          ),
                      ],
                    ],
                  ),
                ),
              if (manage && (!compact || showOpening))
                OpeningReviewPanel(
                  vm: vm,
                  balances: data.opening,
                  editable: data.editable,
                  equity: data.openingEquity,
                ),
              if (!compact || !showOpening)
                DeptAccountingPanel(
                  title: 'الحركات المالية',
                  padding: EdgeInsets.zero,
                  child: DeptAccountingDataTable(
                    compactRowBuilder: (context, index) {
                      final doc = docs.items[index];
                      return Padding(
                        padding: const EdgeInsets.all(8),
                        child: DeptAccountingRecordTile(
                          title: '${doc.label} · ${doc.number}',
                          subtitle: formatDocumentDateTime(doc.date),
                          leading: Icons.account_balance_wallet_outlined,
                          onTap: () => context.go('/finance/view/${doc.id}'),
                          details: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (doc.notes.isNotEmpty) Text(doc.notes),
                              DeptAccountingAmount(
                                Numbers.format(doc.total),
                                currency: currency,
                                emphasized: true,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    columns: const [
                      DataColumn(label: Text('المرجع')),
                      DataColumn(label: Text('النوع')),
                      DataColumn(label: Text('التاريخ')),
                      DataColumn(label: Text('المبلغ')),
                      DataColumn(label: Text('البيان')),
                    ],
                    rows: [
                      for (final doc in docs.items)
                        DataRow(
                          cells: [
                            DataCell(
                              DeptAccountingButton.table(
                                onPressed: () =>
                                    context.go('/finance/view/${doc.id}'),
                                label: doc.number,
                              ),
                            ),
                            DataCell(Text(doc.label)),
                            DataCell(Text(formatDocumentDateTime(doc.date))),
                            DataCell(
                              DeptAccountingAmount(
                                Numbers.format(doc.total),
                                currency: currency,
                              ),
                            ),
                            DataCell(Text(doc.notes)),
                          ],
                        ),
                    ],
                    totalRows: docs.total,
                    page: docs.page,
                    pageSize: 10,
                    onPageChanged: (v) => setState(() => page = v),
                  ),
                ),
            ],
          );
        },
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
          manage = d.store.user!.canManage;
      return DatabaseQuery(
        store: d.store,
        task: FinanceTasks.voucher(
          vm.voucher ? vm.partyId : null,
          vm.kind == 'receipt',
          vm.total,
          vm.invoicePage,
          vm.allocationMode == 'auto',
        ),
        queryKey: (
          vm.partyId,
          vm.kind,
          vm.total,
          vm.invoicePage,
          vm.allocationMode,
        ),
        builder: (context, data) {
          final accounts = data.accounts;
          final outstanding = data.invoices,
              preview = vm.allocationMode == 'auto'
                  ? data.preview
                  : vm.safePreview;
          return WorkPage(
            busy: vm.busy,
            title: 'عملية مالية جديدة',
            onBack: () => context.go('/finance'),
            actions: [
              DeptAccountingButton(
                label: 'اعتماد العملية',
                loading: vm.busy,
                onPressed: () async {
                  if (!await showDeptAccountingConfirmation(
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
                DeptAccountingEditorLayout(
                  form: SectionStack(
                    children: [
                      DeptAccountingPanel(
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
                                  (
                                    value: 'transfer',
                                    label: 'تحويل بين الحسابات',
                                  ),
                                  (value: 'capital', label: 'إضافة رأس مال'),
                                  (value: 'drawing', label: 'مسحوبات شخصية'),
                                ],
                              ],
                              onChanged: (v) => vm.changeKind(v!),
                            ),
                            if (vm.voucher)
                              PartyField(
                                repository: d.parties,
                                customer: vm.kind == 'receipt',
                                label: 'الطرف',
                                emptyLabel: 'اختر الطرف',
                                value: vm.partyId,
                                onChanged: vm.changeParty,
                              ),
                            if (vm.kind == 'expense')
                              DeptAccountingField(
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
                            DeptAccountingField(
                              label: 'البيان / الملاحظات',
                              onChanged: (v) {
                                vm.notes = v;
                                vm.changed();
                              },
                            ),
                          ],
                        ),
                      ),
                      DeptAccountingPanel(
                        title: 'الحسابات والمبالغ',
                        action: DeptAccountingButton.table(
                          label: 'إضافة حساب للدفع',
                          onPressed: () async {
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
                                    compact: true,
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
                                  DeptAccountingField(
                                    label: 'المبلغ ($currency)',
                                    compact: true,
                                    initialValue: p.amount,
                                    numeric: true,
                                    onChanged: (v) {
                                      p.amount = v;
                                      vm.changed();
                                    },
                                  ),
                                  if (vm.payments.length > 1)
                                    DeptAccountingIconButton.table(
                                      onPressed: () async {
                                        vm.payments.remove(p);
                                        vm.changed();
                                      },
                                      tooltip: 'إزالة الدفعة',
                                      icon: Icons.close,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      if (vm.voucher)
                        DeptAccountingPanel(
                          title: 'تخصيص الدفعة',
                          description: 'التخصيص يوزع الدفعة نفسها ولا ينشئ حركة نقدية أخرى.',
                          child: SectionStack.form(
                            children: [
                              ChoiceField(
                                label: 'طريقة التخصيص',
                                value: vm.allocationMode,
                                items: const [
                                  (
                                    value: 'auto',
                                    label: 'تلقائي — الأقدم أولًا',
                                  ),
                                  (value: 'manual', label: 'اختيار يدوي'),
                                  (value: 'none', label: 'على الرصيد العام'),
                                ],
                                onChanged: (v) {
                                  vm.allocationMode = v!;
                                  vm.changed();
                                },
                              ),
                              InvoiceAllocationTable(
                                invoices: outstanding,
                                currency: currency,
                                manualMode: vm.allocationMode == 'manual',
                                manual: vm.manual,
                                preview: preview,
                                onPageChanged: vm.goInvoices,
                                onManualChanged: (id, value) {
                                  vm.manual[id] = value;
                                  vm.changed();
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  summary: DeptAccountingPanel(
                    title: 'ملخص العملية',
                    child: SectionStack(
                      children: [
                        DeptAccountingSummaryLine(
                          label: 'الإجمالي',
                          value: Numbers.format(vm.total),
                          currency: currency,
                          total: true,
                        ),
                        if (vm.voucher) ...[
                          DeptAccountingSummaryLine(
                            label: 'المخصص للفواتير',
                            value: Numbers.format(
                              preview.values.fold<int>(0, (a, b) => a + b),
                            ),
                            currency: currency,
                          ),
                          DeptAccountingSummaryLine(
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
                          style: TextStyle(color: DeptAccountingColors.muted),
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
    },
  );
}
