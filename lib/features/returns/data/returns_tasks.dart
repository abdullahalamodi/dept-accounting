import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';
import 'returns_repository.dart';

typedef ReturnSnapshot = ({ReturnHistory history, int due});

abstract final class ReturnTasks {
  static DatabaseTask<Document> post({
    required String requestId,
    required String invoiceId,
    required List<ReturnSelection> selected,
    required String reason,
    String? cashAccount,
    int refund = 0,
  }) => DatabaseTask(
    'returns.post',
    (context) => context.returns.post(
      requestId: requestId,
      invoiceId: invoiceId,
      selected: selected,
      reason: reason,
      cashAccount: cashAccount,
      refund: refund,
    ),
  );

  static DatabaseTask<ReturnSnapshot> context(Document original) =>
      DatabaseTask(
        'returns.context',
        (data) => (
          history: data.returns.history(original),
          due: data.invoices.due(original.id),
        ),
      );
}
