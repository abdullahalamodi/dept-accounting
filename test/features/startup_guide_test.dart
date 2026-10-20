import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/backup/data/backup_service.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/features/startup/data/startup_guide_repository.dart';
import 'package:dept_accounting/features/startup/presentation/startup_guide.dart';
import 'package:dept_accounting/features/startup/presentation/startup_guide_view_model.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/load_app_fonts.dart';

AppDependencies newShop() {
  final d = AppDependencies(LocalDatabase.memory());
  d.store.setSetting(
    'shop',
    const Shop(name: 'محل البداية', currency: 'SAR').toJson(),
  );
  d.store.user = const AppUser(
    id: 'owner',
    name: 'أحمد',
    username: 'owner',
    role: 'owner',
  );
  return d;
}

Future<void> openDesktopGuide(WidgetTester tester) async {
  final tile = find.byKey(const PageStorageKey('desktop-startup-guide'));
  if (tile.evaluate().isEmpty) return;
  await tester.ensureVisible(tile);
  if (find
          .text('الخطوة التالية: راجع الصندوق وأرصدة البداية')
          .evaluate()
          .isEmpty &&
      find.text('كل خطوات البداية بالترتيب').evaluate().isEmpty) {
    await tester.tap(find.textContaining('تجهيز المحل ·'));
    await tester.pumpAndSettle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadAppFonts);
  test(
    'Guide tracks actual setup, persists skipped steps and respects roles',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final d = newShop();
      final vm = StartupGuideViewModel(
        d.startupGuide,
        backupStatus: d.backups.status,
      );
      addTearDown(() {
        vm.dispose();
        d.backups.dispose();
        d.store.dispose();
        d.store.database.close();
      });
      await vm.refresh();
      expect(vm.query.error, isNull);
      expect(vm.query.value, isNotNull);
      expect(vm.visible, isTrue);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.cash);
      // Seeded lists and the default cash account do not mean the shop reviewed them.
      await vm.refresh();
      expect(vm.resolvedCount, 0);
      await vm.review(StartupTask.cash, skip: true);
      await vm.refresh();
      expect(vm.visible, isTrue);
      await vm.refresh();
      expect(vm.steps.first.skipped, isTrue);
      await vm.revisit(StartupTask.cash);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.cash);
      await vm.review(StartupTask.cash);
      await vm.review(StartupTask.categories);
      await vm.review(StartupTask.units);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.products);
      d.catalog.save(
        const Product(id: 'a', name: 'أول منتج', purchasePrice: 100),
      );
      d.catalog.save(
        const Product(id: 'b', name: 'ثاني منتج', purchasePrice: 100),
      );
      await vm.refresh();
      expect(vm.next!.task, StartupTask.stock);
      d.catalog.opening('a', 1000);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.stock);
      await vm.refresh();
      expect(vm.next!.path, '/catalog/b/opening');
      d.catalog.opening('b', 1000);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.suppliers);
      d.parties.save(
        const Party(
          id: 'supplier',
          name: 'مورد',
          customer: false,
          supplier: true,
        ),
      );
      await vm.refresh();
      expect(vm.next!.task, StartupTask.customers);
      await vm.review(StartupTask.customers, skip: true);
      await vm.refresh();
      expect(vm.next!.task, StartupTask.backup);
      // A local backup alone does not complete protection against device loss.
      d.store.setSetting('backup_at', '2026-10-16T10:00:00Z');
      d.backups.status.value = const BackupNotice(
        title: 'نسخة محلية',
        message: '',
      );
      await vm.refresh();
      expect(vm.next!.task, StartupTask.backup);
      d.store.setSetting('external_backup_directory', '/usb');
      d.store.setSetting('external_backup_at', '2026-10-16T10:00:00Z');
      d.backups.status.value = const BackupNotice(
        title: 'نسخة خارجية',
        message: '',
      );
      await vm.refresh();
      expect(vm.next, isNull);
      await vm.refresh();
      expect(vm.visible, isTrue);
      final reopened = StartupGuideRepository(d.store);
      expect(
        reopened
            .steps()
            .singleWhere((s) => s.task == StartupTask.customers)
            .skipped,
        isTrue,
      );
      d.store.user = d.store.user!.copyWith(role: 'accountant');
      await vm.refresh();
      await vm.refresh();
      expect(vm.steps.any((s) => s.task == StartupTask.backup), isFalse);
      d.store.user = d.store.user!.copyWith(role: 'seller');
      await vm.refresh();
      await vm.refresh();
      expect(vm.available, isFalse);
      expect(() => reopened.review(StartupTask.cash), throwsException);
    },
  );

  testWidgets(
    'Guide opens setup screens, permits revisiting and hides after completion',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = newShop();
      await tester.pumpWidget(DeptAccountingApp(dependencies: d));
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byType(DeptAccountingWorkspace)),
      );
      await openDesktopGuide(tester);
      expect(
        find.text('الخطوة التالية: راجع الصندوق وأرصدة البداية'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(StartupGuide),
          matching: find.byIcon(Icons.close),
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.text('إعداد الحسابات'));
      await tester.tap(find.text('إعداد الحسابات'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/finance');
      router.go('/');
      await tester.pumpAndSettle();
      await openDesktopGuide(tester);
      await tester.ensureVisible(find.text('تخطي الآن'));
      await tester.tap(find.text('تخطي الآن'));
      await tester.pumpAndSettle();
      expect(find.text('الخطوة التالية: جهّز التصنيفات'), findsOneWidget);
      await tester.ensureVisible(find.text('مراجعة التصنيفات'));
      await tester.tap(find.text('مراجعة التصنيفات'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        '/catalog/categories',
      );
      router.go('/');
      await tester.pumpAndSettle();
      await openDesktopGuide(tester);
      await tester.ensureVisible(find.text('التصنيفات مناسبة لنشاطي'));
      await tester.tap(find.text('التصنيفات مناسبة لنشاطي'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('الوحدات مناسبة لنشاطي'));
      await tester.tap(find.text('الوحدات مناسبة لنشاطي'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('إضافة منتج أو خدمة'));
      await tester.tap(find.text('إضافة منتج أو خدمة'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/catalog/new');
      d.startupGuide.review(StartupTask.products, skip: true);
      d.startupGuide.review(StartupTask.stock, skip: true);
      router.go('/');
      await tester.pumpAndSettle();
      await openDesktopGuide(tester);
      await tester.ensureVisible(find.text('إضافة مورد'));
      await tester.tap(find.text('إضافة مورد'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DeptAccountingFilterChip>(
              find.widgetWithText(DeptAccountingFilterChip, 'مورد'),
            )
            .selected,
        isTrue,
      );
      expect(
        tester
            .widget<DeptAccountingFilterChip>(
              find.widgetWithText(DeptAccountingFilterChip, 'عميل'),
            )
            .selected,
        isFalse,
      );
      d.startupGuide.review(StartupTask.suppliers, skip: true);
      d.startupGuide.review(StartupTask.customers, skip: true);
      router.go('/');
      await tester.pumpAndSettle();
      await openDesktopGuide(tester);
      await tester.ensureVisible(find.text('إعداد النسخ الاحتياطية'));
      await tester.tap(find.text('إعداد النسخ الاحتياطية'));
      await tester.pumpAndSettle();
      expect(find.text('النسخ الاحتياطية والاستعادة'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();
      await openDesktopGuide(tester);
      await tester.ensureVisible(find.text('كل خطوات البداية بالترتيب'));
      await tester.tap(find.text('كل خطوات البداية بالترتيب'));
      await tester.pumpAndSettle();
      final cash = find
          .descendant(
            of: find.byType(StartupGuide),
            matching: find.text('إعادة الخطوة'),
          )
          .first;
      await tester.ensureVisible(cash);
      await tester.tap(cash);
      await tester.pumpAndSettle();
      expect(
        find.text('الخطوة التالية: راجع الصندوق وأرصدة البداية'),
        findsOneWidget,
      );
      d.startupGuide.review(StartupTask.cash);
      await tester.pumpAndSettle();
      expect(find.text('الخطوة التالية: احمِ بيانات محلك'), findsOneWidget);
      d.startupGuide.review(StartupTask.backup, skip: true);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(StartupGuide),
          matching: find.byType(DeptAccountingPanel),
        ),
        findsNothing,
      );
      expect(find.text('دليل تجهيز المحل'), findsNothing);
      router.go('/finance');
      await tester.pumpAndSettle();
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('اكتملت مراجعة خطوات البداية'), findsNothing);
      expect(find.text('دليل تجهيز المحل'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('Guide fits desktop, phone and large text', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const capture = String.fromEnvironment('DEPT_ACCOUNTING_CAPTURE_DIR');
    for (final (width, scale) in [(1440.0, 1.0), (390.0, 1.0), (390.0, 2.0)]) {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      final d = newShop();
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 1400),
              textScaler: TextScaler.linear(scale),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SingleChildScrollView(
                  child: RepaintBoundary(
                    key: key,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: StartupGuide(dependencies: d),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width >= DeptAccountingLayout.compact) await openDesktopGuide(tester);
      await tester.tap(find.text('كل خطوات البداية بالترتيب'));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: '$width at text scale $scale',
      );
      if (capture.isNotEmpty) {
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory(capture).create(recursive: true);
          await File('$capture/startup-${width.toInt()}-$scale.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox.shrink());
      d.backups.dispose();
      d.store.dispose();
      d.store.database.close();
    }
  });
}
