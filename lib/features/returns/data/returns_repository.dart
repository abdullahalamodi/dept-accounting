import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';

typedef ReturnSelection = ({
  int index,
  int quantity,
  int serviceAmount,
  bool damaged,
});

class ReturnsRepository {
  ReturnsRepository(this.store, this.engine, this.invoices, this.catalog);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  final CatalogRepository catalog;
  List<Document> forInvoice(String id) {
    store.require(manage: true);
    return store.database.handle
        .select(
          "SELECT data FROM documents WHERE source_id = ? AND kind IN ('sale_return','purchase_return') ORDER BY rowid",
          [id],
        )
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
  }

  int costCorrection(Document invoice, int index) {
    final product = invoice.lines[index].productId;
    var correction = 0;
    for (final row in store.database.handle.select(
      "SELECT data FROM documents WHERE kind = 'purchase' AND json_type(data, '\$.extra.costAdjustments') = 'object'",
    )) {
      final doc = DocumentMapper.fromJson(row['data'] as String);
      correction +=
          (doc.extra['costAdjustments']?[invoice.id]?[product] as int?) ?? 0;
    }
    final matching = [
      for (var i = 0; i < invoice.lines.length; i++)
        if (invoice.lines[i].productId == product) i,
    ];
    final shares = invoices.distribute(
      correction.abs(),
      matching.map((i) => invoice.lines[i].baseQuantity).toList(),
    );
    return shares[matching.indexOf(index)] * (correction < 0 ? -1 : 1);
  }

  ({int quantity, int value, int cost}) alreadyReturned(String id, int index) {
    var quantity = 0, value = 0, cost = 0;
    for (final doc in forInvoice(id)) {
      for (final entry in (doc.extra['returns'] as List? ?? [])) {
        if (entry['index'] == index) {
          quantity += entry['quantity'] as int;
          value += entry['value'] as int;
          cost +=
              (entry['cost'] as int) +
              Numbers.ratio(
                costCorrection(invoices.get(id), index) -
                    ((entry['costCorrection'] as int?) ?? 0),
                entry['quantity'] as int,
                invoices.get(id).lines[index].quantity,
              );
        }
      }
    }
    return (quantity: quantity, value: value, cost: cost);
  }

  int lineValue(Document invoice, int index) {
    final values = invoice.lines.map((l) => l.total).toList();
    final discount = invoices.distribute(invoice.discount, values);
    final shipping = invoices.distribute(invoice.shipping, [
      for (var i = 0; i < values.length; i++) values[i] - discount[i],
    ]);
    return values[index] - discount[index] + shipping[index];
  }

  List<({ReturnSelection selection, int value, int cost})> calculate(
    Document original,
    List<ReturnSelection> selected,
  ) {
    if (store.database.handle.select(
      "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
      [original.id],
    ).isNotEmpty) {
      throw const BusinessException('الفاتورة ملغاة ولا تقبل مرتجعًا.');
    }
    if (!['sale', 'purchase'].contains(original.kind)) {
      throw const BusinessException('المرتجع يتطلب فاتورة بيع أو شراء أصلية.');
    }
    final seen = <int>{};
    return [
      for (final s in selected)
        (() {
          if (s.index < 0 ||
              s.index >= original.lines.length ||
              !seen.add(s.index)) {
            throw const BusinessException('بنود المرتجع غير صالحة.');
          }
          final line = original.lines[s.index],
              previous = alreadyReturned(original.id, s.index),
              fullValue = lineValue(original, s.index);
          final remainingValue = fullValue - previous.value;
          if (line.service) {
            if (s.serviceAmount <= 0 || s.serviceAmount > remainingValue) {
              throw const BusinessException(
                'المبلغ يتجاوز قيمة الخدمة القابلة للرد.',
              );
            }
            return (selection: s, value: s.serviceAmount, cost: 0);
          }
          final remainingQuantity = line.quantity - previous.quantity;
          if (s.quantity <= 0 || s.quantity > remainingQuantity) {
            throw const BusinessException(
              'الكمية تتجاوز المتبقي القابل للإرجاع.',
            );
          }
          final base = Numbers.baseQuantity(s.quantity, line.factor),
              product = catalog.get(line.productId);
          if (!product.fractional && base % 1000 != 0) {
            throw const BusinessException('الصنف لا يقبل كسر الوحدة الأساسية.');
          }
          final value = s.quantity == remainingQuantity
              ? remainingValue
              : Numbers.ratio(
                  fullValue,
                  s.quantity,
                  line.quantity,
                ).clamp(0, remainingValue);
          final correctedCost = line.cost + costCorrection(original, s.index);
          final cost = s.quantity == remainingQuantity
              ? correctedCost - previous.cost
              : Numbers.ratio(
                  correctedCost,
                  s.quantity,
                  line.quantity,
                ).clamp(0, correctedCost - previous.cost);
          return (selection: s, value: value, cost: cost);
        })(),
    ];
  }

  Document post({
    required String requestId,
    required String invoiceId,
    required List<ReturnSelection> selected,
    required String reason,
    String? cashAccount,
    int refund = 0,
  }) {
    store.require(manage: true);
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      final original = invoices.get(invoiceId), sale = original.kind == 'sale';
      if (reason.trim().isEmpty || selected.isEmpty) {
        throw const BusinessException('اختر بنود المرتجع وأدخل السبب.');
      }
      final computed = calculate(original, selected),
          total = computed.fold<int>(0, (n, l) => n + l.value);
      if (total <= 0) {
        throw const BusinessException('قيمة المرتجع يجب أن تكون موجبة.');
      }
      final unpaid = invoices.due(invoiceId),
          excess = (total - unpaid).clamp(0, total);
      if (refund < 0 || refund > excess) {
        throw const BusinessException(
          'الرد النقدي يتجاوز الفائض بعد تخفيض المستحق.',
        );
      }
      if (original.partyId == null && refund != total) {
        throw const BusinessException(
          'المرتجع النقدي بلا عميل يتطلب رد المبلغ كاملًا من حساب محدد.',
        );
      }
      if (refund > 0) {
        if (cashAccount == null) {
          throw const BusinessException('اختر حساب الرد النقدي.');
        }
        engine.requireCash(cashAccount);
      }
      final journal = <JournalLine>[], snapshots = <InvoiceLine>[];
      final movements = <({String id, int q, int value, String note})>[];
      final remainingStock = <String, ({int q, int value, int unitCost})>{};
      for (final item in computed) {
        final s = item.selection,
            line = original.lines[s.index],
            base = line.service
                ? 0
                : Numbers.baseQuantity(s.quantity, line.factor);
        snapshots.add(
          line.copyWith(
            quantity: line.service ? 1000 : s.quantity,
            price: item.value,
            discount: 0,
            cost: item.cost,
          ),
        );
        if (sale) {
          journal.add(debit(line.service ? '4200' : '4100', item.value));
          if (!line.service) {
            journal.addAll([
              debit('1300', item.cost),
              credit('5100', item.cost),
            ]);
            movements.add((
              id: line.productId,
              q: base,
              value: item.cost,
              note: 'مرتجع صالح',
            ));
            if (s.damaged) {
              journal.addAll([
                debit('6200', item.cost),
                credit('1300', item.cost),
              ]);
              movements.add((
                id: line.productId,
                q: -base,
                value: -item.cost,
                note: 'إتلاف مرتجع تالف',
              ));
            }
          }
        } else {
          final current =
              remainingStock[line.productId] ??
              (() {
                final stock = engine.stock(line.productId);
                return (
                  q: stock.quantity,
                  value: stock.value,
                  unitCost: stock.unitCost,
                );
              })();
          if (base > current.q) {
            throw const BusinessException('المخزون لا يكفي لمرتجع الشراء.');
          }
          final cost = base == current.q
              ? current.value
              : Numbers.ratio(
                  current.unitCost,
                  base,
                  10000000,
                ).clamp(0, current.value);
          remainingStock[line.productId] = (
            q: current.q - base,
            value: current.value - cost,
            unitCost: current.unitCost,
          );
          journal.add(credit('1300', cost));
          final difference = cost - item.value;
          if (difference > 0) journal.add(debit('6900', difference));
          if (difference < 0) journal.add(credit('6900', -difference));
          movements.add((
            id: line.productId,
            q: -base,
            value: -cost,
            note: 'مرتجع شراء',
          ));
        }
      }
      if (total > refund) {
        journal.add(
          sale
              ? credit('1200', total - refund, original.partyId)
              : debit('2100', total - refund, original.partyId),
        );
      }
      if (refund > 0) {
        journal.add(
          sale ? credit(cashAccount!, refund) : debit(cashAccount!, refund),
        );
      }
      final doc = engine.create(
        id: requestId,
        kind: sale ? 'sale_return' : 'purchase_return',
        partyId: original.partyId,
        total: total,
        sourceId: invoiceId,
        reason: reason.trim(),
        lines: snapshots,
        payments: refund == 0
            ? []
            : [Payment(account: cashAccount!, amount: refund)],
        extra: {
          'returns': [
            for (final item in computed)
              {
                'index': item.selection.index,
                'quantity': item.selection.quantity,
                'value': item.value,
                'cost': item.cost,
                'costCorrection': costCorrection(
                  original,
                  item.selection.index,
                ),
                'damaged': item.selection.damaged,
              },
          ],
          'dueReduction': total.clamp(0, unpaid),
          'credit': excess - refund,
        },
      );
      engine.insert(doc, journal);
      for (final move in movements) {
        engine.moveStock(doc.id, move.id, move.q, move.value, move.note);
      }
      return doc;
    });
  }
}
