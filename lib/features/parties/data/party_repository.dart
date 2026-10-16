import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import 'party.dart';
import '../../reports/data/export_service.dart';

class PartyRepository {
  PartyRepository(this.store, this.engine);
  final AppStore store;
  final PostingEngine engine;

  QueryPage<Party> page({
    String search = '',
    int page = 1,
    int pageSize = 10,
    bool activeOnly = false,
    bool? customer,
  }) {
    store.require();
    final conditions = [
      if (activeOnly) "json_extract(data, '\$.active') = 1",
      if (customer != null)
        "json_extract(data, '\$.${customer ? 'customer' : 'supplier'}') = 1",
      if (search.isNotEmpty) "instr(app_lower(json_extract(data, '\$.name') || ' ' || json_extract(data, '\$.phone')), ?) > 0",
    ];
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final parameters = <Object?>[if (search.isNotEmpty) search.toLowerCase()];
    final db = store.database.handle;
    return QueryPage.read(
      total:
          db
                  .select(
                    'SELECT COUNT(*) AS n FROM parties $where',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => db
          .select(
            "SELECT data FROM parties $where ORDER BY json_extract(data, '\$.name'), id LIMIT ? OFFSET ?",
            [...parameters, limit, offset],
          )
          .map((row) => PartyMapper.fromJson(row['data'] as String))
          .toList(),
    );
  }

  List<Party> all() {
    store.require();
    return store.database.handle
        .select(
          'SELECT data FROM parties ORDER BY json_extract(data, \'\$.name\')',
        )
        .map((r) => PartyMapper.fromJson(r['data'] as String))
        .toList();
  }

  Party get(String id) {
    final party = find(id);
    if (party == null) throw const BusinessException('الطرف غير موجود.');
    return party;
  }

  Party? find(String id) {
    store.require();
    final rows = store.database.handle.select(
      'SELECT data FROM parties WHERE id = ?',
      [id],
    );
    return rows.isEmpty
        ? null
        : PartyMapper.fromJson(rows.first['data'] as String);
  }

  void save(Party party) {
    store.require();
    if (party.name.trim().isEmpty || (!party.customer && !party.supplier)) {
      throw const BusinessException('الاسم ونوع التعامل مطلوبان.');
    }
    if (!store.user!.canManage && party.supplier) {
      throw const BusinessException(
        'إدارة الموردين تحتاج صلاحية المالك أو المحاسب.',
      );
    }
    store.write(() {
      final old = store.database.handle.select(
        'SELECT data FROM parties WHERE id = ?',
        [party.id],
      );
      if (old.isNotEmpty) {
        final previous = PartyMapper.fromJson(old.first['data'] as String);
        if ((previous.customer && !party.customer) ||
            (previous.supplier && !party.supplier)) {
          throw const BusinessException(
            'يمكن إضافة دور للطرف دون حذف دوره السابق.',
          );
        }
      }
      store.database.handle.execute(
        'INSERT INTO parties VALUES (?, ?) ON CONFLICT(id) DO UPDATE SET data = excluded.data',
        [party.id, party.toJson()],
      );
      store.audit('حفظ طرف', party.id, party.name);
    });
  }

  int balance(String id, bool customer) {
    store.require(manage: !customer);
    return engine.balance(customer ? '1200' : '2100', id) * (customer ? 1 : -1);
  }

  void opening(String id, bool customer, int amount) {
    store.require(manage: true);
    if (store.setting('opening_closed') == 'true') {
      throw const BusinessException('تم إقفال الافتتاح؛ استخدم تسوية موثقة.');
    }
    final p = get(id);
    if (customer ? !p.customer : !p.supplier) {
      throw const BusinessException('دور الطرف غير مناسب.');
    }
    if (amount == 0) {
      throw const BusinessException('الرصيد لا يمكن أن يكون صفرًا.');
    }
    store.write(() {
      final code = customer ? '1200' : '2100';
      if (store.database.handle.select(
        'SELECT id FROM journal WHERE account = ? AND party_id = ? LIMIT 1',
        [code, id],
      ).isNotEmpty) {
        throw const BusinessException('بدأت حركة الحساب؛ استخدم تسوية موثقة.');
      }
      final doc = engine.create(
        id: store.id(),
        kind: 'opening',
        partyId: id,
        total: amount.abs(),
        notes: 'افتتاح ${customer ? 'عميل' : 'مورد'}',
      );
      final delta = amount * (customer ? 1 : -1);
      engine.insert(doc, [
        delta > 0 ? debit(code, delta, id) : credit(code, -delta, id),
        delta > 0 ? credit('3900', delta) : debit('3900', -delta),
      ]);
    });
  }

  void adjust(String id, bool customer, int amount, String reason) {
    store.require(manage: true);
    if (amount == 0 || reason.trim().isEmpty) {
      throw const BusinessException('أدخل فرق الرصيد وسبب التسوية.');
    }
    final party = get(id);
    if (customer ? !party.customer : !party.supplier) {
      throw const BusinessException('دور الطرف غير مناسب.');
    }
    store.write(() {
      final delta = amount * (customer ? 1 : -1),
          code = customer ? '1200' : '2100',
          equity = store.setting('opening_closed') == 'true' ? '3100' : '3900';
      final doc = engine.create(
        id: store.id(),
        kind: 'party_adjustment',
        partyId: id,
        total: amount.abs(),
        reason: reason.trim(),
        notes: 'تسوية رصيد سابق للبرنامج · ${customer ? 'عميل' : 'مورد'}',
      );
      engine.insert(doc, [
        delta > 0 ? debit(code, delta, id) : credit(code, -delta, id),
        delta > 0 ? credit(equity, delta) : debit(equity, -delta),
      ]);
    });
  }

  ReportTable statementReport(String id, bool customer) {
    final entries = statement(id, customer), party = get(id);
    var running = 0;
    return ReportTable(
      title: 'كشف حساب ${customer ? 'عميل' : 'مورد'} · ${party.name}',
      subtitle: '${store.shop!.currencyLabel} · من بداية التشغيل',
      columns: ['التاريخ', 'المرجع', 'مدين', 'دائن', 'الرصيد'],
      rows: [
        for (final row in entries)
          [
            (row['posted_at'] as String).substring(0, 10),
            row['number'] as String,
            Numbers.format(row['debit'] as int),
            Numbers.format(row['credit'] as int),
            Numbers.format(
              running +=
                  ((row['debit'] as int) - (row['credit'] as int)) *
                  (customer ? 1 : -1),
            ),
          ],
      ],
      summary: {'الرصيد الحالي': Numbers.format(balance(id, customer))},
    );
  }

  List<Map<String, Object?>> statement(String id, bool customer) {
    store.require(manage: !customer);
    return store.database.handle
        .select(
          '''SELECT d.id, d.number, d.kind, d.posted_at, d.data,
      SUM(j.debit) AS debit, SUM(j.credit) AS credit FROM journal j JOIN documents d ON d.id = j.document_id
      WHERE j.account = ? AND j.party_id = ? GROUP BY d.id ORDER BY d.posted_at, d.rowid''',
          [customer ? '1200' : '2100', id],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  QueryPage<Map<String, Object?>> statementPage(
    String id,
    bool customer, {
    int page = 1,
    int pageSize = 10,
  }) {
    store.require(manage: !customer);
    final parameters = [customer ? '1200' : '2100', id];
    final db = store.database.handle;
    return QueryPage.read(
      total:
          db
                  .select(
                    'SELECT COUNT(DISTINCT document_id) AS n FROM journal WHERE account = ? AND party_id = ?',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => db
          .select(
            '''
        SELECT d.id,d.number,d.kind,d.posted_at,SUM(j.debit) AS debit,SUM(j.credit) AS credit,
          SUM(SUM(j.debit-j.credit)) OVER (
            ORDER BY d.posted_at,d.rowid ROWS UNBOUNDED PRECEDING
          ) * ${customer ? 1 : -1} AS balance
        FROM journal j JOIN documents d ON d.id = j.document_id
        WHERE j.account = ? AND j.party_id = ?
        GROUP BY d.id ORDER BY d.posted_at,d.rowid LIMIT ? OFFSET ?
      ''',
            [...parameters, limit, offset],
          )
          .map((r) => Map<String, Object?>.from(r))
          .toList(),
    );
  }
}
