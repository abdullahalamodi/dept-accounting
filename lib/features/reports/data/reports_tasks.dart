import 'export_service.dart';
import '../../../core/data/query_page.dart';
import '../../../core/data/database_task.dart';

typedef AccountingSnapshot = ({
  Map<String, int> overview,
  List<Map<String, Object?>> trial,
  QueryPage<Map<String, Object?>> ledger,
});

abstract final class ReportTasks {
  static DatabaseTask<({ReportTable report, int total, int page})> page(
    String kind,
    DateTime from,
    DateTime through, {
    int page = 1,
    int pageSize = 10,
  }) => DatabaseTask(
    'reports.page',
    (context) => context.reports.page(
      kind,
      from,
      through,
      page: page,
      pageSize: pageSize,
    ),
  );
  static DatabaseTask<ReportTable> table(
    String kind,
    DateTime from,
    DateTime through,
  ) => DatabaseTask(
    'reports.table',
    (context) => context.reports.table(kind, from, through),
  );

  static DatabaseTask<AccountingSnapshot> accounting(String? code, int page) =>
      DatabaseTask(
        'reports.accounting',
        (data) => (
          overview: data.reports.overview(),
          trial: data.reports.trialBalance(),
          ledger: code == null
              ? const QueryPage(
                  items: <Map<String, Object?>>[],
                  total: 0,
                  page: 1,
                )
              : data.reports.ledger(code, page: page),
        ),
      );
  static DatabaseTask<List<Map<String, Object?>>> activity(bool enabled) =>
      DatabaseTask(
        'reports.activity',
        (data) => enabled ? data.reports.audit() : <Map<String, Object?>>[],
      );
}
