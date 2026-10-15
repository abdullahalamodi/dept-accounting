import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Backup notices distinguish setup, first copy and an overdue copy',
    () async {
      final d = AppDependencies(LocalDatabase.memory());
      final directory = await Directory.systemTemp.createTemp(
        'dept_accounting-notice-',
      );
      try {
        await d.store.setup(
          shop: const Shop(name: 'محل جديد', currency: 'SAR'),
          ownerName: 'المالك',
          username: 'owner',
          password: 'safe-password',
          recovery: 'recovery-code',
          backupKey: Passwords.token(32),
        );
        d.store.setSetting('backup_directory', directory.path);
        await d.backups.backup();
        expect(
          d.backups.status.value?.title,
          'لم تُعدّ النسخ الاحتياطي الخارجي بعد',
        );
        expect(d.backups.status.value?.warning, isFalse);
        expect(d.store.setting('backup_at'), isNotNull);
        expect(d.store.setting('external_backup_at'), isNull);

        d.store.setSetting(
          'external_backup_directory',
          '${directory.path}/missing',
        );
        await d.backups.check();
        expect(d.backups.status.value?.title, 'لم تُحفظ أول نسخة خارجية بعد');
        expect(d.backups.status.value?.warning, isFalse);

        d.store.setSetting('external_backup_directory', directory.path);
        await d.backups.backup();
        expect(d.store.setting('external_backup_at'), isNotNull);
        expect(d.backups.status.value, isNull);

        for (final age in [
          const Duration(hours: 23, minutes: 59),
          const Duration(hours: 24),
        ]) {
          d.store.setSetting(
            'external_backup_at',
            DateTime.now().toUtc().subtract(age).toIso8601String(),
          );
          await d.backups.check();
          if (age.inHours < 24) {
            expect(d.backups.status.value, isNull);
          } else {
            expect(d.backups.status.value?.title, 'النسخة الخارجية متأخرة');
            expect(d.backups.status.value?.warning, isTrue);
          }
        }

        await d.backups.backup();
        expect(d.backups.status.value, isNull);
      } finally {
        await d.backups.shutdown();
        d.store.dispose();
        d.store.database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}
