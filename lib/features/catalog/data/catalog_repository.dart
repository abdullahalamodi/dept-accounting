import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import 'product.dart';
import 'catalog_reference.dart';
import 'catalog_references_repository.dart';

class CatalogRepository {
  CatalogRepository(this.store, this.engine, this.references);
  final AppStore store;
  final PostingEngine engine;
  final CatalogReferencesRepository references;
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
        item.salePrice < 0 ||
        item.purchasePrice < 0 ||
        item.factor < 1000 ||
        item.minStock < 0) {
      throw const BusinessException('راجع الاسم والوحدات والأسعار.');
    }
    store.write(() {
      final duplicate = store.database.handle.select(
        'SELECT id FROM products WHERE barcode = ? AND id != ?',
        [item.barcode.trim(), item.id],
      );
      if (item.barcode.trim().isNotEmpty && duplicate.isNotEmpty) {
        throw const BusinessException('الباركود مستخدم لمنتج آخر.');
      }
      final previous = store.database.handle.select(
        'SELECT data FROM products WHERE id = ?',
        [item.id],
      );
      final old = previous.isEmpty
          ? null
          : ProductMapper.fromJson(previous.first['data'] as String);
      final unit = references.resolve(
        CatalogReferenceKind.unit,
        id: item.unitId,
        name: item.unit,
        previousId: old?.unitId ?? '',
      );
      final additional =
          item.service ||
              (item.alternateUnitId.isEmpty &&
                  item.alternateUnit.trim().isEmpty)
          ? null
          : references.resolve(
              CatalogReferenceKind.unit,
              id: item.alternateUnitId,
              name: item.alternateUnit,
              previousId: old?.alternateUnitId ?? '',
            );
      final category = item.categoryId.isEmpty && item.category.trim().isEmpty
          ? null
          : references.resolve(
              CatalogReferenceKind.category,
              id: item.categoryId,
              name: item.category,
              previousId: old?.categoryId ?? '',
            );
      if (unit.id == additional?.id) {
        throw const BusinessException(
          'اختر وحدة إضافية مختلفة عن الوحدة الأساسية.',
        );
      }
      if (old != null &&
          store.database.handle.select(
            'SELECT id FROM stock_moves WHERE product_id = ? LIMIT 1',
            [item.id],
          ).isNotEmpty &&
          (old.service != item.service ||
              old.unitId != unit.id ||
              old.fractional != item.fractional)) {
        throw const BusinessException(
          'لا يمكن تغيير نوع المنتج أو وحدته الأساسية أو الكسور بعد بدء حركته.',
        );
      }
      final saved = item.copyWith(
        name: item.name.trim(),
        barcode: item.barcode.trim(),
        categoryId: category?.id ?? '',
        category: category?.name ?? '',
        unitId: unit.id,
        unit: unit.name,
        alternateUnitId: additional?.id ?? '',
        alternateUnit: additional?.name ?? '',
        factor: additional == null ? 1000 : item.factor,
      );
      store.database.handle.execute(
        '''INSERT INTO products(id,barcode,data,category_id,base_unit_id,additional_unit_id)
        VALUES (?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET barcode=excluded.barcode,
        data=excluded.data,category_id=excluded.category_id,base_unit_id=excluded.base_unit_id,
        additional_unit_id=excluded.additional_unit_id''',
        [
          saved.id,
          saved.barcode.isEmpty ? null : saved.barcode,
          saved.toJson(),
          category?.id,
          unit.id,
          additional?.id,
        ],
      );
      store.audit('حفظ منتج', item.id, item.name);
    });
  }

  String? openingUnavailableReason([String? id]) {
    if (store.setting('opening_closed') == 'true') {
      return 'تم إقفال الافتتاح؛ استخدم تسوية موثقة.';
    }
    if (id == null) return null;
    if (get(id).service) return 'الخدمات لا تحتاج إلى مخزون افتتاحي.';
    if (store.database.handle.select(
      'SELECT id FROM stock_moves WHERE product_id = ? LIMIT 1',
      [id],
    ).isNotEmpty) {
      return 'بدأت حركة المنتج؛ استخدم تسوية مخزون بدل تعديل الافتتاح.';
    }
    return null;
  }

  void opening(String id, int quantity) {
    store.require(manage: true);
    store.write(() {
      final unavailable = openingUnavailableReason(id);
      if (unavailable != null) throw BusinessException(unavailable);
      final item = get(id);
      if (quantity <= 0 || (!item.fractional && quantity % 1000 != 0)) {
        throw const BusinessException(
          'أدخل كمية افتتاحية صحيحة بالوحدة الأساسية.',
        );
      }
      if (item.purchasePrice <= 0) {
        throw const BusinessException(
          'أضف سعر شراء للمنتج قبل تسجيل مخزونه الافتتاحي.',
        );
      }
      final value = Numbers.ratio(item.purchasePrice, quantity, 1000);
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
