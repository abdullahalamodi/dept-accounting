import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'New items can continue to opening stock and missing buying prices can be corrected',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = AppDependencies(LocalDatabase.memory());
      d.store.setSetting(
        'shop',
        const Shop(name: 'اختبار', currency: 'SAR').toJson(),
      );
      d.store.user = const AppUser(
        id: 'owner',
        name: 'مالك',
        username: 'owner',
        role: 'owner',
      );
      await tester.pumpWidget(DeptAccountingApp(dependencies: d));
      await tester.pumpAndSettle();
      final router = GoRouter.of(
        tester.element(find.byType(DeptAccountingWorkspace)),
      );
      router.go('/catalog/new');
      await tester.pumpAndSettle();
      expect(find.text('لديك كمية موجودة من هذا المنتج؟'), findsOneWidget);
      for (final label in ['تكلفة الوحدة', 'سعر البيع', 'حد تنبيه المخزون']) {
        expect(
          tester
              .widget<TextFormField>(find.widgetWithText(TextFormField, label))
              .controller!
              .text,
          isEmpty,
        );
      }
      final type = find.widgetWithText(DropdownButtonFormField<bool>, 'النوع');
      final category = find.widgetWithText(TextFormField, 'التصنيف');
      expect(tester.getTopLeft(type).dy, tester.getTopLeft(category).dy);
      expect(
        tester.getTopLeft(type).dx,
        greaterThan(tester.getTopLeft(category).dx),
      );
      expect(
        tester
            .getTopLeft(find.widgetWithText(TextFormField, 'تكلفة الوحدة'))
            .dy,
        lessThanOrEqualTo(
          tester.getTopLeft(find.widgetWithText(TextFormField, 'سعر البيع')).dy,
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'منتج جديد',
      );
      await tester.tap(find.text('حفظ وإضافة مخزون افتتاحي'));
      await tester.pumpAndSettle();
      final id = d.catalog.all().single.id;
      expect(
        router.routeInformationProvider.value.uri.path,
        '/catalog/$id/opening',
      );
      expect(find.text('أضف تكلفة الوحدة أولًا'), findsOneWidget);
      expect(
        tester
            .widget<DeptAccountingButton>(
              find.widgetWithText(
                DeptAccountingButton,
                'اعتماد المخزون الافتتاحي',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('تعديل بيانات المنتج'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
        '10.25',
      );
      await tester.tap(find.text('حفظ وإضافة مخزون افتتاحي'));
      await tester.pumpAndSettle();
      expect(find.text('أضف تكلفة الوحدة أولًا'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'الكمية الافتتاحية'),
        '2',
      );
      await tester.pumpAndSettle();
      expect(find.text('20.5'), findsOneWidget);
      await tester.tap(find.text('اعتماد المخزون الافتتاحي'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'اعتماد'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/catalog');
      expect(d.engine.stock(id).quantity, 2000);
      expect(d.engine.stock(id).value, 2050);
      d.store.setSetting('opening_closed', 'true');
      router.go('/catalog/new');
      await tester.pumpAndSettle();
      expect(find.text('حفظ وإضافة مخزون افتتاحي'), findsNothing);
      d.store.user = d.store.user!.copyWith(role: 'seller');
      router.go('/catalog/$id/opening');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Item edits and opening stock return to an updated list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final d = AppDependencies(LocalDatabase.memory());
    d.store.setSetting(
      'shop',
      const Shop(name: 'محل اختبار', currency: 'YER').toJson(),
    );
    d.store.user = const AppUser(
      id: 'owner',
      name: 'مالك',
      username: 'owner',
      role: 'owner',
    );
    d.catalog.save(const Product(id: 'p', name: 'مصباح'));
    await tester.pumpWidget(DeptAccountingApp(dependencies: d));
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byType(DeptAccountingWorkspace)),
    );
    router.go('/catalog/p');
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'اسم المنتج'),
      'مصباح محدث',
    );
    expect(
      find.widgetWithText(TextFormField, 'وحدة إضافية (اختياري)'),
      findsNothing,
    );
    final advanced = find.text('إعدادات الوحدات المتقدمة');
    await tester.ensureVisible(advanced);
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'عدد الوحدات الأساسية'),
      findsNothing,
    );
    await tester.tap(
      find.widgetWithText(TextFormField, 'وحدة إضافية (اختياري)'),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'بحث بالاسم'),
      'كرتون',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'اختيار'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'عدد الوحدات الأساسية'),
      '12',
    );
    await tester.pumpAndSettle();
    expect(find.text('1 كرتون = 12 حبة'), findsOneWidget);
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(DeptAccountingButton, 'حفظ المنتج'),
    );
    await tester.tap(find.widgetWithText(DeptAccountingButton, 'حفظ المنتج'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/catalog');
    expect(find.text('مصباح محدث'), findsOneWidget);
    expect(d.catalog.get('p').alternateUnit, 'كرتون');
    expect(d.catalog.get('p').factor, 12000);

    await tester.tap(find.byTooltip('عرض وتعديل'));
    await tester.pumpAndSettle();
    expect(find.text('1 كرتون = 12 حبة'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'تكلفة الوحدة'),
      '10',
    );
    await tester.ensureVisible(find.text('حفظ وإضافة مخزون افتتاحي'));
    await tester.tap(find.text('حفظ وإضافة مخزون افتتاحي'));
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/catalog/p/opening',
    );
    expect(find.text('تكلفة الوحدة لكل حبة'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'تكلفة الوحدة'), findsNothing);
    expect(find.byType(TextFormField), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'الكمية الافتتاحية'),
      '20',
    );
    await tester.pumpAndSettle();
    expect(find.text('200'), findsOneWidget);
    final opening = find.widgetWithText(
      DeptAccountingButton,
      'اعتماد المخزون الافتتاحي',
    );
    await tester.ensureVisible(opening);
    await tester.tap(opening);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DeptAccountingButton, 'اعتماد'));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/catalog');
    expect(find.text('20 حبة'), findsOneWidget);
    expect(d.engine.stock('p').value, 20000);
    router.go('/catalog/p');
    await tester.pumpAndSettle();
    expect(find.text('حفظ وإضافة مخزون افتتاحي'), findsNothing);
    router.go('/catalog/p/opening');
    await tester.pumpAndSettle();
    expect(find.text('المخزون الافتتاحي غير متاح'), findsOneWidget);
    expect(find.text('اعتماد المخزون الافتتاحي'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Feature routes fit a phone and desktop and draft navigation stays safe',
    (tester) async {
      for (final width in [390.0, 1440.0]) {
        tester.view.physicalSize = Size(width, 1100);
        tester.view.devicePixelRatio = 1;
        final d = AppDependencies(LocalDatabase.memory());
        d.store.setSetting(
          'shop',
          const Shop(name: 'محل اختبار', currency: 'YER').toJson(),
        );
        d.store.user = const AppUser(
          id: 'owner',
          name: 'مالك',
          username: 'owner',
          role: 'owner',
        );
        d.catalog.save(
          const Product(
            id: 'p',
            name: 'مصباح',
            salePrice: 150000,
            purchasePrice: 100000,
            alternateUnit: 'كرتون',
            factor: 12000,
            fractional: true,
          ),
        );
        d.parties.save(
          const Party(id: 'party', name: 'العميل والمورد', supplier: true),
        );
        await tester.pumpWidget(DeptAccountingApp(dependencies: d));
        await tester.pumpAndSettle();
        final router = GoRouter.of(
          tester.element(find.byType(DeptAccountingWorkspace)),
        );
        for (final path in [
          '/catalog',
          '/catalog/p',
          '/catalog/p/opening',
          '/inventory/p',
          '/parties',
          '/parties/party',
          '/sales',
          '/sales/new/sale',
          '/purchases/new/purchase',
          '/receiving',
          '/receiving/new/receive',
          '/finance',
          '/finance/new',
          '/reports',
          '/settings',
          '/profile',
        ]) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$path at $width');
        }
        router.go('/settings');
        await tester.pumpAndSettle();
        for (final section in [
          'النسخ الاحتياطية',
          'المستخدمون',
          'سجل العمليات',
          'المحل',
        ]) {
          final tab = find.widgetWithText(DeptAccountingFilterChip, section);
          await tester.ensureVisible(tab);
          await tester.tap(tab);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: 'settings $section at $width',
          );
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
