import 'dart:convert';
import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';
import 'package:dept_accounting/features/catalog/data/catalog_reference.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const owner = AppUser(
  id: 'owner',
  name: 'مالك',
  username: 'owner',
  role: 'owner',
);

// Only the v1 tables read by catalog migration and fresh restore are needed.
Database legacyDatabase(String path) {
  final db = sqlite3.open(path);
  db.execute('''
    CREATE TABLE products(id TEXT PRIMARY KEY,barcode TEXT UNIQUE,data TEXT NOT NULL);
    CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL);
    CREATE TABLE documents(id TEXT PRIMARY KEY,data TEXT NOT NULL);
  ''');
  db.execute('INSERT INTO settings VALUES (?,?)', [
    'shop',
    const Shop(name: 'قديم', currency: 'YER').toJson(),
  ]);
  for (final id in ['p', 'q']) {
    final data = const Product(
      id: 'unused',
      name: 'أسلاك',
      unit: 'لفة',
      alternateUnit: 'بكرة',
      factor: 12500,
      category: 'تمديدات',
    ).toMap();
    data['id'] = id;
    data.removeWhere(
      (key, _) => ['unitId', 'alternateUnitId', 'categoryId'].contains(key),
    );
    db.execute('INSERT INTO products VALUES (?,NULL,?)', [
      id,
      jsonEncode(data),
    ]);
  }
  db.execute('INSERT INTO documents VALUES (?,?)', [
    'old',
    '{"unit":"بكرة","factor":12500}',
  ]);
  db.userVersion = 1;
  return db;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'v1 migration preserves custom names and factors and runs only once',
    () {
      final db = LocalDatabase.fromHandle(
        legacyDatabase(':memory:'),
        ':memory:',
      );
      addTearDown(db.close);
      final rows = db.handle.select('SELECT * FROM products ORDER BY id');
      expect(db.handle.userVersion, currentSchemaVersion);
      expect(rows.first['base_unit_id'], rows.last['base_unit_id']);
      expect(rows.first['additional_unit_id'], rows.last['additional_unit_id']);
      expect(rows.first['category_id'], rows.last['category_id']);
      final p = ProductMapper.fromJson(rows.first['data'] as String);
      expect(
        [p.unit, p.alternateUnit, p.category, p.factor],
        ['لفة', 'بكرة', 'تمديدات', 12500],
      );
      expect(p.unitId, rows.first['base_unit_id']);
      expect(db.handle.select('PRAGMA foreign_key_check'), isEmpty);
      expect(
        db.handle.select('SELECT data FROM documents').single['data'],
        '{"unit":"بكرة","factor":12500}',
      );
      final count = db.handle
          .select('SELECT count(*) AS n FROM units')
          .single['n'];
      db.migrate();
      expect(
        db.handle.select('SELECT count(*) AS n FROM units').single['n'],
        count,
      );
      expect(
        () => db.handle.execute(
          'UPDATE products SET additional_unit_id=base_unit_id',
        ),
        throwsA(isA<SqliteException>()),
      );
      expect(
        () => db.handle.execute('UPDATE products SET base_unit_id=NULL'),
        throwsA(isA<SqliteException>()),
      );
    },
  );

  test(
    'restoring v1 and v2 backups retains managed lists and references',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dept_accounting-catalog-restore-',
      );
      final legacy = legacyDatabase('${directory.path}/legacy.sqlite');
      legacy.close();
      final d = AppDependencies(LocalDatabase.memory());
      final key = Passwords.token(32);
      try {
        final encrypted = await d.backups.encrypt(
          await File('${directory.path}/legacy.sqlite').readAsBytes(),
          key,
        );
        expect((await d.backups.inspect(encrypted, key)).shop.name, 'قديم');
        await d.backups.restoreFresh(encrypted, key);
        d.store.user = owner;
        expect(d.catalog.get('p').alternateUnit, 'بكرة');
        expect(d.store.database.handle.userVersion, currentSchemaVersion);
        expect(
          d.catalogReferences
              .all(CatalogReferenceKind.category)
              .where((r) => r.name == 'تمديدات'),
          hasLength(1),
        );
        final snapshot = await d.store.database.snapshot(directory);
        final encryptedV2 = await d.backups.encrypt(
          await snapshot.readAsBytes(),
          key,
        );
        final target = AppDependencies(LocalDatabase.memory());
        try {
          await target.backups.restoreFresh(encryptedV2, key);
          target.store.user = owner;
          expect(target.catalog.get('p').unitId, d.catalog.get('p').unitId);
          expect(
            target.store.database.handle.select('PRAGMA foreign_key_check'),
            isEmpty,
          );
        } finally {
          await target.backups.shutdown();
          target.store.dispose();
          target.store.database.close();
        }
      } finally {
        await d.backups.shutdown();
        d.store.dispose();
        d.store.database.close();
        await directory.delete(recursive: true);
      }
    },
  );

  group('managed catalog', () {
    late AppDependencies d;
    setUp(() {
      d = AppDependencies(LocalDatabase.memory());
      d.store.user = owner;
      d.store.setSetting(
        'shop',
        const Shop(name: 'اختبار', currency: 'YER').toJson(),
      );
    });
    tearDown(() async {
      await d.backups.shutdown();
      d.store.dispose();
      d.store.database.close();
    });

    test('unit roles and conversion factors belong to each product; snapshots survive renaming', () {
      final category = d.catalogReferences.save(
        CatalogReferenceKind.category,
        name: 'إضاءة',
      );
      d.catalog.save(
        Product(
          id: 'p',
          name: 'مصباح',
          categoryId: category.id,
          unitId: 'unit_piece',
          alternateUnitId: 'unit_carton',
          factor: 12000,
          purchasePrice: 100,
          salePrice: 200,
        ),
      );
      d.catalog.save(
        const Product(id: 'q', name: 'كرتون كامل', unitId: 'unit_carton'),
      );
      d.catalog.save(
        const Product(
          id: 'r',
          name: 'مصباح آخر',
          alternateUnitId: 'unit_carton',
          factor: 24000,
        ),
      );
      d.finance.openAccount('1100', 2000);
      d.parties.save(const Party(id: 'supplier', name: 'مورد', supplier: true));
      final document = d.invoices.post(
        requestId: 'buy',
        sale: false,
        partyId: 'supplier',
        payments: const [Payment(account: '1100', amount: 1200)],
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح',
            unit: 'كرتون',
            factor: 12000,
            quantity: 1000,
            price: 1200,
          ),
        ],
      );
      d.catalogReferences.save(
        CatalogReferenceKind.unit,
        id: 'unit_carton',
        name: 'صندوق',
      );
      d.catalogReferences.save(
        CatalogReferenceKind.unit,
        id: 'unit_piece',
        name: 'قطعة',
      );
      d.catalogReferences.save(
        CatalogReferenceKind.category,
        id: category.id,
        name: 'إنارة',
      );
      final p = d.catalog.get('p');
      expect(
        [p.unit, p.alternateUnit, p.category, p.factor],
        ['قطعة', 'صندوق', 'إنارة', 12000],
      );
      expect(d.catalog.get('q').unit, 'صندوق');
      expect(d.catalog.get('r').factor, 24000);
      expect(d.invoices.get(document.id).lines.single.unit, 'كرتون');
      expect(d.invoices.get(document.id).lines.single.factor, 12000);
      // Renaming is allowed after stock movement because identity is unchanged.
      d.catalog.save(p.copyWith(name: 'مصباح محدث'));
      expect(
        () => d.catalog.save(p.copyWith(unitId: 'unit_metre')),
        throwsA(isA<BusinessException>()),
      );
      expect(
        d.catalogReferences
            .all(CatalogReferenceKind.unit)
            .singleWhere((r) => r.id == 'unit_carton')
            .productCount,
        3,
      );
    });

    test('inactive entries remain on existing products and cannot be assigned to new ones', () {
      final category = d.catalogReferences.save(
        CatalogReferenceKind.category,
        name: 'إضاءة',
      );
      d.catalog.save(
        Product(
          id: 'p',
          name: 'مصباح',
          categoryId: category.id,
          alternateUnitId: 'unit_carton',
          factor: 12000,
        ),
      );
      for (final id in ['unit_piece', 'unit_carton']) {
        d.catalogReferences.setActive(CatalogReferenceKind.unit, id, false);
      }
      d.catalogReferences.setActive(
        CatalogReferenceKind.category,
        category.id,
        false,
      );
      d.catalog.save(d.catalog.get('p').copyWith(salePrice: 500));
      expect(d.catalog.get('p').salePrice, 500);
      expect(
        () => d.catalog.save(const Product(id: 'new', name: 'جديد')),
        throwsA(isA<BusinessException>()),
      );
      d.catalogReferences.setActive(
        CatalogReferenceKind.unit,
        'unit_piece',
        true,
      );
      expect(
        () => d.catalog.save(
          Product(id: 'new', name: 'جديد', categoryId: category.id),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.catalog.save(
          const Product(
            id: 'new',
            name: 'جديد',
            alternateUnitId: 'unit_carton',
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      d.catalog.save(
        d.catalog
            .get('p')
            .copyWith(
              category: '',
              categoryId: '',
              alternateUnit: '',
              alternateUnitId: '',
            ),
      );
      expect(d.catalog.get('p').factor, 1000);
      expect(d.catalog.get('p').alternateUnitId, isEmpty);
      expect(
        () => d.catalogReferences.save(
          CatalogReferenceKind.unit,
          name: ' كرتون ',
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.catalog.save(
          const Product(
            id: 'invalid',
            name: 'مكرر',
            alternateUnitId: 'unit_piece',
          ),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.catalog.save(
          const Product(id: 'unknown', name: 'غير معروف', unitId: 'unknown'),
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () =>
            d.catalogReferences.save(CatalogReferenceKind.category, name: '  '),
        throwsA(isA<BusinessException>()),
      );
      d.store.user = const AppUser(
        id: 'seller',
        name: 'بائع',
        username: 'seller',
        role: 'seller',
      );
      expect(
        () =>
            d.catalogReferences.save(CatalogReferenceKind.unit, name: 'ممنوع'),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.catalogReferences.setActive(
          CatalogReferenceKind.category,
          category.id,
          true,
        ),
        throwsA(isA<BusinessException>()),
      );
    });
  });
}
