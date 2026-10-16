import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';

abstract final class ReconciliationTasks {
  static DatabaseTask<Document> reconcile({
    required String requestId,
    required String account,
    required int counted,
    required String reason,
  }) => DatabaseTask(
    'reconciliation.reconcile',
    (context) => context.reconciliation.reconcile(
      requestId: requestId,
      account: account,
      counted: counted,
      reason: reason,
    ),
  );
  static DatabaseTask<void> closeOpening(String reason) => DatabaseTask(
    'reconciliation.closeOpening',
    (context) => context.reconciliation.closeOpening(reason),
  );
}
