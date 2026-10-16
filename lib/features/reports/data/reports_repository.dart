import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../accounting/data/posting_engine.dart';
import '../../../core/numbers.dart';
import 'period_report_query.dart';
import 'export_service.dart';

class ReportsRepository {
  ReportsRepository(this.store, this.engine);
  final AppStore store;
  final PostingEngine engine;
  Map<String, int> overview() {
    store.require();
    final codes = store.user!.canManage
        ? "'1200','1300','2100','4100','4200','5100','6100','6200','6900'"
        : "'1200'";
    final rows = store.database.handle.select('''
      SELECT a.code,a.cash,COALESCE(SUM(j.debit-j.credit),0) AS balance
      FROM accounts a LEFT JOIN journal j ON j.account = a.code
      WHERE a.cash = 1 OR a.code IN ($codes) GROUP BY a.code
    ''');
    final balances = {
      for (final row in rows) row['code'] as String: row['balance'] as int,
    };
    int balance(String code) => balances[code] ?? 0;
    final cash = rows
        .where((r) => r['cash'] == 1)
        .fold<int>(0, (sum, r) => sum + (r['balance'] as int));
    final result = <String, int>{'cash': cash, 'receivables': balance('1200')};
    if (store.user!.canManage) {
      result.addAll({
        'stock': balance('1300'),
        'payables': -balance('2100'),
        'sales': -balance('4100') - balance('4200'),
        'services': -balance('4200'),
        'cost': balance('5100'),
        'expenses': balance('6100') + balance('6200') + balance('6900'),
      });
      result['profit'] =
          result['sales']! - result['cost']! - result['expenses']!;
    }
    return result;
  }

  List<Map<String, Object?>> trialBalance() {
    store.require(manage: true);
    return store.database.handle
        .select(
          '''SELECT a.code,a.name,a.kind,COALESCE(SUM(j.debit),0) AS debit,
      COALESCE(SUM(j.credit),0) AS credit FROM accounts a LEFT JOIN journal j ON j.account = a.code
      GROUP BY a.code ORDER BY a.code''',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  QueryPage<Map<String, Object?>> ledger(
    String code, {
    int page = 1,
    int pageSize = 10,
  }) {
    store.require(manage: true);
    return QueryPage.read(
      total:
          store.database.handle.select(
                'SELECT COUNT(*) AS n FROM journal WHERE account = ?',
                [code],
              ).first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => store.database.handle
          .select(
            '''SELECT d.id,d.number,d.posted_at,j.debit,j.credit
      FROM journal j JOIN documents d ON d.id = j.document_id WHERE j.account = ? ORDER BY d.posted_at,j.id LIMIT ? OFFSET ?''',
            [code, limit, offset],
          )
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
    );
  }

  List<Map<String, Object?>> audit() {
    store.require(manage: true);
    return store.database.handle
        .select(
          'SELECT a.*,json_extract(u.data,\'\$.name\') AS name FROM audit a LEFT JOIN users u ON u.id = a.user_id ORDER BY a.id DESC LIMIT 200',
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  Object? _aggregateKey;
  ({int total, Map<String, String> summary})? _aggregate;

  ReportTable table(String kind, DateTime from, DateTime through) =>
      _period(kind, from, through).report;

  ({ReportTable report, int total, int page}) page(
    String kind,
    DateTime from,
    DateTime through, {
    int page = 1,
    int pageSize = 10,
  }) => _period(kind, from, through, page: page, pageSize: pageSize);

  ({ReportTable report, int total, int page}) _period(
    String kind,
    DateTime from,
    DateTime through, {
    int? page,
    int pageSize = 10,
  }) {
    store.require(manage: true);
    final first = DateTime(from.year, from.month, from.day),
        last = DateTime(through.year, through.month, through.day + 1);
    final now = DateTime.now();
    if (first.isAfter(through) ||
        through.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const BusinessException('اختر فترة صحيحة لا تتجاوز اليوم.');
    }
    final start = first.toUtc().toIso8601String(),
        end = last.toUtc().toIso8601String();
    final query = periodReportQuery(kind, start, end),
        db = store.database.handle;
    final key = (store.revision, kind, start, end);
    if (_aggregate == null || _aggregateKey != key) {
      final fields = [
        'COUNT(*) AS n',
        for (final (index, entry) in query.totals.entries.indexed)
          '${entry.value} AS total_$index',
      ];
      final totals = db
          .select(
            'WITH result AS (${query.sql}) SELECT ${fields.join(',')} FROM result',
            query.arguments,
          )
          .first;
      _aggregate = (
        total: totals['n'] as int,
        summary: {
          for (final (index, entry) in query.totals.entries.indexed)
            entry.key: Numbers.format(totals['total_$index'] as int),
        },
      );
      _aggregateKey = key;
    }
    List<List<String>> rows([int? limit, int offset = 0]) => db
        .select(
          'WITH result AS (${query.sql}) SELECT * FROM result ORDER BY ${query.order} ${limit == null ? '' : 'LIMIT ? OFFSET ?'}',
          [
            ...query.arguments,
            if (limit != null) ...[limit, offset],
          ],
        )
        .map(query.format)
        .toList();
    final result = page == null
        ? QueryPage(items: rows(), total: _aggregate!.total, page: 1)
        : QueryPage.read(
            total: _aggregate!.total,
            page: page,
            pageSize: pageSize,
            read: rows,
          );
    return (
      report: ReportTable(
        title: query.title,
        subtitle:
            '${first.toIso8601String().substring(0, 10)} — ${through.toIso8601String().substring(0, 10)} · ${store.shop!.currencyLabel} · حسب وقت الاعتماد',
        columns: query.columns,
        rows: result.items,
        summary: _aggregate!.summary,
      ),
      total: result.total,
      page: result.page,
    );
  }
}
