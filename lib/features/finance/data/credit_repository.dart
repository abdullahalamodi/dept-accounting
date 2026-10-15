import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';

typedef CreditSource = ({Document document, int available});

class CreditRepository {
  CreditRepository(this.store, this.engine, this.invoices);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  List<CreditSource> sources(String partyId, bool customer) {
    store.require(manage: !customer);
    final kinds = customer
        ? "'receipt','sale_return','opening','party_adjustment'"
        : "'payment','purchase_return','opening','party_adjustment'";
    final rows = store.database.handle.select(
      "SELECT data FROM documents d WHERE party_id = ? AND kind IN ($kinds) AND NOT EXISTS (SELECT 1 FROM documents c WHERE c.source_id = d.id AND c.kind = 'reversal') ORDER BY d.posted_at,d.rowid",
      [partyId],
    );
    final result = <CreditSource>[];
    for (final r in rows) {
      final doc = DocumentMapper.fromJson(r['data'] as String);
      var limit = doc.total;
      if (doc.kind.endsWith('_return')) {
        limit = doc.extra['credit'] as int? ?? 0;
      }
      if (['opening', 'party_adjustment'].contains(doc.kind)) {
        final rows = store.database.handle.select(
          'SELECT COALESCE(SUM(debit-credit),0) AS n FROM journal WHERE document_id = ? AND account = ?',
          [doc.id, customer ? '1200' : '2100'],
        );
        limit = (rows.first['n'] as int) * (customer ? -1 : 1);
        if (limit < 0) limit = 0;
      }
      final used =
          store.database.handle.select(
                'SELECT COALESCE(SUM(amount),0) AS n FROM allocations WHERE payment_id = ?',
                [doc.id],
              ).first['n']
              as int;
      final available = (limit - used).clamp(0, limit);
      if (available > 0) result.add((document: doc, available: available));
    }
    return result;
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
          sources(
            source.partyId!,
            customer,
          ).where((s) => s.document.id == sourceId).firstOrNull?.available ??
          0;
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
      final credits = sources(partyId, customer),
          available = credits.fold<int>(0, (n, s) => n + s.available);
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
      var remaining = amount;
      for (final source in credits) {
        if (remaining <= 0) break;
        final part = remaining.clamp(0, source.available);
        remaining -= part;
        store.database.handle.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [source.document.id, doc.id, part],
        );
      }
      return doc;
    });
  }
}
