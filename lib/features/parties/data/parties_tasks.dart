import '../../../core/data/query_page.dart';
import 'party.dart';
import '../../reports/data/export_service.dart';
import '../../../core/data/database_task.dart';

typedef PartyPageSnapshot = ({
  QueryPage<Party> rows,
  Map<String, ({int customer, int supplier})> balances,
});
typedef PartyStatementSnapshot = ({
  QueryPage<Map<String, Object?>> rows,
  int balance,
});

abstract final class PartyTasks {
  static DatabaseTask<void> save(Party party) =>
      DatabaseTask('parties.save', (context) => context.parties.save(party));
  static DatabaseTask<void> opening(String id, bool customer, int amount) =>
      DatabaseTask(
        'parties.opening',
        (context) => context.parties.opening(id, customer, amount),
      );
  static DatabaseTask<void> adjust(
    String id,
    bool customer,
    int amount,
    String reason,
  ) => DatabaseTask(
    'parties.adjust',
    (context) => context.parties.adjust(id, customer, amount, reason),
  );
  static DatabaseTask<ReportTable> statementReport(String id, bool customer) =>
      DatabaseTask(
        'parties.statementReport',
        (context) => context.parties.statementReport(id, customer),
      );
  static DatabaseTask<QueryPage<Party>> page({
    String search = '',
    int page = 1,
    int pageSize = 10,
    bool activeOnly = false,
    bool? customer,
  }) => DatabaseTask(
    'parties.page',
    (context) => context.parties.page(
      search: search,
      page: page,
      pageSize: pageSize,
      customer: customer,
      activeOnly: activeOnly,
    ),
  );

  static DatabaseTask<PartyPageSnapshot> snapshot(
    String search,
    int page,
    int size,
  ) => DatabaseTask('parties.snapshot', (data) {
    final rows = data.parties.page(search: search, page: page, pageSize: size),
        manage = data.store.user!.canManage;
    return (
      rows: rows,
      balances: {
        for (final p in rows.items)
          p.id: (
            customer: p.customer ? data.parties.balance(p.id, true) : 0,
            supplier: manage && p.supplier
                ? data.parties.balance(p.id, false)
                : 0,
          ),
      },
    );
  });
  static DatabaseTask<PartyStatementSnapshot> statement(
    String id,
    bool customer,
    int page,
    bool enabled,
  ) => DatabaseTask(
    'parties.statement',
    (data) => (
      rows: enabled
          ? data.parties.statementPage(id, customer, page: page)
          : const QueryPage(items: <Map<String, Object?>>[], total: 0, page: 1),
      balance: enabled ? data.parties.balance(id, customer) : 0,
    ),
  );
}
