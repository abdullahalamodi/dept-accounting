import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../data/export_service.dart';

class PeriodReportViewModel extends ActionViewModel {
  PeriodReportViewModel(this.d);
  final AppDependencies d;
  String kind = 'profit';
  DateTime from = DateTime(DateTime.now().year, DateTime.now().month),
      through = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
  int page = 1;
  ReportTable get report => d.reports.table(kind, from, through);
  Future<bool> pdf() => run(() => d.exports.savePdf(d.store.shop!, report));
  Future<bool> excel() => run(() => d.exports.saveExcel(d.store.shop!, report));
  Future<bool> printReport() =>
      run(() => d.exports.printReport(d.store.shop!, report));
}

class PeriodReports extends StatefulWidget {
  const PeriodReports({super.key, required this.dependencies});
  final AppDependencies dependencies;
  @override
  State<PeriodReports> createState() => _PeriodReportsState();
}

class _PeriodReportsState extends State<PeriodReports> {
  late final vm = PeriodReportViewModel(widget.dependencies);
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final report = vm.report;
      return DukanPanel(
        title: 'تقارير الفترة والتصدير',
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            FieldGrid(
              children: [
                ChoiceField(
                  label: 'التقرير',
                  value: vm.kind,
                  items: const [
                    (value: 'profit', label: 'الأرباح والخسائر'),
                    (value: 'sales', label: 'المبيعات'),
                    (value: 'purchases', label: 'المشتريات'),
                    (value: 'returns', label: 'المرتجعات'),
                    (value: 'expenses', label: 'المصروفات'),
                    (value: 'stock', label: 'المخزون وقيمته'),
                    (value: 'parties', label: 'أرصدة العملاء والموردين'),
                    (value: 'cash', label: 'حركة النقدية'),
                    (value: 'trial', label: 'ميزان المراجعة'),
                  ],
                  onChanged: (v) {
                    vm.kind = v!;
                    vm.page = 1;
                    vm.changed();
                  },
                ),
                DukanButton(
                  label:
                      '${vm.from.toIso8601String().substring(0, 10)} — ${vm.through.toIso8601String().substring(0, 10)}',
                  variant: DukanButtonVariant.secondary,
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                      initialDateRange: DateTimeRange(
                        start: vm.from,
                        end: vm.through,
                      ),
                    );
                    if (range != null) {
                      vm.from = range.start;
                      vm.through = range.end;
                      vm.page = 1;
                      vm.changed();
                    }
                  },
                ),
              ],
            ),
            Text(report.subtitle),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                DukanButton(
                  label: 'تصدير PDF',
                  loading: vm.busy,
                  onPressed: vm.pdf,
                ),
                DukanButton(
                  label: 'تصدير Excel',
                  variant: DukanButtonVariant.secondary,
                  onPressed: vm.excel,
                ),
                DukanButton(
                  label: 'طباعة',
                  variant: DukanButtonVariant.secondary,
                  onPressed: vm.printReport,
                ),
              ],
            ),
            DukanDataTable(
              columns: report.columns
                  .map((c) => DataColumn(label: Text(c)))
                  .toList(),
              rows: [
                for (final row in report.rows.skip((vm.page - 1) * 10).take(10))
                  DataRow(cells: row.map((v) => DataCell(Text(v))).toList()),
              ],
              totalRows: report.rows.length,
              page: vm.page,
              pageSize: 10,
              onPageChanged: (v) {
                vm.page = v;
                vm.changed();
              },
            ),
            for (final entry in report.summary.entries)
              DukanSummaryLine(
                label: entry.key,
                value: entry.value,
                currency: widget.dependencies.store.shop!.currencyLabel,
                total: true,
              ),
          ],
        ),
      );
    },
  );
}
