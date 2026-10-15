import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import 'product.dart';

class CatalogRepository {
  CatalogRepository(this.store, this.engine);
  final AppStore store;
  final PostingEngine engine;
  List<Product> all() {
    store.require();
    return store.database.handle
        .select(
          'SELECT data FROM products ORDER BY json_extract(data, \'\$.name\')',
        )
        .map((r) {
          final p = ProductMapper.fromJson(r['data'] as String);
          return store.user!.canManage ? p : p.copyWith(purchasePrice: 0);
        })
        .toList();
  }

  Product get(String id) {
    final row = store.database.handle.select(
      'SELECT data FROM products WHERE id = ?',
      [id],
    );
    if (row.isEmpty) throw const BusinessException('المنتج غير موجود.');
    return ProductMapper.fromJson(row.first['data'] as String);
  }

  void save(Product item) {
    store.require(manage: true);
    if (item.name.trim().isEmpty ||
        item.unit.trim().isEmpty ||
        item.salePrice < 0 ||
        item.purchasePrice < 0 ||
        item.factor < 1000 ||
        item.minStock < 0 ||
        (item.alternateUnit.isNotEmpty && item.alternateUnit == item.unit)) {
      throw const BusinessException('راجع الاسم والوحدات والأسعار.');
    }
    store.write(() {
      final duplicate = store.database.handle.select(
        'SELECT id FROM products WHERE barcode = ? AND id != ?',
        [item.barcode, item.id],
      );
      if (item.barcode.isNotEmpty && duplicate.isNotEmpty) {
        throw const BusinessException('الباركود مستخدم لمنتج آخر.');
      }
      final previous = store.database.handle.select(
        'SELECT data FROM products WHERE id = ?',
        [item.id],
      );
      if (previous.isNotEmpty &&
          store.database.handle.select(
            'SELECT id FROM stock_moves WHERE product_id = ? LIMIT 1',
            [item.id],
          ).isNotEmpty) {
        final old = ProductMapper.fromJson(previous.first['data'] as String);
        if (old.service != item.service ||
            old.unit != item.unit ||
            old.fractional != item.fractional) {
          throw const BusinessException(
            'لا يمكن تغيير نوع الصنف أو وحدته الأساسية أو الكسور بعد بدء حركته.',
          );
        }
      }
      store.database.handle.execute(
        'INSERT INTO products VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET barcode = excluded.barcode, data = excluded.data',
        [item.id, item.barcode.isEmpty ? null : item.barcode, item.toJson()],
      );
      store.audit('حفظ صنف', item.id, item.name);
    });
  }

  void opening(String id, int quantity, int unitCost) {
    store.require(manage: true);
    if (store.setting('opening_closed') == 'true') {
      throw const BusinessException('تم إقفال الافتتاح؛ استخدم تسوية موثقة.');
    }
    final item = get(id);
    if (item.service ||
        quantity <= 0 ||
        unitCost <= 0 ||
        (!item.fractional && quantity % 1000 != 0)) {
      throw const BusinessException('أدخل كمية افتتاحية وتكلفة صحيحتين.');
    }
    store.write(() {
      if (store.database.handle.select(
        'SELECT id FROM stock_moves WHERE product_id = ? LIMIT 1',
        [id],
      ).isNotEmpty) {
        throw const BusinessException(
          'بدأت حركة الصنف؛ استخدم تسوية مخزون بدل تعديل الافتتاح.',
        );
      }
      final value = Numbers.ratio(unitCost, quantity, 10000000);
      if (value == 0) {
        throw const BusinessException(
          'قيمة المخزون الافتتاحي أقل من دقة المبالغ.',
        );
      }
      final doc = engine.create(
        id: store.id(),
        kind: 'opening',
        total: value,
        notes: 'افتتاح مخزون ${item.name}',
      );
      engine.insert(doc, [debit('1300', value), credit('3900', value)]);
      engine.moveStock(doc.id, id, quantity, value, 'افتتاح');
    });
  }
}
