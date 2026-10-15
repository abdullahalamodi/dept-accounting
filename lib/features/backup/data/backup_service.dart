import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../auth/data/auth_models.dart';
import 'folder_access.dart';
import 'backup_codec.dart';

class BackupNotice {
  const BackupNotice({
    required this.title,
    required this.message,
    this.warning = false,
  });

  final String title;
  final String message;
  final bool warning;
}

class BackupService {
  BackupService(this.store) {
    folders = FolderAccess(store);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => check());
    store.addListener(_changed);
    unawaited(check());
  }
  final AppStore store;
  late final FolderAccess folders;
  Timer? _timer;
  bool busy = false;
  bool _disposed = false;
  Completer<void>? _idle;
  String? error;
  final status = ValueNotifier<BackupNotice?>(null);
  void _refreshStatus() {
    if (_disposed) return;
    if (store.shop == null) {
      status.value = null;
      return;
    }
    if (error != null) {
      status.value = BackupNotice(
        title: 'تنبيه بشأن النسخ الاحتياطي',
        message: error!,
        warning: true,
      );
      return;
    }
    final last = store.setting('external_backup_at');
    if (last == null) {
      status.value = store.setting('external_backup_directory') == null
          ? const BackupNotice(
              title: 'لم تُعدّ النسخ الاحتياطي الخارجي بعد',
              message: 'لحماية بياناتك عند فقد الجهاز أو تعطله، افتح «الإعدادات والنسخ» واضغط «اختيار مجلد النسخة الخارجية» وحدد مجلدًا على USB أو قرص خارجي، ثم اضغط «إنشاء نسخة احتياطية الآن».',
            )
          : const BackupNotice(
              title: 'لم تُحفظ أول نسخة خارجية بعد',
              message: 'تم اختيار المجلد، لكن لم تُحفظ فيه نسخة بعد. وصّل USB أو القرص الخارجي، ثم افتح «الإعدادات والنسخ» واضغط «إنشاء نسخة احتياطية الآن».',
            );
    } else {
      status.value =
          DateTime.now().toUtc().difference(DateTime.parse(last)) >=
              const Duration(hours: 24)
          ? const BackupNotice(
              title: 'النسخة الخارجية متأخرة',
              message: 'مضت 24 ساعة أو أكثر منذ آخر نسخة خارجية ناجحة. وصّل USB أو القرص الخارجي، ثم افتح «الإعدادات والنسخ» واضغط «إنشاء نسخة احتياطية الآن» لحفظ أحدث بياناتك.',
              warning: true,
            )
          : null;
    }
  }

  void _changed() {
    if (store.shop != null) unawaited(check());
  }

  String get localDirectory =>
      p.join(p.dirname(store.database.path), 'backups');
  Future<List<int>> encrypt(List<int> bytes, String key) =>
      BackupCodec.encrypt(bytes, key);
  Future<List<int>> decrypt(List<int> bytes, String key) =>
      BackupCodec.decrypt(bytes, key);
  Future<void> check() async {
    if (_disposed) return;
    _refreshStatus();
    if (store.database.path == ':memory:') return;
    await folders.restore();
    if (_disposed) return;
    if (busy || store.shop == null || store.database.path == ':memory:') return;
    _refreshStatus();
    final changed = store.setting('changed_at'),
        last = store.setting('backup_at');
    final overdue =
        last == null ||
        DateTime.now().toUtc().difference(DateTime.parse(last)).inHours >= 1;
    final external = store.setting('external_backup_directory');
    final externalDue =
        external != null &&
        await Directory(external).exists() &&
        store.setting('external_backup_change') != changed;
    if ((overdue && changed != store.setting('backup_change')) || externalDue) {
      try {
        await backup(automatic: true);
      } catch (e) {
        error = e.toString();
      }
    }
  }

  Future<String> backup({
    bool automatic = false,
    bool forceLocal = false,
  }) async {
    if (!automatic) store.require(owner: true);
    if (busy) throw const BusinessException('توجد عملية نسخ قيد التنفيذ.');
    if (store.setting('backup_key') == null) {
      throw const BusinessException('لم يتم إعداد مفتاح النسخ.');
    }
    busy = true;
    _idle = Completer<void>();
    Directory? temporary;
    try {
      final changed = store.setting('changed_at') ?? '';
      temporary = await Directory.systemTemp.createTemp('dukan-backup-');
      final snapshot = await store.database.snapshot(temporary);
      final bytes = await snapshot.readAsBytes();
      final encrypted = await encrypt(bytes, store.setting('backup_key')!);
      // Verify decryption and SQLite integrity before recording a successful backup.
      final verified = File(p.join(temporary.path, 'verified.sqlite'));
      await verified.writeAsBytes(
        await decrypt(encrypted, store.setting('backup_key')!),
        flush: true,
      );
      _validate(verified.path);
      final filename =
          'dukan-${automatic ? 'auto' : 'manual'}-${DateTime.now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.dukan';
      final configured = forceLocal ? null : store.setting('backup_directory');
      var directory = Directory(configured ?? localDirectory);
      final primaryUnavailable =
          configured != null && !await directory.exists();
      if (configured == null || primaryUnavailable) {
        directory = await Directory(localDirectory).create(recursive: true);
      }
      final output = File(p.join(directory.path, filename));
      await _write(output, encrypted);
      final now = DateTime.now().toUtc().toIso8601String();
      store.setSetting('backup_at', now);
      store.setSetting('backup_change', changed);
      store.setSetting('backup_file', output.path);
      final external = store.setting('external_backup_directory');
      if (external != null && await Directory(external).exists()) {
        await _write(File(p.join(external, filename)), encrypted);
        store.setSetting('external_backup_at', now);
        store.setSetting('external_backup_change', changed);
      }
      if (automatic) await _prune(directory);
      error = primaryUnavailable
          ? 'حُفظت نسخة في مجلد التطبيق لأن مجلد النسخ الذي اخترته غير متاح. أعد توصيل القرص الذي يحتويه أو اختر مجلدًا آخر من «الإعدادات والنسخ».'
          : null;
      return output.path;
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      busy = false;
      _refreshStatus();
      try {
        await temporary?.delete(recursive: true);
      } finally {
        _idle?.complete();
      }
    }
  }

  Future<void> _prune(Directory directory) async {
    final files = await directory
        .list()
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith('dukan-auto-') &&
              e.path.endsWith('.dukan'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(48)) {
      await file.delete();
    }
  }

  Future<void> restoreFresh(List<int> file, String key) async {
    if (store.shop != null) {
      throw const BusinessException(
        'يوجد محل على الجهاز. استخدم الاستعادة من حساب المالك.',
      );
    }
    await _replace(file, key, existing: false);
  }

  Future<void> _replace(
    List<int> file,
    String key, {
    required bool existing,
  }) async {
    final directory = await Directory.systemTemp.createTemp('dukan-restore-');
    try {
      final temporary = File(p.join(directory.path, 'restore.sqlite'));
      await temporary.writeAsBytes(await decrypt(file, key), flush: true);
      _validate(temporary.path);
      if (existing) await backup(forceLocal: true);
      final source = sqlite3.open(temporary.path);
      try {
        await source.backup(store.database.handle).drain<void>();
      } finally {
        source.close();
      }
      store.setSetting('backup_key', key.trim());
      store.database.handle.execute(
        "DELETE FROM settings WHERE key IN ('backup_directory','external_backup_directory','backup_directory_bookmark','external_backup_directory_bookmark','backup_at','backup_change','backup_file','external_backup_at','external_backup_change')",
      );
      store.logout();
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<void> _write(File target, List<int> data) async {
    final temporary = File('${target.path}.partial');
    await temporary.writeAsBytes(data, flush: true);
    await temporary.rename(target.path);
  }

  Shop _validate(String path) {
    final db = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      if (db.userVersion != 1 ||
          db.select('PRAGMA integrity_check').first.values.first != 'ok') {
        throw const BusinessException(
          'النسخة تالفة أو غير متوافقة مع هذا الإصدار.',
        );
      }
      final settings = db.select(
        "SELECT value FROM settings WHERE key = 'shop'",
      );
      if (settings.isEmpty) {
        throw const BusinessException('النسخة لا تحتوي بيانات محل.');
      }
      return ShopMapper.fromJson(settings.first['value'] as String);
    } finally {
      db.close();
    }
  }

  Future<({Shop shop, String date})> inspect(List<int> file, String key) async {
    final directory = await Directory.systemTemp.createTemp('dukan-inspect-');
    try {
      final temporary = File(p.join(directory.path, 'restore.sqlite'));
      await temporary.writeAsBytes(await decrypt(file, key), flush: true);
      final shop = _validate(temporary.path);
      final source = sqlite3.open(temporary.path, mode: OpenMode.readOnly);
      try {
        final rows = source.select(
          "SELECT value FROM settings WHERE key = 'changed_at'",
        );
        return (
          shop: shop,
          date: rows.isEmpty ? '—' : rows.first['value'] as String,
        );
      } finally {
        source.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<void> restore(List<int> file, String key) async {
    store.require(owner: true);
    await _replace(file, key, existing: true);
  }

  Future<void> shutdown() async {
    dispose();
    await _idle?.future;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    status.dispose();
    _timer?.cancel();
    store.removeListener(_changed);
  }
}
