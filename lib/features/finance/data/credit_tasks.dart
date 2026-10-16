import '../../invoices/data/invoice_summary.dart';
import 'finance_repository.dart';
import '../../../core/data/query_page.dart';
import 'credit_repository.dart';
import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';

typedef CreditContext = ({
  CreditSummary? selected,
  bool hasSources,
  QueryPage<InvoiceSummary> invoices,
  Map<String, int> preview,
  List<CashAccount> accounts,
});

abstract final class CreditTasks {
  static DatabaseTask<void> allocate(
    String requestId,
    String sourceId,
    Map<String, int> allocations,
  ) => DatabaseTask(
    'credits.allocate',
    (context) => context.credits.allocate(requestId, sourceId, allocations),
  );
  static DatabaseTask<void> clearAllocations(String sourceId, String reason) =>
      DatabaseTask(
        'credits.clearAllocations',
        (context) => context.credits.clearAllocations(sourceId, reason),
      );
  static DatabaseTask<Document> refund({
    required String requestId,
    required String partyId,
    required bool customer,
    required String account,
    required int amount,
    required String reason,
  }) => DatabaseTask(
    'credits.refund',
    (context) => context.credits.refund(
      requestId: requestId,
      partyId: partyId,
      customer: customer,
      account: account,
      amount: amount,
      reason: reason,
    ),
  );
  static DatabaseTask<QueryPage<CreditSummary>> sourcePage(
    String partyId,
    bool customer, {
    String search = '',
    int page = 1,
    int pageSize = 5,
  }) => DatabaseTask(
    'credit.sourcePage',
    (context) => context.credits.sourcePage(
      partyId,
      customer,
      search: search,
      page: page,
      pageSize: pageSize,
    ),
  );

  static DatabaseTask<CreditContext> context(
    String partyId,
    bool customer,
    String? sourceId,
    int invoicePage,
    bool automatic,
  ) => DatabaseTask('credit.context', (data) {
    final selected = data.credits.source(partyId, customer, sourceId ?? '');
    return (
      selected: selected,
      hasSources:
          selected != null || data.credits.hasSources(partyId, customer),
      invoices: selected == null
          ? const QueryPage(items: <InvoiceSummary>[], total: 0, page: 1)
          : data.invoices.outstandingPage(partyId, customer, page: invoicePage),
      preview: selected == null || !automatic
          ? <String, int>{}
          : data.finance.allocationPreview(
              partyId,
              customer,
              selected.available,
            ),
      accounts: data.store.user!.canManage
          ? data.finance.accounts()
          : <CashAccount>[],
    );
  });
}
