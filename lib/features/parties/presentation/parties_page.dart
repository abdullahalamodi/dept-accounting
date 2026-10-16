import '../../../core/ui/database_query.dart';
import '../data/parties_tasks.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/party.dart';
import 'party_view_model.dart';
import '../../finance/presentation/credit_panel.dart';

class PartiesPage extends StatefulWidget {
  const PartiesPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<PartiesPage> createState() => _PartiesPageState();
}

class _PartiesPageState extends State<PartiesPage> {
  late final vm = PartyViewModel(
    widget.dependencies.parties,
    exports: widget.dependencies.exports,
  );
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
          manage = d.store.user!.canManage,
          currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: d.store,
        task: PartyTasks.snapshot(vm.search, vm.page, vm.pageSize),
        queryKey: (vm.search, vm.page, vm.pageSize),
        builder: (context, data) {
          final results = data.rows;
          return SectionStack(
            children: [
              DeptAccountingPageHeader(
                title: 'العملاء والموردون',
                description: 'بيانات موحدة لكل طرف، وحساب مستقل لكل دور',
                actions: [
                  DeptAccountingButton(
                    label: 'إضافة طرف',
                    onPressed: () => context.go('/parties/new'),
                  ),
                ],
              ),
              DeptAccountingPanel(
                child: DeptAccountingField(
                  label: 'بحث بالاسم أو الهاتف',
                  onChanged: vm.filter,
                ),
              ),
              DeptAccountingPanel(
                padding: EdgeInsets.zero,
                child: DeptAccountingDataTable(
                  columns: [
                    const DataColumn(label: Text('الاسم')),
                    const DataColumn(label: Text('الهاتف')),
                    const DataColumn(label: Text('التعامل')),
                    const DataColumn(label: Text('رصيد العميل')),
                    if (manage) const DataColumn(label: Text('رصيد المورد')),
                    const DataColumn(label: Text('الإجراء')),
                  ],
                  rows: [
                    for (final p in results.items)
                      DataRow(
                        cells: [
                          DataCell(Text(p.name)),
                          DataCell(Text(p.phone.isEmpty ? '—' : p.phone)),
                          DataCell(
                            Text(
                              [
                                if (p.customer) 'عميل',
                                if (p.supplier) 'مورد',
                              ].join(' / '),
                            ),
                          ),
                          DataCell(
                            p.customer
                                ? DeptAccountingAmount(
                                    Numbers.format(
                                      data.balances[p.id]!.customer,
                                    ),
                                    currency: currency,
                                  )
                                : const Text('—'),
                          ),
                          if (manage)
                            DataCell(
                              p.supplier
                                  ? DeptAccountingAmount(
                                      Numbers.format(
                                        data.balances[p.id]!.supplier,
                                      ),
                                      currency: currency,
                                    )
                                  : const Text('—'),
                            ),
                          DataCell(
                            TextButton(
                              onPressed: () => context.go('/parties/${p.id}'),
                              child: const Text('كشف وبيانات'),
                            ),
                          ),
                        ],
                      ),
                  ],
                  totalRows: results.total,
                  page: results.page,
                  pageSize: vm.pageSize,
                  onPageChanged: (v) {
                    vm.page = v;
                    vm.changed();
                  },
                  onPageSizeChanged: (v) {
                    vm.pageSize = v;
                    vm.page = 1;
                    vm.changed();
                  },
                  emptyTitle: 'لا يوجد أطراف',
                  emptyMessage: 'أضف عميلًا أو موردًا للبدء.',
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class PartyPage extends StatefulWidget {
  const PartyPage({
    super.key,
    required this.dependencies,
    required this.id,
    this.initialSupplier = false,
  });
  final AppDependencies dependencies;
  final String id;
  final bool initialSupplier;
  @override
  State<PartyPage> createState() => _PartyPageState();
}

class _PartyPageState extends State<PartyPage> {
  late final vm = PartyViewModel(
    widget.dependencies.parties,
    exports: widget.dependencies.exports,
  );
  late final Party? party = widget.id == 'new'
      ? null
      : widget.dependencies.parties.find(widget.id);
  late final id = party?.id ?? widget.dependencies.store.id();
  late final name = TextEditingController(text: party?.name),
      phone = TextEditingController(text: party?.phone),
      address = TextEditingController(text: party?.address),
      opening = TextEditingController();
  final adjustment = TextEditingController(),
      adjustmentReason = TextEditingController();
  late bool customer =
          party?.customer ??
          !(widget.initialSupplier &&
              widget.dependencies.store.user!.canManage),
      supplier =
          party?.supplier ??
          (widget.initialSupplier && widget.dependencies.store.user!.canManage),
      active = party?.active ?? true;
  late bool customerStatement = party?.customer ?? true;
  int page = 1;
  @override
  void dispose() {
    for (final c in [
      name,
      phone,
      address,
      opening,
      adjustment,
      adjustmentReason,
    ]) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies,
          manage = d.store.user!.canManage,
          currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: d.store,
        task: PartyTasks.statement(
          id,
          customerStatement,
          page,
          party != null && (party!.customer || manage),
        ),
        queryKey: (id, customerStatement, page, party != null, manage),
        builder: (context, data) {
          final statements = data.rows;
          return WorkPage(
            busy: vm.busy,
            title: party?.name ?? 'طرف جديد',
            onBack: () => context.go('/parties'),
            actions: [
              DeptAccountingButton(
                label: 'حفظ البيانات',
                onPressed: () async {
                  if (await vm.save(
                        Party(
                          id: id,
                          name: name.text.trim(),
                          phone: phone.text.trim(),
                          address: address.text.trim(),
                          customer: customer,
                          supplier: supplier,
                          active: active,
                        ),
                      ) &&
                      context.mounted) {
                    showMessage(context, 'تم حفظ الطرف');
                    context.go('/parties');
                  }
                },
              ),
            ],
            child: SectionStack(
              children: [
                ErrorNotice(vm.error),
                DeptAccountingPanel(
                  title: 'بيانات الطرف',
                  child: SectionStack.form(
                    children: [
                      FieldGrid(
                        children: [
                          DeptAccountingField(
                            label: 'اسم الطرف',
                            controller: name,
                          ),
                          DeptAccountingField(
                            label: 'الهاتف',
                            controller: phone,
                          ),
                          DeptAccountingField(
                            label: 'العنوان',
                            controller: address,
                          ),
                        ],
                      ),
                      Wrap(
                        children: [
                          DeptAccountingFilterChip(
                            label: const Text('عميل'),
                            selected: customer,
                            onSelected: (v) => setState(() => customer = v),
                          ),
                          if (manage) ...[
                            const SizedBox(width: 12),
                            DeptAccountingFilterChip(
                              label: const Text('مورد'),
                              selected: supplier,
                              onSelected: (v) => setState(() => supplier = v),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (party != null && (party!.customer || manage)) ...[
                  DeptAccountingPanel(
                    title: 'كشف الحساب',
                    description: 'الرصيد الموجب مستحق؛ الرصيد السالب دفعة مقدمة لصالح الطرف',
                    child: SectionStack(
                      children: [
                        ChoiceField(
                          label: 'الحساب',
                          value: customerStatement,
                          items: [
                            if (party!.customer)
                              (value: true, label: 'حساب العميل'),
                            if (party!.supplier && manage)
                              (value: false, label: 'حساب المورد'),
                          ],
                          onChanged: (v) => setState(() {
                            customerStatement = v!;
                            page = 1;
                          }),
                        ),
                        DeptAccountingSummaryLine(
                          label: 'الرصيد الحالي',
                          value: Numbers.format(data.balance),
                          currency: currency,
                          total: true,
                        ),
                        DeptAccountingDataTable(
                          columns: const [
                            DataColumn(label: Text('التاريخ')),
                            DataColumn(label: Text('المرجع')),
                            DataColumn(label: Text('مدين')),
                            DataColumn(label: Text('دائن')),
                            DataColumn(label: Text('الرصيد')),
                          ],
                          rows: [
                            for (final row in statements.items)
                              DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      (row['posted_at'] as String).substring(
                                        0,
                                        10,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(row['number'] as String)),
                                  DataCell(
                                    DeptAccountingAmount(
                                      Numbers.format(row['debit'] as int),
                                      currency: currency,
                                    ),
                                  ),
                                  DataCell(
                                    DeptAccountingAmount(
                                      Numbers.format(row['credit'] as int),
                                      currency: currency,
                                    ),
                                  ),
                                  DataCell(
                                    DeptAccountingAmount(
                                      Numbers.format(row['balance'] as int),
                                      currency: currency,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                          totalRows: statements.total,
                          page: statements.page,
                          pageSize: 10,
                          onPageChanged: (v) => setState(() => page = v),
                        ),
                      ],
                    ),
                  ),
                  CreditPanel(
                    key: ValueKey('$id-$customerStatement'),
                    d: d,
                    partyId: id,
                    customer: customerStatement,
                  ),
                  if (manage)
                    DeptAccountingPanel(
                      title: 'تسوية رصيد سابق لبدء البرنامج',
                      description: 'فرق مستقل موثق دون إنشاء فاتورة وهمية. السالب يخفض المستحق أو يزيد الرصيد لصالح الطرف.',
                      child: SectionStack.form(
                        children: [
                          FieldGrid(
                            children: [
                              DeptAccountingField(
                                label: 'فرق الرصيد (موجب أو سالب)',
                                controller: adjustment,
                                numeric: true,
                              ),
                              DeptAccountingField(
                                label: 'سبب التسوية',
                                controller: adjustmentReason,
                              ),
                            ],
                          ),
                          DeptAccountingButton(
                            label: 'اعتماد التسوية',
                            variant: DeptAccountingButtonVariant.secondary,
                            onPressed: () async {
                              if (await vm.adjust(
                                    id,
                                    customerStatement,
                                    adjustment.text,
                                    adjustmentReason.text,
                                  ) &&
                                  context.mounted) {
                                showMessage(context, 'تم اعتماد تسوية الرصيد');
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  if (manage)
                    DeptAccountingPanel(
                      title: 'رصيد افتتاحي لهذا الحساب',
                      description: 'مرة واحدة قبل أول حركة. السالب يعني رصيدًا لصالح الطرف.',
                      child: SectionStack.form(
                        children: [
                          DeptAccountingField(
                            label: 'الرصيد الافتتاحي',
                            controller: opening,
                            numeric: true,
                          ),
                          DeptAccountingButton(
                            label: 'اعتماد الافتتاح',
                            variant: DeptAccountingButtonVariant.secondary,
                            onPressed: () async {
                              if (await vm.opening(
                                    id,
                                    customerStatement,
                                    opening.text,
                                  ) &&
                                  context.mounted) {
                                showMessage(
                                  context,
                                  'تم اعتماد الرصيد الافتتاحي',
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
    },
  );
}
