import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import 'catalog_reference.dart';

class CatalogReferencesRepository {
  CatalogReferencesRepository(this.store);
  final AppStore store;

  List<CatalogReference> all(CatalogReferenceKind kind) {
    store.require();
    final relation = kind == CatalogReferenceKind.unit
        ? '(p.base_unit_id = r.id OR p.additional_unit_id = r.id)'
        : 'p.category_id = r.id';
    return store.database.handle
        .select('''
      SELECT r.*, (SELECT count(*) FROM products p WHERE $relation) AS product_count
      FROM ${kind.table} r ORDER BY r.name COLLATE NOCASE
    ''')
        .map(
          (row) => CatalogReference(
            id: row['id'] as String,
            name: row['name'] as String,
            active: row['active'] == 1,
            productCount: row['product_count'] as int,
          ),
        )
        .toList();
  }

  CatalogReference resolve(
    CatalogReferenceKind kind, {
    required String id,
    required String name,
    String previousId = '',
  }) {
    final entry = all(kind)
        .where(
          (r) => id.isNotEmpty
              ? r.id == id
              : r.name.toLowerCase() == name.trim().toLowerCase(),
        )
        .firstOrNull;
    if (entry == null || (!entry.active && entry.id != previousId)) {
      throw BusinessException('اختر ${kind.label} من القائمة النشطة.');
    }
    return entry;
  }

  CatalogReference save(
    CatalogReferenceKind kind, {
    String? id,
    required String name,
  }) {
    store.require(manage: true);
    final clean = name.trim();
    if (clean.isEmpty) throw BusinessException('أدخل اسم ${kind.label}.');
    return store.write(() {
      final db = store.database.handle;
      final entries = all(kind);
      final previous = entries.where((r) => r.id == id).firstOrNull;
      if (id != null && previous == null) {
        throw const BusinessException('العنصر غير موجود.');
      }
      if (entries.any(
        (r) => r.id != id && r.name.toLowerCase() == clean.toLowerCase(),
      )) {
        throw BusinessException(
          'اسم ${kind.label} مستخدم بالفعل، بما في ذلك العناصر الموقوفة.',
        );
      }
      final result = CatalogReference(
        id: id ?? store.id(),
        name: clean,
        active: previous?.active ?? true,
        productCount: previous?.productCount ?? 0,
      );
      db.execute(
        'INSERT INTO ${kind.table}(id,name,active) VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name',
        [result.id, result.name, result.active ? 1 : 0],
      );
      // Keep current product labels in sync; posted document snapshots stay immutable.
      final columns = kind == CatalogReferenceKind.unit
          ? {'base_unit_id': 'unit', 'additional_unit_id': 'alternateUnit'}
          : {'category_id': 'category'};
      for (final entry in columns.entries) {
        db.execute(
          "UPDATE products SET data=json_set(data, '\$.${entry.value}', ?) WHERE ${entry.key}=?",
          [clean, result.id],
        );
      }
      store.audit('حفظ ${kind.label}', result.id, clean);
      return result;
    });
  }

  void setActive(CatalogReferenceKind kind, String id, bool active) {
    store.require(manage: true);
    store.write(() {
      final entry = all(kind).where((r) => r.id == id).firstOrNull;
      if (entry == null) throw const BusinessException('العنصر غير موجود.');
      store.database.handle.execute(
        'UPDATE ${kind.table} SET active=? WHERE id=?',
        [active ? 1 : 0, id],
      );
      store.audit(
        active ? 'تفعيل ${kind.label}' : 'إيقاف ${kind.label}',
        id,
        entry.name,
      );
    });
  }
}
