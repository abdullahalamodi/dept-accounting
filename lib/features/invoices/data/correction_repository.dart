import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import 'document.dart';
import 'invoice_repository.dart';

class CorrectionRepository {
  CorrectionRepository(this.store, this.engine, this.invoices);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  bool isCancelled(String id) => store.database.handle.select(
    "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
    [id],
  ).isNotEmpty;
  Document cancel(String id, String requestId, String reason) {
    store.require(manage: true);
    return store.write(() {
      final duplicate = engine.find(requestId);
      if (duplicate != null) return duplicate;
      final original = invoices.get(id), db = store.database.handle;
      if (reason.trim().isEmpty ||
          ![
            'sale',
            'purchase',
            'receipt',
            'payment',
            'expense',
            'transfer',
            'capital',
            'drawing',
          ].contains(original.kind)) {
        throw const BusinessException(
          'اختر مستندًا قابلًا للإلغاء وأدخل السبب.',
        );
      }
      if (original.extra['settlesReceipt'] != null) {
        throw const BusinessException(
          'فاتورة تسوية استلام؛ استخدم مرتجعًا مرتبطًا للحفاظ على أثر التكلفة.',
        );
      }
      if (isCancelled(id)) {
        throw const BusinessException('المستند ملغى بالفعل.');
      }
      if (db.select(
        "SELECT id FROM documents WHERE source_id = ? AND kind != 'allocation' LIMIT 1",
        [id],
      ).isNotEmpty) {
        throw const BusinessException(
          'للمستند عمليات مرتبطة؛ عالجها قبل الإلغاء.',
        );
      }
      if (db.select(
        r"SELECT d.id FROM documents d, json_each(d.data, '$.extra.costAdjustments') c WHERE d.kind = 'purchase' AND c.key = ? LIMIT 1",
        [id],
      ).isNotEmpty) {
        throw const BusinessException(
          'للفاتورة تسوية تكلفة لاحقة. استخدم مرتجعًا مرتبطًا.',
        );
      }
      if (db.select(
        "SELECT a.id FROM allocations a JOIN documents d ON d.id = a.invoice_id WHERE a.payment_id = ? AND d.kind IN ('customer_refund','supplier_refund') LIMIT 1",
        [id],
      ).isNotEmpty) {
        throw const BusinessException(
          'استُخدم الرصيد في رد نقدي؛ لا يمكن إلغاء مصدره.',
        );
      }
      final stock = db.select(
        'SELECT * FROM stock_moves WHERE document_id = ? ORDER BY id DESC',
        [id],
      );
      for (final move in stock) {
        if (db.select(
          'SELECT id FROM stock_moves WHERE product_id = ? AND id > ? AND document_id != ? LIMIT 1',
          [move['product_id'], move['id'], id],
        ).isNotEmpty) {
          throw const BusinessException(
            'توجد حركة مخزون لاحقة. استخدم مرتجعًا مرتبطًا بدل إلغاء التكلفة السابقة.',
          );
        }
      }
      final externalAllocations = db.select(
        'SELECT id FROM allocations WHERE invoice_id = ? AND payment_id != ? LIMIT 1',
        [id, id],
      );
      if (externalAllocations.isNotEmpty) {
        throw const BusinessException(
          'توجد دفعات لاحقة مخصصة لهذه الفاتورة. ألغِ تخصيصها أولًا.',
        );
      }
      final journal = db
          .select('SELECT * FROM journal WHERE document_id = ?', [id])
          .map(
            (r) => (
              account: r['account'] as String,
              debit: r['credit'] as int,
              credit: r['debit'] as int,
              party: r['party_id'] as String?,
            ),
          )
          .toList();
      final doc = engine.create(
        id: requestId,
        kind: 'reversal',
        sourceId: id,
        partyId: original.partyId,
        total: original.total,
        reason: reason.trim(),
        notes: 'إلغاء ${original.number}',
        extra: {
          'previousAllocations': db
              .select(
                'SELECT * FROM allocations WHERE payment_id = ? OR invoice_id = ?',
                [id, id],
              )
              .map((r) => Map<String, Object?>.from(r))
              .toList(),
        },
      );
      engine.insert(doc, journal);
      for (final move in stock) {
        engine.moveStock(
          doc.id,
          move['product_id'] as String,
          -(move['quantity'] as int),
          -(move['value'] as int),
          'إلغاء ${original.number}',
        );
      }
      db.execute(
        'DELETE FROM allocations WHERE payment_id = ? OR invoice_id = ?',
        [id, id],
      );
      return doc;
    });
  }
}
