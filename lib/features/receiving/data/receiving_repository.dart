import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../parties/data/party_repository.dart';

class ReceivingRepository {
  ReceivingRepository(
    this.store,
    this.engine,
    this.catalog,
    this.parties,
    this.invoices,
  );
  final AppStore store;
  final PostingEngine engine;
  final CatalogRepository catalog;
  final PartyRepository parties;
  final InvoiceRepository invoices;
  List<Document> pending() {
    store.require(manage: true);
    return store.database.handle
        .select(
          "SELECT data FROM documents d WHERE kind = 'quick_receipt' AND NOT EXISTS (SELECT 1 FROM documents f WHERE f.source_id = d.id AND f.kind = 'purchase') ORDER BY d.rowid DESC",
        )
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
  }

  Document receive({
    required String requestId,
    required String partyId,
    required List<InvoiceLine> lines,
    String notes = '',
  }) {
    store.require(manage: true);
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      if (!parties.get(partyId).supplier || lines.isEmpty) {
        throw const BusinessException('اختر موردًا وأضف أصناف الاستلام.');
      }
      final snapshots = <InvoiceLine>[];
      for (final line in lines) {
        final p = catalog.get(line.productId), base = line.baseQuantity;
        if (!p.active ||
            p.service ||
            line.quantity <= 0 ||
            line.price <= 0 ||
            line.discount != 0 ||
            (!p.fractional && base % 1000 != 0) ||
            (line.unit != p.unit && line.unit != p.alternateUnit) ||
            line.factor != (line.unit == p.unit ? 1000 : p.factor)) {
          throw const BusinessException(
            'الاستلام يحتاج منتجًا وكمية وتكلفة تقديرية موجبة ووحدة صحيحة.',
          );
        }
        snapshots.add(
          line.copyWith(name: p.name, service: false, cost: line.total),
        );
      }
      final total = snapshots.fold<int>(0, (n, l) => n + l.total);
      final doc = engine.create(
        id: requestId,
        kind: 'quick_receipt',
        partyId: partyId,
        lines: snapshots,
        total: total,
        notes: notes,
      );
      engine.insert(doc, [debit('1300', total), credit('2200', total)]);
      for (final line in snapshots) {
        engine.moveStock(
          doc.id,
          line.productId,
          line.baseQuantity,
          line.cost,
          'استلام بتكلفة تقديرية',
        );
      }
      return doc;
    });
  }

  ({int stock, Map<String, int> realized, Map<String, Map<String, int>> issues})
  _costFlow(String receiptId, String productId, int delta) {
    final db = store.database.handle;
    final start =
        db.select(
              'SELECT MAX(id) AS n FROM stock_moves WHERE document_id = ? AND product_id = ?',
              [receiptId, productId],
            ).first['n']
            as int;
    var quantity =
        db.select(
              'SELECT COALESCE(SUM(quantity),0) AS n FROM stock_moves WHERE product_id = ? AND id <= ?',
              [productId, start],
            ).first['n']
            as int;
    var carry = delta;
    final realized = <String, int>{'5100': 0, '6200': 0, '6900': 0};
    final saleCorrection = <String, int>{}, saleQuantities = <String, int>{};
    final returnRemainingCorrection = <String, int>{},
        returnRemainingQuantity = <String, int>{};
    final issues = <String, Map<String, int>>{};
    final moves = db.select(
      '''SELECT m.*,d.kind,d.source_id,d.data FROM stock_moves m JOIN documents d ON d.id = m.document_id
      WHERE m.product_id = ? AND m.id > ? ORDER BY m.id''',
      [productId, start],
    );
    for (final move in moves) {
      final q = move['quantity'] as int,
          kind = move['kind'] as String,
          id = move['document_id'] as String;
      if (q < 0) {
        if (kind == 'reversal') {
          final source = engine.find(move['source_id'] as String);
          if (source?.kind == 'purchase') {
            quantity += q;
            continue;
          }
        }
        if (quantity < -q) {
          throw const BusinessException(
            'تعذر تتبع كميات الاستلام؛ راجع حركات المخزون.',
          );
        }
        final share = quantity == -q
            ? carry
            : Numbers.ratio(carry, -q, quantity);
        carry -= share;
        final account = kind == 'sale'
            ? '5100'
            : kind == 'purchase_return'
            ? '6900'
            : '6200';
        realized[account] = (realized[account] ?? 0) + share;
        if (kind == 'sale') {
          saleCorrection.update(id, (v) => v + share, ifAbsent: () => share);
          saleQuantities.update(id, (v) => v - q, ifAbsent: () => -q);
          issues.putIfAbsent(id, () => {})[productId] = saleCorrection[id]!;
        }
      } else if (q > 0 &&
          (kind == 'sale_return' ||
              (kind == 'reversal' &&
                  saleCorrection.containsKey(move['source_id'])))) {
        final source = move['source_id'] as String?;
        if (source != null && saleCorrection.containsKey(source)) {
          final leftQ =
              returnRemainingQuantity[source] ?? saleQuantities[source]!;
          final leftValue =
              returnRemainingCorrection[source] ?? saleCorrection[source]!;
          final returned = q == leftQ
              ? leftValue
              : Numbers.ratio(leftValue, q, leftQ);
          returnRemainingQuantity[source] = leftQ - q;
          returnRemainingCorrection[source] = leftValue - returned;
          carry += returned;
          realized['5100'] = realized['5100']! - returned;
        }
      } else if (q > 0 && kind == 'stock_adjustment' && quantity > 0) {
        final doc = DocumentMapper.fromJson(move['data'] as String);
        if (doc.extra['usesAverage'] == true) {
          final additional = Numbers.ratio(carry, q, quantity);
          carry += additional;
          realized['6200'] = realized['6200']! - additional;
        }
      }
      quantity += q;
    }
    return (stock: carry, realized: realized, issues: issues);
  }

  Document finalize({
    required String requestId,
    required String receiptId,
    required List<int> actualPrices,
    required List<Payment> payments,
    int shipping = 0,
    String? date,
    String notes = '',
  }) {
    store.require(manage: true);
    return store.write(() {
      final duplicate = engine.find(requestId);
      if (duplicate != null) return duplicate;
      final original = invoices.get(receiptId), db = store.database.handle;
      if (original.kind != 'quick_receipt' ||
          db.select(
            "SELECT id FROM documents WHERE source_id = ? AND kind = 'purchase'",
            [receiptId],
          ).isNotEmpty) {
        throw const BusinessException(
          'الاستلام غير صالح أو تمت فوترته مسبقًا.',
        );
      }
      if (actualPrices.length != original.lines.length ||
          actualPrices.any((p) => p <= 0) ||
          shipping < 0) {
        throw const BusinessException('أدخل التكلفة النهائية لكل بند.');
      }
      final values = [
        for (var i = 0; i < actualPrices.length; i++)
          Numbers.ratio(actualPrices[i], original.lines[i].quantity, 1000),
      ];
      final freight = invoices.distribute(shipping, values),
          total = values.fold<int>(0, (a, b) => a + b) + shipping;
      final paid = payments.fold<int>(0, (n, p) => n + p.amount);
      if (paid > total || payments.any((p) => p.amount <= 0)) {
        throw const BusinessException('راجع مبالغ الدفعات.');
      }
      for (final p in payments) {
        engine.requireCash(p.account);
      }
      final estimates = <String, int>{},
          actual = <String, int>{},
          snapshots = <InvoiceLine>[];
      for (var i = 0; i < original.lines.length; i++) {
        final l = original.lines[i], value = values[i] + freight[i];
        estimates.update(
          l.productId,
          (v) => v + l.cost,
          ifAbsent: () => l.cost,
        );
        actual.update(l.productId, (v) => v + value, ifAbsent: () => value);
        snapshots.add(l.copyWith(price: actualPrices[i], cost: value));
      }
      final journal = <JournalLine>[debit('2200', original.total)],
          stockDeltas = <String, int>{},
          issues = <String, Map<String, int>>{};
      for (final e in actual.entries) {
        final flow = _costFlow(receiptId, e.key, e.value - estimates[e.key]!);
        stockDeltas[e.key] = flow.stock;
        if (flow.stock != 0) {
          journal.add(
            flow.stock > 0
                ? debit('1300', flow.stock)
                : credit('1300', -flow.stock),
          );
        }
        for (final r in flow.realized.entries) {
          if (r.value != 0) {
            journal.add(
              r.value > 0 ? debit(r.key, r.value) : credit(r.key, -r.value),
            );
          }
        }
        for (final s in flow.issues.entries) {
          issues.putIfAbsent(s.key, () => {}).addAll(s.value);
        }
      }
      for (final p in payments) {
        journal.add(credit(p.account, p.amount));
      }
      if (total > paid) {
        journal.add(credit('2100', total - paid, original.partyId));
      }
      final doc = engine.create(
        id: requestId,
        kind: 'purchase',
        sourceId: receiptId,
        partyId: original.partyId,
        total: total,
        lines: snapshots,
        payments: payments,
        shipping: shipping,
        date: date,
        notes: notes,
        extra: {
          'settlesReceipt': receiptId,
          'costAdjustments': issues,
          'stockDeltas': stockDeltas,
        },
      );
      engine.insert(doc, journal);
      for (final e in stockDeltas.entries) {
        if (e.value != 0) {
          engine.moveStock(
            doc.id,
            e.key,
            0,
            e.value,
            'تسوية تكلفة الاستلام ${original.number}',
          );
        }
      }
      if (paid > 0) {
        db.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [doc.id, doc.id, paid],
        );
      }
      return doc;
    });
  }
}
