import '../../../core/data/query_page.dart';
import 'receiving_repository.dart';
import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';

abstract final class ReceivingTasks {
  static DatabaseTask<Document> receive({
    required String requestId,
    required String partyId,
    required List<InvoiceLine> lines,
    String notes = '',
    String? date,
  }) => DatabaseTask('receiving.receive', (context) {
    final result = context.receiving.receive(
      requestId: requestId,
      partyId: partyId,
      lines: lines,
      notes: notes,
      date: date,
    );
    context.invoices.deleteDraft(requestId);
    return result;
  });
  static DatabaseTask<Document> finalize({
    required String requestId,
    required String receiptId,
    required List<int> actualPrices,
    required List<Payment> payments,
    int shipping = 0,
    String? date,
    String notes = '',
  }) => DatabaseTask('receiving.finalize', (context) {
    final result = context.receiving.finalize(
      requestId: requestId,
      receiptId: receiptId,
      actualPrices: actualPrices,
      payments: payments,
      shipping: shipping,
      date: date,
      notes: notes,
    );
    context.invoices.deleteDraft(requestId);
    return result;
  });
  static DatabaseTask<QueryPage<PendingReceipt>> pending({
    int page = 1,
    int pageSize = 10,
  }) => DatabaseTask(
    'receiving.pending',
    (context) => context.receiving.pending(page: page, pageSize: pageSize),
  );
}
