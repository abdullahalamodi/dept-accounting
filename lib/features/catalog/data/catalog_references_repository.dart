import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import 'catalog_reference.dart';

class CatalogReferencesRepository {
  CatalogReferencesRepository(this.store);
  final AppStore store;

  String _columns(CatalogReferenceKind kind, bool counts) {
    final relation = kind == CatalogReferenceKind.unit
        ? '(p.base_unit_id = r.id OR p.additional_unit_id = r.id)'
        : 'p.category_id = r.id';
    return "r.*, ${counts ? '(SELECT count(*) FROM products p WHERE $relation)' : '0'} AS product_count";
  }

  CatalogReference _reference(Map<String, Object?> row) => CatalogReference(
    id: row['id'] as String,
    name: row['name'] as String,
    active: row['active'] == 1,
    productCount: row['product_count'] as int,
  );

  CatalogReference? find(
    CatalogReferenceKind kind,
    String id, {
    bool counts = false,
  }) {
    store.require();
    if (id.isEmpty) return null;
    final rows = store.database.handle.select(
      'SELECT ${_columns(kind, counts)} FROM ${kind.table} r WHERE r.id = ?',
      [id],
    );
    return rows.isEmpty ? null : _reference(rows.first);
  }

  CatalogReference? defaultUnit() {
    store.require();
    final rows = store.database.handle.select(
      "SELECT ${_columns(CatalogReferenceKind.unit, false)} FROM units r WHERE active = 1 ORDER BY CASE WHEN id = 'unit_piece' THEN 0 ELSE 1 END, name COLLATE NOCASE,id LIMIT 1",
    );
    return rows.isEmpty ? null : _reference(rows.first);
  }

  QueryPage<CatalogReference> page(
    CatalogReferenceKind kind, {
    String search = '',
    bool showInactive = false,
    String excludeId = '',
    bool counts = true,
    int page = 1,
    int pageSize = 10,
  }) {
    store.require();
    final conditions = <String>[
      if (!showInactive) 'r.active = 1',
      if (excludeId.isNotEmpty) 'r.id != ?',
      if (search.trim().isNotEmpty) 'instr(app_lower(r.name), ?) > 0',
    ];
    final parameters = <Object?>[
      if (excludeId.isNotEmpty) excludeId,
      if (search.trim().isNotEmpty) search.trim().toLowerCase(),
    ];
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final db = store.database.handle;
    return QueryPage.read(
      total:
          db
                  .select(
                    'SELECT COUNT(*) AS n FROM ${kind.table} r $where',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => db
          .select(
            'SELECT ${_columns(kind, counts)} FROM ${kind.table} r $where ORDER BY r.name COLLATE NOCASE,r.id LIMIT ? OFFSET ?',
            [...parameters, limit, offset],
          )
          .map(_reference)
          .toList(),
    );
  }

  List<CatalogReference> all(CatalogReferenceKind kind) {
    store.require();
    return store.database.handle
        .select('''
      SELECT ${_columns(kind, true)}
      FROM ${kind.table} r ORDER BY r.name COLLATE NOCASE
    ''')
        .map(_reference)
        .toList();
  }

  CatalogReference resolve(
    CatalogReferenceKind kind, {
    required String id,
    required String name,
    String previousId = '',
  }) {
    store.require();
    final rows = store.database.handle.select(
      'SELECT ${_columns(kind, false)} FROM ${kind.table} r WHERE ${id.isNotEmpty ? 'id = ?' : 'app_lower(name) = ?'} LIMIT 1',
      [id.isNotEmpty ? id : name.trim().toLowerCase()],
    );
    final entry = rows.isEmpty ? null : _reference(rows.first);
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
      final previous = id == null ? null : find(kind, id, counts: true);
      if (id != null && previous == null) {
        throw const BusinessException('العنصر غير موجود.');
      }
      if (db.select(
        'SELECT id FROM ${kind.table} WHERE app_lower(name) = ? AND (? IS NULL OR id != ?) LIMIT 1',
        [clean.toLowerCase(), id, id],
      ).isNotEmpty) {
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
      final entry = find(kind, id);
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
