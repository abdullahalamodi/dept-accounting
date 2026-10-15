import 'dart:io';

import 'package:dept_accounting/core/data/database_rename.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('Rename copies committed WAL data once and keeps the source', () async {
    final directory = await Directory.systemTemp.createTemp(
      'dept_accounting-rename-',
    );
    final source = File(p.join(directory.path, 'legacy.sqlite'));
    final destination = File(p.join(directory.path, 'dept_accounting.sqlite'));
    final database = sqlite3.open(source.path);
    try {
      database.execute('PRAGMA journal_mode = WAL');
      database.execute('CREATE TABLE settings (value TEXT)');
      database.execute("INSERT INTO settings VALUES ('existing shop')");
      await copyLegacyDatabase(destination, [source]);
      expect(await source.exists(), isTrue);
      final renamed = sqlite3.open(destination.path);
      try {
        expect(
          renamed.select('SELECT value FROM settings').first['value'],
          'existing shop',
        );
        renamed.execute("UPDATE settings SET value = 'new shop'");
      } finally {
        renamed.close();
      }
      await copyLegacyDatabase(destination, [source]);
      final reopened = sqlite3.open(destination.path);
      try {
        expect(
          reopened.select('SELECT value FROM settings').first['value'],
          'new shop',
        );
        expect(
          database.select('SELECT value FROM settings').first['value'],
          'existing shop',
        );
      } finally {
        reopened.close();
      }
    } finally {
      database.close();
      await directory.delete(recursive: true);
    }
  });
}
