import 'dart:convert';
import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/presentation/auth_page.dart';
import 'package:dept_accounting/features/auth/presentation/auth_view_model.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDependencies dependencies;
  late Directory downloads;
  bool failDownload = false;
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  setUp(() async {
    dependencies = AppDependencies(LocalDatabase.memory());
    downloads = await Directory.systemTemp.createTemp('recovery-downloads-');
    failDownload = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, (call) async {
          if (call.method == 'getDownloadsDirectory') {
            if (failDownload) throw PlatformException(code: 'unavailable');
            return downloads.path;
          }
          return null;
        });
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathChannel, null);
    await downloads.delete(recursive: true);
    dependencies.backups.dispose();
    dependencies.store.dispose();
    dependencies.store.database.close();
  });

  Widget host() => MaterialApp(
    theme: DeptAccountingTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: AuthPage(dependencies: dependencies, setup: true),
  );

  testWidgets('login remember checkbox toggles and is hidden during recovery', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DeptAccountingTheme.light(),
        home: AuthPage(dependencies: dependencies, setup: false),
      ),
    );
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      false,
    );
    await tester.tap(find.text('إبقائي مسجل الدخول'));
    await tester.pump();
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      true,
    );
    await tester.tap(find.text('نسيت كلمة مرور المالك؟'));
    await tester.pump();
    expect(find.text('إبقائي مسجل الدخول'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test(
    'Account writes reject non-English usernames at every entry point',
    () async {
      final store = dependencies.store;
      const shop = Shop(name: 'محل', currency: 'YER');
      await expectLater(
        store.setup(
          shop: shop,
          ownerName: 'المالك',
          username: 'مالك',
          password: 'safe-password',
          recovery: 'recovery',
          backupKey: 'backup',
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(store.shop, isNull);
      await store.setup(
        shop: shop,
        ownerName: 'المالك',
        username: 'Owner_1.a-b',
        password: 'safe-password',
        recovery: 'recovery',
        backupKey: 'backup',
      );
      expect(
        () => store.updateProfile(name: 'المالك', username: 'ownerع'),
        throwsA(isA<BusinessException>()),
      );
      await expectLater(
        store.saveUser(
          const AppUser(
            id: 'seller',
            name: 'البائع',
            username: 'بائع',
            role: 'seller',
          ),
          'safe-password',
        ),
        throwsA(isA<BusinessException>()),
      );
      expect(store.users(), hasLength(1));
      expect(store.user!.username, 'Owner_1.a-b');
    },
  );

  test('Only saved and acknowledged exports unlock setup; exported keys recover the account and encrypted data', () async {
    final vm = AuthViewModel(dependencies.store);
    addTearDown(vm.dispose);
    const shop = Shop(name: 'محل تجريبي', currency: 'YER');
    vm.confirmRecoveryStorage(true);
    expect(vm.canSetup, isFalse);
    expect(await vm.setup(shop, 'المالك', 'owner', 'safe-password'), isFalse);
    expect(dependencies.store.shop, isNull);

    failDownload = true;
    await vm.downloadRecoveryKeys();
    expect(vm.recoveryDownloadError, isNotNull);
    expect(vm.canSetup, isFalse);

    failDownload = false;
    await vm.downloadRecoveryKeys();
    expect(vm.recoveryDownloadError, isNull);
    expect(vm.recoveryFileDownloaded, isTrue);
    expect(vm.canSetup, isFalse);
    final firstFile = File(vm.recoveryFileLocation!);
    expect(p.dirname(firstFile.path), downloads.path);
    expect(p.basename(firstFile.path), 'دبت للحسابات-مفاتيح الاسترداد.txt');
    final contents = await firstFile.readAsString();
    final lines = const LineSplitter().convert(contents);
    final recovery = lines[lines.indexOf('رمز استرداد دخول المالك') + 1];
    final backup = lines[lines.indexOf('مفتاح استعادة النسخ الاحتياطية') + 1];
    expect(recovery, vm.recovery);
    expect(backup, vm.backupKey);
    await vm.downloadRecoveryKeys();
    final copy = File(vm.recoveryFileLocation!);
    expect(copy.path, isNot(firstFile.path));
    final copiedContents = await copy.readAsString();
    expect(copiedContents, contents);
    expect(copiedContents, contains('\n$recovery\n'));
    expect(copiedContents, contains('\n$backup\n'));
    expect(copiedContents, isNot(contains('safe-password')));
    expect(await firstFile.readAsString(), contents);

    vm.confirmRecoveryStorage(true);
    expect(await vm.setup(shop, 'المالك', 'owner', 'safe-password'), isTrue);
    await dependencies.store.recoverOwner(recovery, 'replacement-password');
    await dependencies.store.login('owner', 'replacement-password');
    expect(dependencies.store.user!.username, 'owner');
    final encrypted = await dependencies.backups.encrypt([1, 2, 3], backup);
    expect(await dependencies.backups.decrypt(encrypted, backup), [1, 2, 3]);
  });

  testWidgets(
    'Registration handles download errors, acknowledgement, and field validation',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host());
      final create = find.widgetWithText(
        DeptAccountingButton,
        'إنشاء المحل وبدء العمل',
      );
      final download = find.widgetWithText(
        DeptAccountingButton,
        'تنزيل ملف مفاتيح الاسترداد',
      );
      expect(find.text('١. معلومات المستخدم'), findsOneWidget);
      expect(find.text('٢. بيانات الدخول'), findsOneWidget);
      expect(find.text('٣. مفاتيح الاسترداد'), findsOneWidget);
      expect(tester.widget<DeptAccountingButton>(create).onPressed, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile))
            .onChanged,
        isNull,
      );
      expect(find.byType(SelectableText), findsNothing);
      await tester.ensureVisible(download);
      failDownload = true;
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(find.text('لم يُحفظ الملف'), findsOneWidget);
      failDownload = false;
      await tester.runAsync(() async {
        await tester.tap(download);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await tester.pumpAndSettle();
      expect(find.text('لم يُحفظ الملف'), findsNothing);
      expect(find.text('تم حفظ ملف المفاتيح'), findsOneWidget);
      expect(tester.widget<DeptAccountingButton>(create).onPressed, isNull);
      await tester.ensureVisible(find.byType(CheckboxListTile));
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      expect(tester.widget<DeptAccountingButton>(create).onPressed, isNotNull);
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();
      expect(find.text('أدخل اسم المالك.'), findsOneWidget);
      expect(find.text('أدخل اسم المستخدم.'), findsOneWidget);
      expect(dependencies.store.shop, isNull);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المستخدم'),
        'مالك',
      );
      await tester.pump();
      expect(
        find.text('استخدم أحرفًا إنجليزية وأرقامًا والرموز . أو _ أو - فقط.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المستخدم'),
        'owner_1',
      );
      await tester.pumpAndSettle();
      expect(
        find.text('استخدم أحرفًا إنجليزية وأرقامًا والرموز . أو _ أو - فقط.'),
        findsNothing,
      );
      final passwordField = find.widgetWithText(TextFormField, 'كلمة المرور');
      await tester.enterText(passwordField, 'safe-password');
      final confirmation = find.widgetWithText(
        TextFormField,
        'تأكيد كلمة المرور',
      );
      await tester.enterText(confirmation, 'different-password');
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين.'), findsOneWidget);
      await tester.enterText(confirmation, 'safe-password');
      await tester.pump();
      expect(find.text('كلمتا المرور غير متطابقتين.'), findsNothing);
      await tester.ensureVisible(find.byTooltip('إظهار كلمة المرور'));
      await tester.tap(find.byTooltip('إظهار كلمة المرور'));
      await tester.pump();
      expect(find.byTooltip('إخفاء كلمة المرور'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Registration and restore remain usable on narrow screens with larger text',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final restore = find.text('لديك نسخة احتياطية من محل سابق؟');
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('اختيار نسخة احتياطية واستعادتها'));
      expect(find.text('مفتاح استعادة النسخة'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
