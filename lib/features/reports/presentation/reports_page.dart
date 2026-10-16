import '../data/reports_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'period_reports.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String? code;
  int page = 1;
  @override
  Widget build(BuildContext context) {
    return DatabaseQuery(
      store: widget.dependencies.store,
      task: ReportTasks.accounting(code, page),
      queryKey: (code, page),
      builder: (context, data) {
        final d = widget.dependencies,
            currency = d.store.shop!.currencyLabel,
            trial = data.trial,
            m = data.overview,
            ledger = data.ledger;
        final debit = trial.fold<int>(0, (n, r) => n + (r['debit'] as int)),
            credit = trial.fold<int>(0, (n, r) => n + (r['credit'] as int));
        return SectionStack(
          children: [
            const DeptAccountingPageHeader(
              title: 'التقارير والمحاسبة',
              description: 'نتائج تراكمية من القيود المعتمدة · بعملة المحل',
            ),
            PeriodReports(dependencies: d),
            FieldGrid(
              runSpacing: DeptAccountingSpace.xl,
              children: [
                for (final (key, label) in [
                  ('sales', 'الإيرادات'),
                  ('services', 'منها إيرادات خدمات'),
                  ('cost', 'تكلفة البضاعة المباعة'),
                  ('expenses', 'المصروفات والتالف'),
                  ('profit', 'صافي النتيجة'),
                ])
                  DeptAccountingMetricCard(
                    label: label,
                    value: '${Numbers.format(m[key]!)} $currency',
                    caption: 'من بداية التشغيل',
                  ),
              ],
            ),
            DeptAccountingNotice(
              title: debit == credit
                  ? 'ميزان المراجعة متوازن'
                  : 'يوجد فرق في ميزان المراجعة',
              message:
                  'مدين ${Numbers.format(debit)} · دائن ${Numbers.format(credit)} $currency',
              tone: debit == credit
                  ? DeptAccountingTone.success
                  : DeptAccountingTone.danger,
            ),
            DeptAccountingPanel(
              title: 'ميزان المراجعة',
              child: DeptAccountingDataTable(
                columns: const [
                  DataColumn(label: Text('الحساب')),
                  DataColumn(label: Text('الاسم')),
                  DataColumn(label: Text('حركة مدين')),
                  DataColumn(label: Text('حركة دائن')),
                  DataColumn(label: Text('الرصيد')),
                ],
                rows: [
                  for (final row in trial)
                    DataRow(
                      cells: [
                        DataCell(Text(row['code'] as String)),
                        DataCell(Text(row['name'] as String)),
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
                            Numbers.format(
                              (row['debit'] as int) - (row['credit'] as int),
                            ),
                            currency: currency,
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: trial.length,
                page: 1,
                pageSize: trial.length,
                onPageChanged: (_) {},
              ),
            ),
            DeptAccountingPanel(
              title: 'دفتر الأستاذ',
              child: SectionStack(
                children: [
                  ChoiceField(
                    label: 'اختر الحساب',
                    value: code ?? '',
                    items: [
                      (value: '', label: 'اختر حسابًا'),
                      ...trial.map(
                        (r) => (
                          value: r['code'] as String,
                          label: '${r['code']} · ${r['name']}',
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      code = v == '' ? null : v;
                      page = 1;
                    }),
                  ),
                  DeptAccountingDataTable(
                    columns: const [
                      DataColumn(label: Text('الوقت')),
                      DataColumn(label: Text('المرجع')),
                      DataColumn(label: Text('مدين')),
                      DataColumn(label: Text('دائن')),
                    ],
                    rows: [
                      for (final row in ledger.items)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                (row['posted_at'] as String)
                                    .substring(0, 16)
                                    .replaceAll('T', ' '),
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
                          ],
                        ),
                    ],
                    totalRows: ledger.total,
                    page: ledger.page,
                    pageSize: 10,
                    onPageChanged: (v) => setState(() => page = v),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
