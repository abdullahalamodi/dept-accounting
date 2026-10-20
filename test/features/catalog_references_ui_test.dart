import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/catalog_reference.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'Shared lists support inline creation, product selection and category management',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = AppDependencies(LocalDatabase.memory());
      d.store.setSetting(
        'shop',
        const Shop(name: 'اختبار', currency: 'YER').toJson(),
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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المنتج'),
        'مصباح',
      );
      await tester.tap(find.widgetWithText(TextFormField, 'التصنيف'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة تصنيف'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم التصنيف'),
        'إضاءة',
      );
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'حفظ'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('إضاءة'), findsOneWidget);

      final advanced = find.text('إعدادات الوحدات المتقدمة');
      await tester.ensureVisible(advanced);
      await tester.tap(advanced);
      await tester.pumpAndSettle();
      final additional = find.widgetWithText(
        TextFormField,
        'وحدة إضافية (اختياري)',
      );
      await tester.ensureVisible(additional);
      await tester.tap(additional);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة وحدة'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم الوحدة'),
        'حزمة',
      );
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'حفظ'));
      await tester.pumpAndSettle();
      final factor = find.widgetWithText(TextFormField, 'عدد الوحدات الأساسية');
      await tester.ensureVisible(factor);
      await tester.enterText(factor, '12');
      await tester.pumpAndSettle();
      expect(find.text('1 حزمة = 12 حبة'), findsOneWidget);
      expect(additional, findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(DeptAccountingButton, 'حفظ المنتج'),
      );
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'حفظ المنتج'));
      await tester.pumpAndSettle();
      final product = d.catalog.all().single;
      expect(product.categoryId, isNotEmpty);
      expect(product.alternateUnitId, isNotEmpty);
      expect(product.factor, 12000);

      await tester.tap(find.widgetWithText(TextButton, 'التصنيفات'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'بحث بالاسم'),
        'إضاءة',
      );
      await tester.pumpAndSettle();
      expect(find.text('1'), findsWidgets);
      await tester.tap(find.byTooltip('تعديل'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم التصنيف'),
        'إنارة داخلية خاصة',
      );
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'حفظ'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'بحث بالاسم'),
        'إنارة داخلية خاصة',
      );
      await tester.pumpAndSettle();
      expect(d.catalog.get(product.id).categoryId, product.categoryId);
      expect(d.catalog.get(product.id).category, 'إنارة داخلية خاصة');
      await tester.tap(find.text('إيقاف'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(DataTable),
          matching: find.text('إنارة داخلية خاصة'),
        ),
        findsNothing,
      );
      await tester.tap(
        find.widgetWithText(DeptAccountingFilterChip, 'إظهار الموقوفة'),
      );
      await tester.pumpAndSettle();
      expect(find.text('موقوفة'), findsOneWidget);
      await tester.tap(find.text('تفعيل'));
      await tester.pumpAndSettle();
      expect(
        d.catalogReferences
            .all(CatalogReferenceKind.category)
            .singleWhere((r) => r.id == product.categoryId)
            .active,
        isTrue,
      );

      // The same management routes also fit a phone.
      tester.view.physicalSize = const Size(390, 1100);
      router.go('/catalog/units');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'قائمة مشتركة للوحدات الأساسية والإضافية؛ يُحدد دور الوحدة ومعامل التحويل داخل كل منتج.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      d.store.user = const AppUser(
        id: 'seller',
        name: 'بائع',
        username: 'seller',
        role: 'seller',
      );
      router.go('/catalog/categories');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
