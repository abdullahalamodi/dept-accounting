import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';

typedef CreditSource = ({Document document, int available});
typedef CreditSummary = ({String id, String number, int available});

class CreditRepository {
  CreditRepository(this.store, this.engine, this.invoices);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  String _sourceCte(bool customer, {bool byId = false, bool search = false}) {
    final kinds = customer
        ? "'receipt','sale_return','opening','party_adjustment'"
        : "'payment','purchase_return','opening','party_adjustment'";
    return '''WITH credit_limits AS (
      SELECT d.*,d.rowid AS position,
        CASE WHEN d.kind IN ('sale_return','purchase_return') THEN COALESCE(json_extract(d.data, '\$.extra.credit'),0)
          WHEN d.kind IN ('opening','party_adjustment') THEN MAX(0, COALESCE((SELECT SUM(j.debit-j.credit) FROM journal j WHERE j.document_id = d.id AND j.account = '${customer ? '1200' : '2100'}'),0) * ${customer ? -1 : 1})
          ELSE json_extract(d.data, '\$.total') END AS credit_limit,
        COALESCE((SELECT SUM(amount) FROM allocations WHERE payment_id = d.id),0) AS used
      FROM documents d WHERE d.party_id = ? AND d.kind IN ($kinds)
        ${byId ? 'AND d.id = ?' : ''}
        ${search ? "AND instr(app_lower(d.number || ' ' || json_extract(d.data, '\$.notes')), ?) > 0" : ''}
        AND NOT EXISTS (SELECT 1 FROM documents c WHERE c.source_id = d.id AND c.kind = 'reversal')
    )''';
  }

  List<CreditSource> sources(String partyId, bool customer) {
    store.require(manage: !customer);
    return store.database.handle
        .select(
          '${_sourceCte(customer)} SELECT data,credit_limit-used AS available FROM credit_limits WHERE credit_limit > used ORDER BY posted_at,position',
          [partyId],
        )
        .map(
          (row) => (
            document: DocumentMapper.fromJson(row['data'] as String),
            available: row['available'] as int,
          ),
        )
        .toList();
  }

  CreditSummary _summary(Map<String, Object?> row) => (
    id: row['id'] as String,
    number: row['number'] as String,
    available: row['available'] as int,
  );

  bool hasSources(String partyId, bool customer) {
    store.require(manage: !customer);
    return store.database.handle.select(
      '${_sourceCte(customer)} SELECT 1 FROM credit_limits WHERE credit_limit > used LIMIT 1',
      [partyId],
    ).isNotEmpty;
  }

  CreditSummary? source(String partyId, bool customer, String id) {
    store.require(manage: !customer);
    if (id.isEmpty) return null;
    final rows = store.database.handle.select(
      '${_sourceCte(customer, byId: true)} SELECT id,number,credit_limit-used AS available FROM credit_limits WHERE credit_limit > used',
      [partyId, id],
    );
    return rows.isEmpty ? null : _summary(rows.first);
  }

  QueryPage<CreditSummary> sourcePage(
    String partyId,
    bool customer, {
    String search = '',
    int page = 1,
    int pageSize = 5,
  }) {
    store.require(manage: !customer);
    final cte = _sourceCte(customer, search: search.isNotEmpty);
    final parameters = <Object?>[
      partyId,
      if (search.isNotEmpty) search.toLowerCase(),
    ];
    final db = store.database.handle;
    return QueryPage.read(
      total:
          db
                  .select(
                    '$cte SELECT COUNT(*) AS n FROM credit_limits WHERE credit_limit > used',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => db
          .select(
            '$cte SELECT id,number,credit_limit-used AS available FROM credit_limits WHERE credit_limit > used ORDER BY posted_at,position LIMIT ? OFFSET ?',
            [...parameters, limit, offset],
          )
          .map(_summary)
          .toList(),
    );
  }

  Map<String, int> _refundPlan(String partyId, bool customer, int amount) {
    final rows = store.database.handle.select(
      '''
      ${_sourceCte(customer)}, available AS (
        SELECT *,credit_limit-used AS available FROM credit_limits WHERE credit_limit > used
      ), ordered AS (
        SELECT *, SUM(available) OVER (ORDER BY posted_at,position ROWS UNBOUNDED PRECEDING) AS cumulative FROM available
      ) SELECT id,MIN(available,?-cumulative+available) AS amount FROM ordered WHERE cumulative-available < ? ORDER BY posted_at,position
    ''',
      [partyId, amount, amount],
    );
    return {for (final row in rows) row['id'] as String: row['amount'] as int};
  }

  void allocate(
    String requestId,
    String sourceId,
    Map<String, int> allocations,
  ) {
    store.require();
    store.write(() {
      if (engine.find(requestId) != null) return;
      final source = engine.find(sourceId);
      if (source == null) {
        throw const BusinessException('مصدر الرصيد غير موجود.');
      }
      final customer =
          ['receipt', 'sale_return'].contains(source.kind) ||
          (['opening', 'party_adjustment'].contains(source.kind) &&
              source.notes.contains('عميل'));
      store.require(manage: !customer);
      if (source.partyId == null) {
        throw const BusinessException('المستند ليس رصيدًا لطرف.');
      }
      final available =
          this.source(source.partyId!, customer, sourceId)?.available ?? 0;
      final amount = allocations.values.fold<int>(0, (a, b) => a + b);
      if (amount <= 0 || amount > available) {
        throw const BusinessException('التخصيص يتجاوز الرصيد غير المخصص.');
      }
      for (final e in allocations.entries) {
        final invoice = invoices.get(e.key);
        if (invoice.kind != (customer ? 'sale' : 'purchase') ||
            invoice.partyId != source.partyId ||
            e.value <= 0 ||
            e.value > invoices.due(e.key)) {
          throw const BusinessException('الفاتورة أو مبلغ التخصيص غير صالح.');
        }
      }
      final doc = engine.create(
        id: requestId,
        kind: 'allocation',
        partyId: source.partyId,
        total: amount,
        sourceId: sourceId,
        notes: 'تخصيص رصيد قائم',
        extra: {'allocations': allocations},
      );
      engine.insert(doc, []);
      for (final e in allocations.entries) {
        store.database.handle.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [sourceId, e.key, e.value],
        );
      }
    });
  }

  void clearAllocations(String sourceId, String reason) {
    store.require(manage: true);
    if (reason.trim().isEmpty) {
      throw const BusinessException('سبب إلغاء التخصيص مطلوب.');
    }
    store.write(() {
      final previous = store.database.handle.select(
        "SELECT a.* FROM allocations a JOIN documents d ON d.id = a.invoice_id WHERE a.payment_id = ? AND a.invoice_id != a.payment_id AND d.kind IN ('sale','purchase')",
        [sourceId],
      );
      store.audit(
        'إلغاء تخصيص دفعة',
        sourceId,
        '$reason · ${previous.map((r) => Map<String, Object?>.from(r)).toList()}',
      );
      store.database.handle.execute(
        "DELETE FROM allocations WHERE payment_id = ? AND invoice_id != payment_id AND invoice_id IN (SELECT id FROM documents WHERE kind IN ('sale','purchase'))",
        [sourceId],
      );
    });
  }

  Document refund({
    required String requestId,
    required String partyId,
    required bool customer,
    required String account,
    required int amount,
    required String reason,
  }) {
    store.require(manage: true);
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      final code = customer ? '1200' : '2100',
          net = engine.balance(code, partyId) * (customer ? -1 : 1);
      final credits = amount <= 0
          ? <String, int>{}
          : _refundPlan(partyId, customer, amount);
      final available = credits.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      if (amount <= 0 ||
          amount > net ||
          amount > available ||
          reason.trim().isEmpty) {
        throw const BusinessException(
          'الرد يتجاوز الرصيد لصالح الطرف أو السبب غير مكتمل.',
        );
      }
      engine.requireCash(account);
      final doc = engine.create(
        id: requestId,
        kind: customer ? 'customer_refund' : 'supplier_refund',
        partyId: partyId,
        total: amount,
        payments: [Payment(account: account, amount: amount)],
        reason: reason,
      );
      engine.insert(
        doc,
        customer
            ? [debit(code, amount, partyId), credit(account, amount)]
            : [debit(account, amount), credit(code, amount, partyId)],
      );
      for (final entry in credits.entries) {
        store.database.handle.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [entry.key, doc.id, entry.value],
        );
      }
      return doc;
    });
  }
}
