import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/data/local_database.dart';
import '../../../core/numbers.dart';
import '../../auth/data/auth_models.dart';
import 'backup_codec.dart';

abstract final class BackupFiles {
  static Future<String> prepare(
    String snapshot,
    String directory,
    String key,
  ) => Isolate.run(() async {
    final encrypted = File(p.join(directory, 'encrypted.backup'));
    final verified = File(p.join(directory, 'verified.sqlite'));
    await BackupCodec.encryptFile(File(snapshot), encrypted, key);
    await BackupCodec.decryptFile(encrypted, verified, key);
    _validate(verified.path);
    return encrypted.path;
  });

  static Future<({Shop shop, String date})> decryptAndValidate(
    String source,
    String target,
    String key,
  ) => Isolate.run(() async {
    await BackupCodec.decryptFile(File(source), File(target), key);
    return _validate(target);
  });

  static ({Shop shop, String date}) _validate(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      if (db.userVersion < 1 ||
          db.userVersion > currentSchemaVersion ||
          db.select('PRAGMA integrity_check').first.values.first != 'ok' ||
          db.select('PRAGMA foreign_key_check').isNotEmpty) {
        throw const BusinessException(
          'النسخة تالفة أو غير متوافقة مع هذا الإصدار.',
        );
      }
      final shop = db.select("SELECT value FROM settings WHERE key = 'shop'");
      if (shop.isEmpty) {
        throw const BusinessException('النسخة لا تحتوي بيانات محل.');
      }
      final changed = db.select(
        "SELECT value FROM settings WHERE key = 'changed_at'",
      );
      return (
        shop: ShopMapper.fromJson(shop.first['value'] as String),
        date: changed.isEmpty ? '—' : changed.first['value'] as String,
      );
    } finally {
      db.close();
    }
  }

  static Future<void> copyTo(File source, File target) async {
    final partial = await source.copy('${target.path}.partial');
    final handle = await partial.open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
    await partial.rename(target.path);
  }
}
