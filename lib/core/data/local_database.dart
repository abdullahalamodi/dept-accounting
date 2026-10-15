import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../numbers.dart';
import 'catalog_migration.dart';
import 'database_rename.dart';

const currentSchemaVersion = 2;

class LocalDatabase {
  LocalDatabase.fromHandle(this.handle, this.path) {
    migrate();
  }
  final Database handle;
  final String path;
  static Future<LocalDatabase> open({
    Future<void> Function(Database, String)? beforeMigration,
  }) async {
    final support = await getApplicationSupportDirectory();
    // Windows derives support from the display name; use a stable technical name.
    final directory = Platform.isWindows
        ? Directory(p.join(p.dirname(support.path), 'dept_accounting'))
        : support;
    await directory.create(recursive: true);
    final path = p.join(directory.path, 'dept_accounting.sqlite');
    // Legacy names are used only to copy existing data during the rename.
    await copyLegacyDatabase(File(path), [
      File(p.join(directory.path, 'dukan.sqlite')),
      if (Platform.isWindows)
        File(p.join(p.dirname(support.path), 'dukan_app', 'dukan.sqlite')),
      if (Platform.isMacOS)
        File(
          p.join(
            p.dirname(support.path),
            'com.example.dukanApp',
            'dukan.sqlite',
          ),
        ),
    ]);
    final handle = sqlite3.open(path);
    try {
      await beforeMigration?.call(handle, path);
      return LocalDatabase.fromHandle(handle, path);
    } catch (_) {
      handle.close();
      rethrow;
    }
  }

  factory LocalDatabase.memory() =>
      LocalDatabase.fromHandle(sqlite3.openInMemory(), ':memory:');

  void migrate() {
    handle.execute('PRAGMA foreign_keys = ON');
    handle.execute('PRAGMA busy_timeout = 5000');
    handle.execute('PRAGMA journal_mode = WAL');
    handle.execute('PRAGMA synchronous = FULL');
    if (handle.userVersion > currentSchemaVersion) {
      throw const BusinessException(
        'قاعدة البيانات أحدث من هذا الإصدار. حدّث التطبيق.',
      );
    }
    if (handle.userVersion == currentSchemaVersion) return;
    transaction(() {
      if (handle.userVersion == 0) {
        handle.execute('''
        CREATE TABLE settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE users (id TEXT PRIMARY KEY, username TEXT NOT NULL UNIQUE COLLATE NOCASE,
          data TEXT NOT NULL, password TEXT NOT NULL);
        CREATE TABLE products (id TEXT PRIMARY KEY, barcode TEXT UNIQUE, data TEXT NOT NULL);
        CREATE TABLE parties (id TEXT PRIMARY KEY, data TEXT NOT NULL);
        CREATE TABLE accounts (code TEXT PRIMARY KEY, name TEXT NOT NULL, kind TEXT NOT NULL,
          cash INTEGER NOT NULL DEFAULT 0 CHECK(cash IN (0,1)));
        CREATE TABLE sequences (kind TEXT PRIMARY KEY, next INTEGER NOT NULL CHECK(next > 0));
        CREATE TABLE documents (id TEXT PRIMARY KEY, kind TEXT NOT NULL, number TEXT NOT NULL UNIQUE,
          party_id TEXT REFERENCES parties(id), posted_at TEXT NOT NULL, data TEXT NOT NULL,
          source_id TEXT REFERENCES documents(id));
        CREATE TABLE journal (id INTEGER PRIMARY KEY, document_id TEXT NOT NULL REFERENCES documents(id),
          account TEXT NOT NULL REFERENCES accounts(code), party_id TEXT REFERENCES parties(id),
          debit INTEGER NOT NULL DEFAULT 0 CHECK(debit >= 0),
          credit INTEGER NOT NULL DEFAULT 0 CHECK(credit >= 0), CHECK(debit = 0 OR credit = 0));
        CREATE TABLE stock (product_id TEXT PRIMARY KEY REFERENCES products(id),
          quantity INTEGER NOT NULL DEFAULT 0 CHECK(quantity >= 0),
          value INTEGER NOT NULL DEFAULT 0 CHECK(value >= 0));
        CREATE TABLE stock_moves (id INTEGER PRIMARY KEY, document_id TEXT NOT NULL REFERENCES documents(id),
          product_id TEXT NOT NULL REFERENCES products(id), quantity INTEGER NOT NULL,
          value INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '');
        CREATE TABLE allocations (id INTEGER PRIMARY KEY, payment_id TEXT NOT NULL REFERENCES documents(id),
          invoice_id TEXT NOT NULL REFERENCES documents(id), amount INTEGER NOT NULL CHECK(amount > 0));
        CREATE TABLE drafts (id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id),
          kind TEXT NOT NULL, updated_at TEXT NOT NULL, data TEXT NOT NULL);
        CREATE TABLE audit (id INTEGER PRIMARY KEY, user_id TEXT, at TEXT NOT NULL, action TEXT NOT NULL,
          entity TEXT NOT NULL, details TEXT NOT NULL DEFAULT '');
        CREATE INDEX journal_account ON journal(account, party_id);
        CREATE INDEX journal_document ON journal(document_id);
        CREATE INDEX stock_document ON stock_moves(document_id);
        CREATE INDEX allocations_invoice ON allocations(invoice_id);
        CREATE INDEX documents_party ON documents(party_id, kind);
      ''');
        const accounts = [
          ('1100', 'الصندوق الرئيسي', 'asset', 1),
          ('1200', 'ذمم العملاء', 'asset', 0),
          ('1300', 'المخزون', 'asset', 0),
          ('2100', 'ذمم الموردين', 'liability', 0),
          ('2200', 'بضاعة مستلمة غير مفوترة', 'liability', 0),
          ('3100', 'رأس المال', 'equity', 0),
          ('3200', 'مسحوبات المالك', 'equity', 0),
          ('3900', 'التسوية الافتتاحية', 'equity', 0),
          ('4100', 'مبيعات المنتجات', 'income', 0),
          ('4200', 'إيرادات الخدمات', 'income', 0),
          ('5100', 'تكلفة البضاعة المباعة', 'expense', 0),
          ('6100', 'مصروفات تشغيلية', 'expense', 0),
          ('6200', 'تالف وفروق المخزون', 'expense', 0),
          ('6900', 'فروق التقريب', 'expense', 0),
        ];
        for (final (code, name, kind, cash) in accounts) {
          handle.execute('INSERT INTO accounts VALUES (?, ?, ?, ?)', [
            code,
            name,
            kind,
            cash,
          ]);
        }
        handle.userVersion = 1;
      }
      if (handle.userVersion == 1) {
        migrateCatalogReferences(handle);
        handle.userVersion = currentSchemaVersion;
      }
    });
  }

  T transaction<T>(T Function() body) {
    handle.execute('BEGIN IMMEDIATE');
    try {
      final result = body();
      handle.execute('COMMIT');
      return result;
    } catch (_) {
      handle.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<File> snapshot(Directory directory) async {
    final file = File(
      p.join(
        directory.path,
        'snapshot-${DateTime.now().microsecondsSinceEpoch}.sqlite',
      ),
    );
    final target = sqlite3.open(file.path);
    try {
      await handle.backup(target).drain<void>();
    } finally {
      target.close();
    }
    return file;
  }

  void close() => handle.close();
}
