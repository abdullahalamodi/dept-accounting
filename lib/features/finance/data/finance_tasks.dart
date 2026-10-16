import '../../invoices/data/invoice_summary.dart';
import '../../../core/data/query_page.dart';
import 'finance_repository.dart';
import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';

typedef FinanceSnapshot = ({
  int openingEquity,
  QueryPage<Document> documents,
  List<CashAccount> accounts,
  List<OpeningBalance> opening,
  Set<String> editable,
});
typedef VoucherSnapshot = ({
  List<CashAccount> accounts,
  QueryPage<InvoiceSummary> invoices,
  Map<String, int> preview,
});

abstract final class FinanceTasks {
  static DatabaseTask<Document> post({
    required String requestId,
    required String kind,
    required List<Payment> payments,
    String? partyId,
    String? toAccount,
    String notes = '',
    String category = '',
    Map<String, int> allocations = const {},
    bool automatic = false,
  }) => DatabaseTask(
    'finance.post',
    (data) => data.finance.post(
      requestId: requestId,
      kind: kind,
      payments: payments,
      partyId: partyId,
      toAccount: toAccount,
      notes: notes,
      category: category,
      allocations: automatic && partyId != null
          ? data.finance.allocationPreview(
              partyId,
              kind == 'receipt',
              payments.fold<int>(0, (sum, p) => sum + p.amount),
            )
          : allocations,
    ),
  );
  static DatabaseTask<void> setOpening(String code, int amount) => DatabaseTask(
    'finance.setOpening',
    (data) => data.finance.setOpening(code, amount),
  );

  static DatabaseTask<void> removeOpening(String code) => DatabaseTask(
    'finance.removeOpening',
    (context) => context.finance.removeOpening(code),
  );
  static DatabaseTask<void> addAccount(String name) => DatabaseTask(
    'finance.addAccount',
    (context) => context.finance.addAccount(name),
  );
  static DatabaseTask<Map<String, int>> allocationPreview(
    String partyId,
    bool customer,
    int amount,
  ) => DatabaseTask(
    'finance.allocationPreview',
    (context) => context.finance.allocationPreview(partyId, customer, amount),
  );
  static DatabaseTask<List<CashAccount>> accounts() =>
      DatabaseTask('finance.accounts', (context) => context.finance.accounts());

  static DatabaseTask<FinanceSnapshot> snapshot(int page) =>
      DatabaseTask('finance.snapshot', (data) {
        final accounts = data.finance.accounts(),
            manage = data.store.user!.canManage;
        return (
          openingEquity: data.engine.balance('3900'),
          documents: data.finance.documentPage(page: page),
          accounts: accounts,
          opening: manage ? data.finance.openingBalances() : <OpeningBalance>[],
          editable: {
            if (manage)
              for (final a in accounts)
                if (data.finance.canEditOpening(a.code)) a.code,
          },
        );
      });
  static DatabaseTask<VoucherSnapshot> voucher(
    String? partyId,
    bool customer,
    int total,
    int page,
    bool automatic,
  ) => DatabaseTask(
    'finance.voucher',
    (data) => (
      accounts: data.finance.accounts(),
      invoices: partyId == null
          ? const QueryPage(items: <InvoiceSummary>[], total: 0, page: 1)
          : data.invoices.outstandingPage(partyId, customer, page: page),
      preview: partyId == null || !automatic
          ? <String, int>{}
          : data.finance.allocationPreview(partyId, customer, total),
    ),
  );
}
