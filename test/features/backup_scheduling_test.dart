import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';
import 'package:dept_accounting/features/backup/data/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('External backups coalesce writes, prune both outputs, and flush on reconnect and shutdown', () async {
    final root = await Directory.systemTemp.createTemp('dept-backup-schedule-');
    final primary = await Directory('${root.path}/primary').create();
    final external = await Directory('${root.path}/external').create();
    final d = AppDependencies(
      LocalDatabase.fromHandle(
        sqlite3.open('${root.path}/shop.sqlite'),
        '${root.path}/shop.sqlite',
      ),
    );
    await d.backups.shutdown();
    var now = DateTime.utc(2026, 10, 16, 12);
    BackupService? backups;
    try {
      d.store.user = const AppUser(
        id: 'owner',
        name: 'مالك',
        username: 'owner',
        role: 'owner',
      );
      d.store.write(() {
        d.store.setSetting(
          'shop',
          const Shop(name: 'اختبار', currency: 'SAR').toJson(),
        );
        d.store.setSetting('backup_key', Passwords.token(32));
        d.store.setSetting('backup_directory', primary.path);
        d.store.setSetting('external_backup_directory', external.path);
      });
      for (final directory in [primary, external]) {
        for (var i = 0; i < 49; i++) {
          await File(
            '${directory.path}/dept_accounting-auto-2020-${i.toString().padLeft(3, '0')}.dept_accounting',
          ).writeAsString('old');
        }
        await File(
          '${directory.path}/dept_accounting-manual-keep.dept_accounting',
        ).writeAsString('manual');
      }
      backups = BackupService(d.store, now: () => now);
      await backups.check(); // Includes the constructor's launch check.
      final first = d.store.setting('external_backup_change');
      for (final directory in [primary, external]) {
        final files = await directory.list().toList();
        expect(files.where((f) => f.path.contains('auto-')), hasLength(48));
        expect(
          await File(
            '${directory.path}/dept_accounting-manual-keep.dept_accounting',
          ).readAsString(),
          'manual',
        );
      }
      void edit(String value) =>
          d.store.write(() => d.store.setSetting('edit', value));
      now = now.add(const Duration(minutes: 1));
      edit('first');
      await backups.check();
      expect(d.store.setting('external_backup_change'), first);
      now = now.add(const Duration(minutes: 2));
      edit('second');
      await backups.check();
      expect(d.store.setting('external_backup_change'), first);
      now = now.add(const Duration(minutes: 3));
      await backups.check();
      expect(
        d.store.setting('external_backup_change'),
        d.store.setting('changed_at'),
      );
      final disconnected = await external.rename('${root.path}/disconnected');
      edit('offline');
      await backups.check();
      expect(
        d.store.setting('external_backup_change'),
        isNot(d.store.setting('changed_at')),
      );
      await disconnected.rename(external.path);
      now = now.add(const Duration(seconds: 1));
      await backups.check();
      expect(
        d.store.setting('external_backup_change'),
        d.store.setting('changed_at'),
      );
      edit('resume');
      now = now.add(const Duration(seconds: 1));
      await Future.wait([backups.check(), backups.check(flush: true)]);
      expect(
        d.store.setting('external_backup_change'),
        d.store.setting('changed_at'),
      );
      edit('shutdown');
      now = now.add(const Duration(seconds: 1));
      await backups.shutdown();
      expect(
        d.store.setting('external_backup_change'),
        d.store.setting('changed_at'),
      );
    } finally {
      await backups?.shutdown();
      d.store.dispose();
      d.store.database.close();
      await root.delete(recursive: true);
    }
  });
}
