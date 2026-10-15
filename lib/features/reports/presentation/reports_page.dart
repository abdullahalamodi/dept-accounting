import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
    final d = widget.dependencies,
        currency = d.store.shop!.currencyLabel,
        trial = d.reports.trialBalance(),
        m = d.reports.overview();
    final debit = trial.fold<int>(0, (n, r) => n + (r['debit'] as int)),
        credit = trial.fold<int>(0, (n, r) => n + (r['credit'] as int));
    final ledger = code == null
        ? <Map<String, Object?>>[]
        : d.reports.ledger(code!);
    return SectionStack(
      children: [
        const DukanPageHeader(
          title: 'التقارير والمحاسبة',
          description: 'نتائج تراكمية من القيود المعتمدة · بعملة المحل',
        ),
        PeriodReports(dependencies: d),
        FieldGrid(
          runSpacing: DukanSpace.xl,
          children: [
            for (final (key, label) in [
              ('sales', 'الإيرادات'),
              ('services', 'منها إيرادات خدمات'),
              ('cost', 'تكلفة البضاعة المباعة'),
              ('expenses', 'المصروفات والتالف'),
              ('profit', 'صافي النتيجة'),
            ])
              DukanMetricCard(
                label: label,
                value: '${Numbers.format(m[key]!)} $currency',
                caption: 'من بداية التشغيل',
              ),
          ],
        ),
        DukanNotice(
          title: debit == credit
              ? 'ميزان المراجعة متوازن'
              : 'يوجد فرق في ميزان المراجعة',
          message:
              'مدين ${Numbers.format(debit)} · دائن ${Numbers.format(credit)} $currency',
          tone: debit == credit ? DukanTone.success : DukanTone.danger,
        ),
        DukanPanel(
          title: 'ميزان المراجعة',
          child: DukanDataTable(
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
                      DukanAmount(
                        Numbers.format(row['debit'] as int),
                        currency: currency,
                      ),
                    ),
                    DataCell(
                      DukanAmount(
                        Numbers.format(row['credit'] as int),
                        currency: currency,
                      ),
                    ),
                    DataCell(
                      DukanAmount(
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
        DukanPanel(
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
              DukanDataTable(
                columns: const [
                  DataColumn(label: Text('الوقت')),
                  DataColumn(label: Text('المرجع')),
                  DataColumn(label: Text('مدين')),
                  DataColumn(label: Text('دائن')),
                ],
                rows: [
                  for (final row in ledger.skip((page - 1) * 10).take(10))
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
                          DukanAmount(
                            Numbers.format(row['debit'] as int),
                            currency: currency,
                          ),
                        ),
                        DataCell(
                          DukanAmount(
                            Numbers.format(row['credit'] as int),
                            currency: currency,
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: ledger.length,
                page: page,
                pageSize: 10,
                onPageChanged: (v) => setState(() => page = v),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
