import '../../../core/ui/database_query.dart';
import '../data/reports_tasks.dart';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
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
  Future<ReportTable> get report =>
      d.store.run(ReportTasks.table(kind, from, through));
  Future<bool> pdf() =>
      run(() async => d.exports.savePdf(d.store.shop!, await report));
  Future<bool> excel() =>
      run(() async => d.exports.saveExcel(d.store.shop!, await report));
  Future<bool> printReport() =>
      run(() async => d.exports.printReport(d.store.shop!, await report));
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
      return DatabaseQuery(
        store: vm.d.store,
        task: ReportTasks.page(vm.kind, vm.from, vm.through, page: vm.page),
        queryKey: (vm.kind, vm.from, vm.through, vm.page),
        builder: (context, results) {
          final report = results.report;
          return DeptAccountingPanel(
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
                    DeptAccountingButton(
                      label:
                          '${vm.from.toIso8601String().substring(0, 10)} — ${vm.through.toIso8601String().substring(0, 10)}',
                      variant: DeptAccountingButtonVariant.secondary,
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
                    DeptAccountingButton(
                      label: 'تصدير PDF',
                      loading: vm.busy,
                      onPressed: vm.pdf,
                    ),
                    DeptAccountingButton(
                      label: 'تصدير Excel',
                      variant: DeptAccountingButtonVariant.secondary,
                      onPressed: vm.excel,
                    ),
                    DeptAccountingButton(
                      label: 'طباعة',
                      variant: DeptAccountingButtonVariant.secondary,
                      onPressed: vm.printReport,
                    ),
                  ],
                ),
                DeptAccountingDataTable(
                  columns: report.columns
                      .map((c) => DataColumn(label: Text(c)))
                      .toList(),
                  rows: [
                    for (final row in report.rows)
                      DataRow(
                        cells: row.map((v) => DataCell(Text(v))).toList(),
                      ),
                  ],
                  totalRows: results.total,
                  page: results.page,
                  pageSize: 10,
                  onPageChanged: (v) {
                    vm.page = v;
                    vm.changed();
                  },
                ),
                for (final entry in report.summary.entries)
                  DeptAccountingSummaryLine(
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
    },
  );
}
