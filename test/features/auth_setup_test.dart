import 'dart:convert';
import 'dart:typed_data';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/presentation/auth_page.dart';
import 'package:dept_accounting/features/auth/presentation/auth_view_model.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _SavePicker extends FilePickerPlatform {
  Uri? result;
  bool fail = false;
  String? contents;
  String? filename;

  @override
  Future<Uri?> saveFile({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
    String? initialDirectory,
    void Function(FilePickerStatus)? onFileSaving,
    WindowsOptions windowsOptions = const WindowsOptions(),
    LinuxOptions linuxOptions = const LinuxOptions(),
    WebOptions webOptions = const WebOptions(),
  }) async {
    if (fail) throw StateError('Save failed');
    filename = fileName;
    contents = utf8.decode(bytes);
    return result;
  }
}

void main() {
  late AppDependencies dependencies;
  late _SavePicker picker;
  late FilePickerPlatform originalPicker;
  setUp(() {
    dependencies = AppDependencies(LocalDatabase.memory());
    originalPicker = FilePickerPlatform.instance;
    FilePickerPlatform.instance = picker = _SavePicker();
  });
  tearDown(() {
    FilePickerPlatform.instance = originalPicker;
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

  test('Only saved and acknowledged exports unlock setup; exported keys recover the account and encrypted data', () async {
    final vm = AuthViewModel(dependencies.store);
    addTearDown(vm.dispose);
    const shop = Shop(name: 'محل تجريبي', currency: 'YER');
    vm.confirmRecoveryStorage(true);
    expect(vm.canSetup, isFalse);
    expect(await vm.setup(shop, 'المالك', 'owner', 'safe-password'), isFalse);
    expect(dependencies.store.shop, isNull);

    await vm.downloadRecoveryKeys();
    expect(vm.recoveryFileDownloaded, isFalse);
    picker.fail = true;
    await vm.downloadRecoveryKeys();
    expect(vm.recoveryDownloadError, isNotNull);
    expect(vm.canSetup, isFalse);

    picker.fail = false;
    picker.result = Uri.file('/tmp/dept_accounting-recovery-keys.txt');
    await vm.downloadRecoveryKeys();
    expect(vm.recoveryDownloadError, isNull);
    expect(vm.recoveryFileDownloaded, isTrue);
    expect(vm.canSetup, isFalse);
    expect(picker.filename, 'دبت للحسابات-مفاتيح الاسترداد.txt');
    final lines = const LineSplitter().convert(picker.contents!);
    final recovery = lines[lines.indexOf('رمز استرداد دخول المالك') + 1];
    final backup = lines[lines.indexOf('مفتاح استعادة النسخ الاحتياطية') + 1];
    expect(recovery, vm.recovery);
    expect(backup, vm.backupKey);
    await vm.downloadRecoveryKeys();
    expect(picker.contents, contains('\n$recovery\n'));
    expect(picker.contents, contains('\n$backup\n'));
    expect(picker.contents, isNot(contains('safe-password')));

    vm.confirmRecoveryStorage(true);
    expect(await vm.setup(shop, 'المالك', 'owner', 'safe-password'), isTrue);
    await dependencies.store.recoverOwner(recovery, 'replacement-password');
    await dependencies.store.login('owner', 'replacement-password');
    expect(dependencies.store.user!.username, 'owner');
    final encrypted = await dependencies.backups.encrypt([1, 2, 3], backup);
    expect(await dependencies.backups.decrypt(encrypted, backup), [1, 2, 3]);
  });

  testWidgets(
    'Registration handles save cancellation, errors, acknowledgement, and field validation',
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
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(tester.widget<DeptAccountingButton>(create).onPressed, isNull);
      picker.fail = true;
      await tester.tap(download);
      await tester.pumpAndSettle();
      expect(find.text('لم يُحفظ الملف'), findsOneWidget);
      picker.fail = false;
      picker.result = Uri.file('/tmp/dept_accounting-recovery-keys.txt');
      await tester.tap(download);
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
