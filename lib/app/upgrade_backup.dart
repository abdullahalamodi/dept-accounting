import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../core/numbers.dart';
import '../core/app_identity.dart';
import '../core/data/local_database.dart';
import '../features/backup/data/backup_codec.dart';

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
  final temporary = await Directory.systemTemp.createTemp('dukan-upgrade-');
  try {
    final snapshot = File(p.join(temporary.path, 'before-upgrade.sqlite')),
        target = sqlite3.open(p.join(temporary.path, 'before-upgrade.sqlite'));
    try {
      await database.backup(target).drain<void>();
    } finally {
      target.close();
    }
    final secret = key.first['value'] as String;
    final encrypted = await BackupCodec.encrypt(
      await snapshot.readAsBytes(),
      secret,
    );
    final verified = await BackupCodec.decrypt(encrypted, secret);
    await File(p.join(temporary.path, 'verified.sqlite'))
        .writeAsBytes(verified, flush: true);
    final check = sqlite3.open(
      p.join(temporary.path, 'verified.sqlite'),
      mode: OpenMode.readOnly,
    );
    try {
      if (check.select('PRAGMA integrity_check').first.values.first != 'ok') {
        throw const BusinessException('تعذر التحقق من نسخة ما قبل التحديث.');
      }
    } finally {
      check.close();
    }
    final directory = await Directory(p.join(p.dirname(path), 'backups'))
        .create(recursive: true);
    final file = File(
      p.join(
        directory.path,
        'dukan-upgrade-${DateTime.now().toUtc().millisecondsSinceEpoch}.dukan',
      ),
    );
    final partial = File('${file.path}.partial');
    await partial.writeAsBytes(encrypted, flush: true);
    await partial.rename(file.path);
  } finally {
    await temporary.delete(recursive: true);
  }
}
