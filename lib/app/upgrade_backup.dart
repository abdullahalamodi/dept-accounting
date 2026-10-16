import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/numbers.dart';
import '../core/app_identity.dart';
import '../core/data/local_database.dart';
import '../features/backup/data/backup_files.dart';

const applicationVersion = '0.1.0+1';
Future<void> backupBeforeUpgrade(Database database, String path) async {
  if (database.userVersion == 0) return;
  if (database.userVersion > currentSchemaVersion) {
    throw const BusinessException('البيانات تحتاج إصدارًا أحدث من $appName.');
  }
  final shop = database.select("SELECT value FROM settings WHERE key = 'shop'");
  if (shop.isEmpty) return;
  final version = database.select(
    "SELECT value FROM settings WHERE key = 'app_version'",
  );
  if (database.userVersion == currentSchemaVersion &&
      version.isNotEmpty &&
      version.first['value'] == applicationVersion) {
    return;
  }
  final key = database.select(
    "SELECT value FROM settings WHERE key = 'backup_key'",
  );
  if (key.isEmpty) {
    throw const BusinessException(
      'مفتاح النسخ مفقود؛ احفظ البيانات الحالية قبل التحديث.',
    );
  }
  final temporary = await Directory.systemTemp.createTemp(
    'dept_accounting-upgrade-',
  );
  try {
    final snapshot = File(p.join(temporary.path, 'before-upgrade.sqlite')),
        target = sqlite3.open(p.join(temporary.path, 'before-upgrade.sqlite'));
    try {
      await database.backup(target, nPage: -1).drain<void>();
    } finally {
      target.close();
    }
    final secret = key.first['value'] as String;
    final encrypted = File(
      await BackupFiles.prepare(snapshot.path, temporary.path, secret),
    );
    final directory = await Directory(p.join(p.dirname(path), 'backups'))
        .create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        'dept_accounting-upgrade-${DateTime.now().toUtc().millisecondsSinceEpoch}.dept_accounting',
      ),
    );
    await BackupFiles.copyTo(encrypted, file);
  } finally {
    await temporary.delete(recursive: true);
  }
}
