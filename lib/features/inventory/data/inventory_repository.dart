import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../invoices/data/document.dart';

class InventoryRepository {
  InventoryRepository(this.store, this.engine, this.catalog);
  final AppStore store;
  final PostingEngine engine;
  final CatalogRepository catalog;
  List<Map<String, Object?>> movements(String productId) {
    store.require(manage: true);
    return store.database.handle
        .select(
          '''SELECT s.*,d.number,d.posted_at FROM stock_moves s JOIN documents d ON d.id = s.document_id
      WHERE s.product_id = ? ORDER BY s.id DESC''',
          [productId],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }

  Document adjust({
    required String requestId,
    required String productId,
    required int counted,
    required String reason,
    int? extraUnitCost,
    bool damaged = false,
  }) {
    store.require(manage: true);
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      final product = catalog.get(productId),
          old = engine.stock(productId),
          delta = counted - old.quantity;
      if (product.service ||
          counted < 0 ||
          reason.trim().isEmpty ||
          delta == 0 ||
          (!product.fractional && counted % 1000 != 0)) {
        throw const BusinessException('راجع الكمية وسبب التسوية.');
      }
      final value = delta < 0
          ? engine.issueCost(productId, -delta)
          : Numbers.ratio(extraUnitCost ?? old.unitCost, delta, 10000000);
      if (delta > 0 && value <= 0) {
        throw const BusinessException('تكلفة الوحدات الزائدة مطلوبة.');
      }
      final doc = engine.create(
        id: requestId,
        kind: 'stock_adjustment',
        total: value,
        reason: reason.trim(),
        notes: '${damaged ? 'تالف' : 'جرد'} · ${product.name}',
        extra: {
          'counted': counted,
          'productId': productId,
          'previous': old.quantity,
          'usesAverage': extraUnitCost == null,
        },
      );
      engine.insert(
        doc,
        delta > 0
            ? [debit('1300', value), credit('6200', value)]
            : [debit('6200', value), credit('1300', value)],
      );
      engine.moveStock(
        doc.id,
        productId,
        delta,
        delta > 0 ? value : -value,
        reason.trim(),
      );
      return doc;
    });
  }
}
