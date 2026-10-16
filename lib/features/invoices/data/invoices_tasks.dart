import '../../reports/data/export_service.dart';
import 'invoice_summary.dart';
import 'invoice_repository.dart';
import '../../../core/data/query_page.dart';
import 'document.dart';
import '../../../core/data/database_task.dart';

typedef DocumentSnapshot = ({Document document, int due, bool cancelled});

abstract final class InvoiceTasks {
  static DatabaseTask<Document> post({
    required String requestId,
    required bool sale,
    required List<InvoiceLine> lines,
    required List<Payment> payments,
    String? partyId,
    int discount = 0,
    int shipping = 0,
    String notes = '',
    String? date,
    String? correctionOf,
  }) => DatabaseTask('invoices.post', (data) {
    final result = data.invoices.post(
      requestId: requestId,
      sale: sale,
      lines: lines,
      payments: payments,
      partyId: partyId,
      discount: discount,
      shipping: shipping,
      notes: notes,
      date: date,
      correctionOf: correctionOf,
    );
    data.invoices.deleteDraft(requestId);
    return result;
  });
  static DatabaseTask<String> correctionDraft(String id) => DatabaseTask(
    'invoices.correctionDraft',
    (data) => data.invoices.correctionDraft(id),
  );

  static DatabaseTask<void> deleteDraft(String id) => DatabaseTask(
    'invoices.deleteDraft',
    (context) => context.invoices.deleteDraft(id),
  );
  static DatabaseTask<void> saveDraft(
    String id,
    String kind,
    Map<String, dynamic> data, {
    bool notify = true,
  }) => DatabaseTask(
    'invoices.saveDraft',
    (context) => context.invoices.saveDraft(id, kind, data, notify: notify),
    notify: notify,
  );
  static DatabaseTask<QueryPage<InvoiceSummary>> page(
    String kind, {
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) => DatabaseTask(
    'invoices.page',
    (context) => context.invoices.page(
      kind,
      search: search,
      page: page,
      pageSize: pageSize,
    ),
  );
  static DatabaseTask<QueryPage<InvoiceDraft>> drafts(
    String kind, {
    int page = 1,
    int pageSize = 5,
  }) => DatabaseTask(
    'invoices.drafts',
    (context) => context.invoices.drafts(kind, page: page, pageSize: pageSize),
  );

  static DatabaseTask<DocumentSnapshot> details(String id) =>
      DatabaseTask('invoices.details', (data) {
        final doc = data.invoices.get(id);
        return (
          document: doc,
          due: ['sale', 'purchase'].contains(doc.kind)
              ? data.invoices.due(id)
              : 0,
          cancelled: data.corrections.isCancelled(id),
        );
      });
  static DatabaseTask<ReportTable> report(String id) => DatabaseTask(
    'invoices.report',
    (data) {
      final doc = data.invoices.get(id);
      return ExportService().document(
        data.store.shop!,
        doc,
        party: doc.partyId == null ? null : data.parties.get(doc.partyId!).name,
        due: ['sale', 'purchase'].contains(doc.kind)
            ? data.invoices.due(id)
            : null,
      );
    },
  );
}
