import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';
import 'package:dept_accounting/features/settings/presentation/settings_page.dart';
import 'package:dept_accounting/features/startup/data/startup_guide_repository.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.iOS,
    TargetPlatform.macOS,
  ]) {
    testWidgets('External backup visibility on ${platform.name}', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      final mobile = platform != TargetPlatform.macOS;
      final d = AppDependencies(LocalDatabase.memory());
      d.store.setSetting(
        'shop',
        const Shop(name: 'محل', currency: 'SAR').toJson(),
      );
      d.store.user = const AppUser(
        id: 'owner',
        name: 'المالك',
        username: 'owner',
        role: 'owner',
      );
      addTearDown(() {
        d.backups.dispose();
        d.store.dispose();
        d.store.database.close();
      });
      await d.backups.check();
      expect(d.backups.status.value == null, mobile);
      final steps = d.startupGuide.steps();
      expect(steps.any((step) => step.task == StartupTask.backup), !mobile);
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SettingsPage(dependencies: d, initialBackups: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('اختيار مجلد النسخة الخارجية'),
        mobile ? findsNothing : findsOneWidget,
      );
      expect(
        find.textContaining('آخر نسخة خارجية:'),
        mobile ? findsNothing : findsOneWidget,
      );
      expect(
        find.textContaining('مجلد النسخة الخارجية:'),
        mobile ? findsNothing : findsOneWidget,
      );
      expect(find.text('إنشاء نسخة احتياطية الآن'), findsOneWidget);
      expect(find.text('استعادة نسخة احتياطية'), findsOneWidget);
      d.backups.error = 'تعذر حفظ النسخة';
      await d.backups.check();
      expect(d.backups.status.value?.message, 'تعذر حفظ النسخة');
      await tester.pumpWidget(const SizedBox.shrink());
      d.backups.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }

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
