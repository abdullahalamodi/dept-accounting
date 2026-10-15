import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

/// Runs inside the database migration transaction; invoice snapshots are untouched.
void migrateCatalogReferences(Database db) {
  db.execute('''
    CREATE TABLE units (
      id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)));
    CREATE UNIQUE INDEX units_name ON units(lower(trim(name)));
    CREATE TABLE categories (
      id TEXT PRIMARY KEY, name TEXT NOT NULL CHECK(length(trim(name)) > 0),
      active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0,1)));
    CREATE UNIQUE INDEX categories_name ON categories(lower(trim(name)));
    ALTER TABLE products ADD COLUMN category_id TEXT REFERENCES categories(id);
    ALTER TABLE products ADD COLUMN base_unit_id TEXT REFERENCES units(id);
    ALTER TABLE products ADD COLUMN additional_unit_id TEXT REFERENCES units(id)
      CHECK(additional_unit_id IS NULL OR additional_unit_id <> base_unit_id);
    CREATE INDEX products_category ON products(category_id);
    CREATE INDEX products_base_unit ON products(base_unit_id);
    CREATE INDEX products_additional_unit ON products(additional_unit_id);
  ''');
  const units = {
    'piece': 'حبة',
    'pair': 'زوج',
    'set': 'طقم',
    'carton': 'كرتون',
    'box': 'علبة',
    'bag': 'كيس',
    'roll': 'لفة',
    'metre': 'متر',
    'centimetre': 'سنتيمتر',
    'kilogram': 'كيلوجرام',
    'gram': 'جرام',
    'litre': 'لتر',
    'millilitre': 'مليلتر',
    'hour': 'ساعة',
  };
  const categories = {
    'household': 'أدوات منزلية',
    'kitchen': 'أدوات مطبخ',
    'electrical': 'أدوات كهربائية',
    'appliances': 'أجهزة كهربائية',
    'lighting': 'إنارة ولمبات',
    'cables': 'أسلاك وكابلات',
    'switches': 'مفاتيح وأفياش',
    'plumbing': 'أدوات صحية',
    'tools': 'عدد وأدوات يدوية',
    'cleaning': 'مواد تنظيف',
    'services': 'خدمات تركيب وصيانة',
  };
  for (final entry in units.entries) {
    db.execute('INSERT INTO units(id,name) VALUES (?,?)', [
      'unit_${entry.key}',
      entry.value,
    ]);
  }
  for (final entry in categories.entries) {
    db.execute('INSERT INTO categories(id,name) VALUES (?,?)', [
      'category_${entry.key}',
      entry.value,
    ]);
  }
  var next = 0;
  String reference(String table, String name) {
    final rows = db.select(
      'SELECT id FROM $table WHERE lower(trim(name)) = lower(?)',
      [name],
    );
    if (rows.isNotEmpty) return rows.first['id'] as String;
    final id = 'legacy_${table}_${next++}';
    db.execute('INSERT INTO $table(id,name) VALUES (?,?)', [id, name]);
    return id;
  }

  for (final row in db.select('SELECT id,data FROM products')) {
    final data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    final category = (data['category'] as String? ?? '').trim();
    final unit = (data['unit'] as String? ?? 'حبة').trim();
    final additional = (data['alternateUnit'] as String? ?? '').trim();
    final categoryId = category.isEmpty
        ? ''
        : reference('categories', category);
    final unitId = reference('units', unit);
    final additionalId = additional.isEmpty
        ? ''
        : reference('units', additional);
    data.addAll({
      'category': category,
      'unit': unit,
      'alternateUnit': additional,
      'categoryId': categoryId,
      'unitId': unitId,
      'alternateUnitId': additionalId,
    });
    db.execute(
      'UPDATE products SET data=?,category_id=?,base_unit_id=?,additional_unit_id=? WHERE id=?',
      [
        jsonEncode(data),
        categoryId.isEmpty ? null : categoryId,
        unitId,
        additionalId.isEmpty ? null : additionalId,
        row['id'],
      ],
    );
  }
  db.execute('''
    CREATE TRIGGER products_require_base_insert BEFORE INSERT ON products
      WHEN NEW.base_unit_id IS NULL BEGIN SELECT RAISE(ABORT,'base unit required'); END;
    CREATE TRIGGER products_require_base_update BEFORE UPDATE OF base_unit_id ON products
      WHEN NEW.base_unit_id IS NULL BEGIN SELECT RAISE(ABORT,'base unit required'); END;
  ''');
}
