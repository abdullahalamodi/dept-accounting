import '../../../core/data/database_task.dart';
import '../../../core/data/query_page.dart';
import 'overview_repository.dart';

typedef OverviewSnapshot = ({
  List<OverviewDay> activity,
  List<OverviewInvoice> invoices,
  QueryPage<OverviewStock> stock,
});

abstract final class OverviewTasks {
  static DatabaseTask<OverviewSnapshot> snapshot(int days) => DatabaseTask(
    'overview.snapshot',
    (data) => (
      activity: data.overview.activity(days),
      invoices: data.overview.recentInvoices(),
      stock: data.overview.stockAlerts(),
    ),
  );
}
