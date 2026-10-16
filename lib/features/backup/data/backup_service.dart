import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

import '../../../core/data/app_store.dart';
import '../../../core/data/store_tasks.dart';
import '../../../core/numbers.dart';
import '../../auth/data/auth_models.dart';
import 'folder_access.dart';
import 'backup_codec.dart';
import 'backup_files.dart';

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
  BackupService(this.store, {DateTime Function()? now})
    : _now = now ?? DateTime.now {
    folders = FolderAccess(store);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => check());
    store.addListener(_changed);
    unawaited(check(flush: true));
  }
  final AppStore store;
  final DateTime Function() _now;
  static const externalDelay = Duration(minutes: 5);
  DateTime? _externalDirtySince;
  String? _observedExternal;
  bool _externalWasAvailable = false;
  Future<void>? _checking;
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
          _now().toUtc().difference(DateTime.parse(last)) >=
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
    if (store.shop != null) {
      _externalDirtySince ??= _now().toUtc();
      unawaited(check());
    }
  }

  String get localDirectory =>
      p.join(p.dirname(store.database.path), 'backups');
  Future<List<int>> encrypt(List<int> bytes, String key) =>
      BackupCodec.encrypt(bytes, key);
  Future<List<int>> decrypt(List<int> bytes, String key) =>
      BackupCodec.decrypt(bytes, key);
  Future<void> check({bool flush = false}) async {
    if (_disposed) return;
    final pending = _checking;
    if (pending != null) {
      await pending;
      // A resume/shutdown request must not inherit a concurrent delayed check.
      if (flush) await check(flush: true);
      return;
    }
    final completion = Completer<void>();
    _checking = completion.future;
    try {
      await _check(flush: flush);
    } finally {
      _checking = null;
      completion.complete();
    }
  }

  Future<void> _check({required bool flush}) async {
    try {
      await _checkDue(flush: flush);
    } catch (e) {
      error = e.toString();
    } finally {
      _refreshStatus();
    }
  }

  Future<void> _checkDue({required bool flush}) async {
    if (_disposed || store.executor?.maintenance == true) return;
    _refreshStatus();
    if (store.database.path == ':memory:') return;
    await folders.restore();
    if (_disposed) return;
    if (busy ||
        store.executor?.maintenance == true ||
        store.shop == null ||
        store.database.path == ':memory:') {
      return;
    }
    _refreshStatus();
    final changed = store.setting('changed_at'),
        last = store.setting('backup_at');
    final overdue =
        last == null ||
        _now().toUtc().difference(DateTime.parse(last)).inHours >= 1;
    final external = store.setting('external_backup_directory');
    if (_observedExternal != external) {
      _observedExternal = external;
      _externalWasAvailable = false;
    }
    final available = external != null && await Directory(external).exists();
    final reconnected = available && !_externalWasAvailable;
    _externalWasAvailable = available;
    if (changed == store.setting('external_backup_change')) {
      _externalDirtySince = null;
    }
    final externalDue =
        available &&
        store.setting('external_backup_change') != changed &&
        (flush ||
            reconnected ||
            _externalDirtySince == null ||
            _now().toUtc().difference(_externalDirtySince!) >= externalDelay);
    if (store.executor?.maintenance == true) return;
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
    _externalDirtySince = null;
    final completion = _idle = Completer<void>();
    Directory? temporary;
    try {
      final changed = store.setting('changed_at') ?? '';
      temporary = await Directory.systemTemp.createTemp(
        'dept_accounting-backup-',
      );
      final snapshot = await store.snapshot(temporary);
      final encrypted = File(
        await BackupFiles.prepare(
          snapshot.path,
          temporary.path,
          store.setting('backup_key')!,
        ),
      );
      final filename =
          'dept_accounting-${automatic ? 'auto' : 'manual'}-${_now().toUtc().toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}.dept_accounting';
      final configured = forceLocal ? null : store.setting('backup_directory');
      var directory = Directory(configured ?? localDirectory);
      final primaryUnavailable =
          configured != null && !await directory.exists();
      if (configured == null || primaryUnavailable) {
        directory = await Directory(localDirectory).create(recursive: true);
      }
      final output = File(p.join(directory.path, filename));
      await BackupFiles.copyTo(encrypted, output);
      final now = _now().toUtc().toIso8601String();
      await store.setSettings({
        'backup_at': now,
        'backup_change': changed,
        'backup_file': output.path,
      });
      final external = store.setting('external_backup_directory');
      if (external != null && await Directory(external).exists()) {
        final sameDirectory = p.equals(
          p.normalize(p.absolute(external)),
          p.normalize(p.absolute(directory.path)),
        );
        if (!sameDirectory) {
          await BackupFiles.copyTo(encrypted, File(p.join(external, filename)));
        }
        await store.setSettings({
          'external_backup_at': now,
          'external_backup_change': changed,
        });
        if (automatic && !sameDirectory) await _prune(Directory(external));
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
      try {
        await temporary?.delete(recursive: true);
      } finally {
        busy = false;
        _refreshStatus();
        completion.complete();
      }
    }
  }

  Future<void> _prune(Directory directory) async {
    final files = await directory
        .list()
        .where(
          (e) =>
              e is File &&
              p.basename(e.path).startsWith('dept_accounting-auto-') &&
              e.path.endsWith('.dept_accounting'),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(48)) {
      await file.delete();
    }
  }

  Future<T> _withBytes<T>(
    List<int> bytes,
    Future<T> Function(File) action,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'dept-backup-input-',
    );
    try {
      final input = await File(p.join(directory.path, 'input.backup'))
          .writeAsBytes(bytes, flush: true);
      return await action(input);
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<void> restoreFresh(List<int> file, String key) =>
      _withBytes(file, (input) => restoreFreshFile(input, key));

  Future<void> restoreFreshFile(File file, String key) async {
    if (store.shop != null) {
      throw const BusinessException(
        'يوجد محل على الجهاز. استخدم الاستعادة من حساب المالك.',
      );
    }
    await _replace(file, key, existing: false);
  }

  Future<void> _replace(File file, String key, {required bool existing}) async {
    final directory = await Directory.systemTemp.createTemp(
      'dept_accounting-restore-',
    );
    try {
      final temporary = File(p.join(directory.path, 'restore.sqlite'));
      await BackupFiles.decryptAndValidate(file.path, temporary.path, key);
      await _checking;
      await _idle?.future;
      Future<void> replace() async {
        if (existing) await backup(forceLocal: true);
        await store.run(
          StoreTasks.restore(temporary.path, key, existing: existing),
        );
      }

      final executor = store.executor;
      if (executor == null) {
        await replace();
      } else {
        await executor.exclusive(replace);
      }
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<({Shop shop, String date})> inspect(List<int> file, String key) =>
      _withBytes(file, (input) => inspectFile(input, key));

  Future<({Shop shop, String date})> inspectFile(File file, String key) async {
    final directory = await Directory.systemTemp.createTemp(
      'dept-accounting-inspect-',
    );
    try {
      return await BackupFiles.decryptAndValidate(
        file.path,
        p.join(directory.path, 'restore.sqlite'),
        key,
      );
    } finally {
      await directory.delete(recursive: true);
    }
  }

  Future<void> restore(List<int> file, String key) =>
      _withBytes(file, (input) => restoreFile(input, key));

  Future<void> restoreFile(File file, String key) async {
    store.require(owner: true);
    await _replace(file, key, existing: true);
  }

  Future<void> shutdown() async {
    _timer?.cancel();
    await _checking;
    await _idle?.future;
    await check(flush: true);
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
