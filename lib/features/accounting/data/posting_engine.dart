import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../invoices/data/document.dart';

typedef JournalLine = ({String account, int debit, int credit, String? party});
JournalLine debit(String account, int amount, [String? party]) =>
    (account: account, debit: amount, credit: 0, party: party);
JournalLine credit(String account, int amount, [String? party]) =>
    (account: account, debit: 0, credit: amount, party: party);

class PostingEngine {
  PostingEngine(this.store);
  final AppStore store;
  String nextNumber(String kind) {
    final db = store.database.handle;
    db.execute('INSERT INTO sequences VALUES (?, 1) ON CONFLICT DO NOTHING', [
      kind,
    ]);
    final number =
        db.select('SELECT next FROM sequences WHERE kind = ?', [
              kind,
            ]).first['next']
            as int;
    db.execute('UPDATE sequences SET next = next + 1 WHERE kind = ?', [kind]);
    final prefix = switch (kind) {
      'sale' => 'SAL',
      'purchase' => 'PUR',
      'receipt' => 'REC',
      'payment' => 'PAY',
      'sale_return' => 'SR',
      'purchase_return' => 'PR',
      'quick_receipt' => 'GRN',
      _ => kind.toUpperCase(),
    };
    return '$prefix-${number.toString().padLeft(6, '0')}';
  }

  Document? find(String id) {
    final rows = store.database.handle.select(
      'SELECT data FROM documents WHERE id = ?',
      [id],
    );
    return rows.isEmpty
        ? null
        : DocumentMapper.fromJson(rows.first['data'] as String);
  }

  int balance(String account, [String? party]) =>
      store.database.handle.select(
            'SELECT COALESCE(SUM(debit-credit),0) AS n FROM journal WHERE account = ?${party == null ? '' : ' AND party_id = ?'}',
            [account, ?party],
          ).first['n']
          as int;
  void requireCash(String account) {
    if (store.database.handle.select(
      'SELECT code FROM accounts WHERE code = ? AND cash = 1',
      [account],
    ).isEmpty) {
      throw const BusinessException('اختر حسابًا نقديًا أو بنكيًا صحيحًا.');
    }
  }

  void validateCash(List<JournalLine> journal) {
    final deltas = <String, int>{};
    for (final line in journal) {
      deltas.update(
        line.account,
        (v) => v + line.debit - line.credit,
        ifAbsent: () => line.debit - line.credit,
      );
    }
    for (final row in store.database.handle.select(
      'SELECT code FROM accounts WHERE cash = 1',
    )) {
      final code = row['code'] as String;
      if (balance(code) + (deltas[code] ?? 0) < 0) {
        throw const BusinessException('الرصيد النقدي لا يكفي لاعتماد العملية.');
      }
    }
  }

  void insert(Document doc, List<JournalLine> journal) {
    if (journal.any((r) => r.debit < 0 || r.credit < 0)) {
      throw const BusinessException('قيد محاسبي غير صالح.');
    }
    if (journal.fold<int>(0, (n, r) => n + r.debit - r.credit) != 0) {
      throw const BusinessException('تعذر الاعتماد: القيد غير متوازن.');
    }
    validateCash(journal);
    final db = store.database.handle;
    db.execute('INSERT INTO documents VALUES (?, ?, ?, ?, ?, ?, ?)', [
      doc.id,
      doc.kind,
      doc.number,
      doc.partyId,
      doc.postedAt,
      doc.toJson(),
      doc.sourceId,
    ]);
    for (final line in journal.where((l) => l.debit != 0 || l.credit != 0)) {
      db.execute(
        'INSERT INTO journal(document_id, account, party_id, debit, credit) VALUES (?, ?, ?, ?, ?)',
        [doc.id, line.account, line.party, line.debit, line.credit],
      );
    }
    store.audit('اعتماد ${doc.label}', doc.id, doc.number);
  }

  ({int quantity, int value, int unitCost}) stock(String id) {
    final rows = store.database.handle.select(
      'SELECT * FROM stock WHERE product_id = ?',
      [id],
    );
    if (rows.isEmpty) return (quantity: 0, value: 0, unitCost: 0);
    final q = rows.first['quantity'] as int, v = rows.first['value'] as int;
    return (
      quantity: q,
      value: v,
      unitCost: q == 0 ? 0 : Numbers.ratio(v, 10000000, q),
    );
  }

  int issueCost(String id, int quantity) {
    final current = stock(id);
    if (quantity <= 0 || quantity > current.quantity) {
      throw const BusinessException('الكمية المطلوبة أكبر من المخزون المتاح.');
    }
    return quantity == current.quantity
        ? current.value
        : Numbers.ratio(
            current.unitCost,
            quantity,
            10000000,
          ).clamp(0, current.value);
  }

  void moveStock(
    String docId,
    String id,
    int quantity,
    int value, [
    String note = '',
  ]) {
    final old = stock(id);
    if (old.quantity + quantity < 0 || old.value + value < 0) {
      throw const BusinessException('لا يمكن جعل المخزون أو قيمته سالبة.');
    }
    final db = store.database.handle;
    db.execute(
      'INSERT INTO stock VALUES (?, ?, ?) ON CONFLICT(product_id) DO UPDATE SET quantity = excluded.quantity, value = excluded.value',
      [id, old.quantity + quantity, old.value + value],
    );
    db.execute(
      'INSERT INTO stock_moves(document_id, product_id, quantity, value, note) VALUES (?, ?, ?, ?, ?)',
      [docId, id, quantity, value, note],
    );
  }

  Document create({
    required String id,
    required String kind,
    int total = 0,
    String? partyId,
    List<InvoiceLine> lines = const [],
    List<Payment> payments = const [],
    int discount = 0,
    int shipping = 0,
    String notes = '',
    String? sourceId,
    String reason = '',
    String? date,
    Map<String, dynamic> extra = const {},
  }) {
    final now = DateTime.now();
    final paper = date ?? now.toIso8601String().substring(0, 10);
    final parsed = DateTime.tryParse(paper);
    if (parsed == null ||
        parsed.isAfter(DateTime(now.year, now.month, now.day))) {
      throw const BusinessException('تاريخ المستند غير صالح أو في المستقبل.');
    }
    return Document(
      id: id,
      kind: kind,
      number: nextNumber(kind),
      date: paper,
      postedAt: now.toUtc().toIso8601String(),
      userId: store.user!.id,
      partyId: partyId,
      lines: lines,
      payments: payments,
      discount: discount,
      shipping: shipping,
      total: total,
      notes: notes,
      sourceId: sourceId,
      reason: reason,
      extra: extra,
    );
  }
}
