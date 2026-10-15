import '../../../core/data/app_store.dart';
import '../../accounting/data/posting_engine.dart';
import '../../../core/numbers.dart';
import '../../invoices/data/document.dart';
import 'export_service.dart';

class ReportsRepository {
  ReportsRepository(this.store, this.engine);
  final AppStore store;
  final PostingEngine engine;
  Map<String, int> overview() {
    store.require();
    final cash = store.database.handle
        .select('SELECT code FROM accounts WHERE cash = 1')
        .fold<int>(0, (a, r) => a + engine.balance(r['code'] as String));
    final result = <String, int>{
      'cash': cash,
      'receivables': engine.balance('1200'),
    };
    if (store.user!.canManage) {
      result.addAll({
        'stock': engine.balance('1300'),
        'payables': -engine.balance('2100'),
        'sales': -engine.balance('4100') - engine.balance('4200'),
        'services': -engine.balance('4200'),
        'cost': engine.balance('5100'),
        'expenses':
            engine.balance('6100') +
            engine.balance('6200') +
            engine.balance('6900'),
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

  List<Map<String, Object?>> ledger(String code) {
    store.require(manage: true);
    return store.database.handle
        .select(
          '''SELECT d.id,d.number,d.posted_at,d.data,j.debit,j.credit
      FROM journal j JOIN documents d ON d.id = j.document_id WHERE j.account = ? ORDER BY d.posted_at,j.id''',
          [code],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
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

  ReportTable table(String kind, DateTime from, DateTime through) {
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
    final db = store.database.handle, currency = store.shop!.currencyLabel;
    final subtitle =
        '${first.toIso8601String().substring(0, 10)} — ${through.toIso8601String().substring(0, 10)} · $currency · حسب وقت الاعتماد';
    if (kind == 'profit') {
      final rows = db.select(
        'SELECT a.code,a.name,a.kind,COALESCE(SUM(j.debit-j.credit),0) AS amount FROM accounts a LEFT JOIN (SELECT j.* FROM journal j JOIN documents d ON d.id = j.document_id WHERE d.posted_at >= ? AND d.posted_at < ?) j ON j.account = a.code WHERE a.kind IN (\'income\',\'expense\') GROUP BY a.code ORDER BY a.code',
        [start, end],
      );
      var income = 0, expense = 0;
      for (final r in rows) {
        if (r['kind'] == 'income') {
          income -= r['amount'] as int;
        } else {
          expense += r['amount'] as int;
        }
      }
      return ReportTable(
        title: 'الأرباح والخسائر',
        subtitle: subtitle,
        columns: ['الحساب', 'الاسم', 'القيمة'],
        rows: [
          for (final r in rows)
            [
              r['code'] as String,
              r['name'] as String,
              Numbers.format(
                (r['amount'] as int) * (r['kind'] == 'income' ? -1 : 1),
              ),
            ],
        ],
        summary: {
          'الإيرادات': Numbers.format(income),
          'المصروفات والتكلفة': Numbers.format(expense),
          'صافي النتيجة': Numbers.format(income - expense),
        },
      );
    }
    if (kind == 'stock') {
      final rows = db.select(
        'SELECT p.data,COALESCE(SUM(m.quantity),0) AS quantity,COALESCE(SUM(m.value),0) AS value FROM products p LEFT JOIN (SELECT m.* FROM stock_moves m JOIN documents d ON d.id = m.document_id WHERE d.posted_at < ?) m ON m.product_id = p.id WHERE json_extract(p.data,\'\$.service\') = 0 GROUP BY p.id',
        [end],
      );
      return ReportTable(
        title: 'المخزون وقيمته في نهاية الفترة',
        subtitle: subtitle,
        columns: ['الصنف', 'الكمية الأساسية', 'القيمة'],
        rows: [
          for (final r in rows)
            [
              store.decode(r['data'] as String)['name'] as String,
              Numbers.format(r['quantity'] as int, decimals: 3),
              Numbers.format(r['value'] as int),
            ],
        ],
        summary: {
          'قيمة المخزون': Numbers.format(
            rows.fold<int>(0, (n, r) => n + (r['value'] as int)),
          ),
        },
      );
    }
    if (kind == 'parties') {
      final rows = db.select(
        'SELECT p.data,j.account,COALESCE(SUM(j.debit-j.credit),0) AS balance FROM parties p JOIN journal j ON j.party_id = p.id JOIN documents d ON d.id = j.document_id WHERE d.posted_at < ? AND j.account IN (\'1200\',\'2100\') GROUP BY p.id,j.account',
        [end],
      );
      return ReportTable(
        title: 'أرصدة العملاء والموردين في نهاية الفترة',
        subtitle: subtitle,
        columns: ['الطرف', 'الحساب', 'المستحق / السالب لصالح الطرف'],
        rows: [
          for (final r in rows)
            [
              store.decode(r['data'] as String)['name'] as String,
              r['account'] == '1200' ? 'عميل' : 'مورد',
              Numbers.format(
                (r['balance'] as int) * (r['account'] == '1200' ? 1 : -1),
              ),
            ],
        ],
      );
    }
    if (kind == 'cash') {
      final rows = db.select(
        'SELECT d.number,d.posted_at,a.name,j.debit,j.credit FROM journal j JOIN accounts a ON a.code = j.account JOIN documents d ON d.id = j.document_id WHERE a.cash = 1 AND d.posted_at >= ? AND d.posted_at < ? ORDER BY d.posted_at,j.id',
        [start, end],
      );
      return ReportTable(
        title: 'حركة الصناديق والبنوك',
        subtitle: subtitle,
        columns: ['المرجع', 'التاريخ', 'الحساب', 'وارد', 'صادر'],
        rows: [
          for (final r in rows)
            [
              r['number'] as String,
              (r['posted_at'] as String).substring(0, 10),
              r['name'] as String,
              Numbers.format(r['debit'] as int),
              Numbers.format(r['credit'] as int),
            ],
        ],
      );
    }
    if (kind == 'trial') {
      final rows = db.select(
        'SELECT a.code,a.name,COALESCE(SUM(j.debit),0) AS debit,COALESCE(SUM(j.credit),0) AS credit FROM accounts a LEFT JOIN (SELECT j.* FROM journal j JOIN documents d ON d.id=j.document_id WHERE d.posted_at < ?) j ON j.account=a.code GROUP BY a.code ORDER BY a.code',
        [end],
      );
      return ReportTable(
        title: 'ميزان المراجعة في نهاية الفترة',
        subtitle: subtitle,
        columns: ['الرمز', 'الحساب', 'مدين', 'دائن', 'صافي الرصيد'],
        rows: [
          for (final r in rows)
            [
              r['code'] as String,
              r['name'] as String,
              Numbers.format(r['debit'] as int),
              Numbers.format(r['credit'] as int),
              Numbers.format((r['debit'] as int) - (r['credit'] as int)),
            ],
        ],
        summary: {
          'إجمالي المدين': Numbers.format(
            rows.fold<int>(0, (n, r) => n + (r['debit'] as int)),
          ),
          'إجمالي الدائن': Numbers.format(
            rows.fold<int>(0, (n, r) => n + (r['credit'] as int)),
          ),
        },
      );
    }
    final kinds = switch (kind) {
      'sales' => ['sale'],
      'purchases' => ['purchase'],
      'returns' => ['sale_return', 'purchase_return'],
      'expenses' => ['expense'],
      _ => ['sale', 'purchase'],
    };
    final rows = db.select(
      'SELECT data FROM documents WHERE posted_at >= ? AND posted_at < ? AND kind IN (${List.filled(kinds.length, '?').join(',')}) ORDER BY posted_at',
      [start, end, ...kinds],
    );
    final docs = rows
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
    return ReportTable(
      title: switch (kind) {
        'sales' => 'المبيعات',
        'purchases' => 'المشتريات',
        'returns' => 'المرتجعات',
        'expenses' => 'المصروفات',
        _ => 'المستندات',
      },
      subtitle: subtitle,
      columns: [
        'المرجع',
        'النوع',
        'تاريخ الورقة',
        'الطرف / التصنيف',
        'القيمة',
        'الحالة',
      ],
      rows: [
        for (final d in docs)
          [
            d.number,
            d.label,
            d.date,
            d.partyId == null
                ? d.extra['category'] as String? ?? ''
                : db.select(
                        'SELECT json_extract(data,\'\$.name\') AS name FROM parties WHERE id = ?',
                        [d.partyId],
                      ).first['name']
                      as String,
            Numbers.format(d.total),
            db.select(
                  "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
                  [d.id],
                ).isEmpty
                ? 'معتمد'
                : 'ملغى',
          ],
      ],
      summary: {
        'إجمالي المستندات المعتمدة': Numbers.format(
          docs
              .where(
                (d) => db.select(
                  "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
                  [d.id],
                ).isEmpty,
              )
              .fold<int>(0, (n, d) => n + d.total),
        ),
      },
    );
  }
}
