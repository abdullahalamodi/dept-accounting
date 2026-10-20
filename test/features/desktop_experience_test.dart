import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/features/reports/presentation/period_reports.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/load_app_fonts.dart';

const _captures = String.fromEnvironment('DESKTOP_CAPTURE_DIR');
const _boundary = ValueKey('desktop-capture');

AppDependencies _shop() {
  final d = AppDependencies(LocalDatabase.memory());
  d.store.user = const AppUser(
    id: 'owner',
    name: 'عبدالله محمد',
    username: 'owner',
    role: 'owner',
  );
  d.store.database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
    'owner',
    'owner',
    d.store.user!.toJson(),
    'test-only',
  ]);
  d.store.setSetting(
    'shop',
    const Shop(name: 'متجر النخبة', currency: 'SAR').toJson(),
  );
  d.catalog.save(
    const Product(
      id: 'p',
      name: 'مصباح موفر للطاقة بضمان لمدة سنتين للاستخدام المنزلي والتجاري',
      barcode: '1234567890123',
      purchasePrice: 1000,
      salePrice: 2000,
      fractional: true,
    ),
  );
  d.catalog.opening('p', 20000);
  d.parties.save(
    const Party(
      id: 'party',
      name: 'مؤسسة نواة للتجارة والتوريد',
      customer: true,
      supplier: true,
    ),
  );
  d.invoices.post(
    requestId: 'sale',
    sale: true,
    partyId: 'party',
    lines: const [
      InvoiceLine(
        productId: 'p',
        name: 'مصباح موفر للطاقة',
        unit: 'حبة',
        quantity: 2000,
        price: 2000,
      ),
    ],
    payments: const [Payment(account: '1100', amount: 1000)],
  );
  d.invoices.saveDraft('desktop-draft', 'sale', {
    'lines': [
      {'productId': 'p', 'unit': 'حبة', 'quantity': '2', 'price': '20'},
    ],
    'payments': [
      {'account': '1100', 'amount': '10'},
    ],
    'paymentMode': 'partial',
    'partyId': 'party',
    'discount': '0',
    'shipping': '0',
    'notes': '',
    'date': DateTime.now().toIso8601String(),
  });
  return d;
}

Future<GoRouter> _mount(WidgetTester tester, AppDependencies d) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 900);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _boundary,
      child: DeptAccountingApp(dependencies: d),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(DeptAccountingWorkspace)));
}

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captures.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_boundary),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(_captures).create(recursive: true);
    await File('$_captures/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'Desktop routes reflow without overflow and keep final actions reachable',
    (tester) async {
      final d = _shop();
      final router = await _mount(tester, d);
      final routes = <String, String>{
        'overview': '/',
        'catalog': '/catalog',
        'product': '/catalog/p',
        'new-product': '/catalog/new',
        'categories': '/catalog/categories',
        'units': '/catalog/units',
        'sales': '/sales',
        'purchases': '/purchases',
        'invoice': '/sales/new/desktop-draft',
        'purchase-editor': '/purchases/new/desktop-purchase',
        'receiving': '/receiving',
        'receiving-editor': '/receiving/new/desktop-receipt',
        'finance': '/finance',
        'finance-editor': '/finance/new',
        'reports': '/reports',
        'parties': '/parties',
        'party': '/parties/party',
        'new-party': '/parties/new',
        'inventory': '/inventory',
        'stock': '/inventory/p',
        'opening': '/catalog/p/opening',
        'returns': '/returns/sale',
        'document': '/sales/view/sale',
        'settings': '/settings',
        'backups': '/settings?section=backups',
        'profile': '/profile',
      };
      for (final size in const [
        Size(600, 800),
        Size(900, 800),
        Size(1100, 800),
        Size(1280, 720),
        Size(1440, 900),
        Size(1920, 1080),
      ]) {
        tester.view.physicalSize = size;
        for (final entry in routes.entries) {
          router.go(entry.value);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${entry.key} at $size',
          );
          if (size.width == 1440 ||
              (size.width == 600 && entry.key == 'invoice')) {
            await _capture(tester, '${entry.key}-${size.width.toInt()}');
          }
          if (entry.key == 'invoice') {
            expect(
              find.text('اعتماد فاتورة بيع').hitTestable(),
              findsOneWidget,
            );
            expect(find.text('حفظ مسودة').hitTestable(), findsOneWidget);
          }
        }
      }
      await _leave(tester);
    },
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets(
    'Desktop sections preserve selections and separate setup from daily work',
    (tester) async {
      final d = _shop();
      final router = await _mount(tester, d);
      router.go('/finance');
      await tester.pumpAndSettle();
      expect(find.text('الحركات المالية'), findsOneWidget);
      expect(find.text('إعداد الحسابات وأرصدة البداية'), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'أرصدة البداية'));
      await tester.pumpAndSettle();
      expect(find.text('إعداد الحسابات وأرصدة البداية'), findsOneWidget);
      await _capture(tester, 'finance-opening-1440');

      router.go('/reports');
      await tester.pumpAndSettle();
      final periodElement = tester.element(find.byType(PeriodReports));
      await tester.tap(find.widgetWithText(TextButton, 'ميزان المراجعة'));
      await tester.pumpAndSettle();
      expect(find.text('ميزان المراجعة متوازن'), findsOneWidget);
      await _capture(tester, 'reports-trial-1440');
      await tester.tap(find.widgetWithText(TextButton, 'تقارير الفترة'));
      await tester.pumpAndSettle();
      expect(tester.element(find.byType(PeriodReports)), same(periodElement));

      router.go('/sales');
      await tester.pumpAndSettle();
      expect(find.text('استكمال'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'بحث برقم الفاتورة أو الملاحظات'),
        'SAL-',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'المسودات'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(OutlinedButton, 'استكمال'), findsOneWidget);
      await _capture(tester, 'sales-drafts-1440');
      await tester.tap(find.widgetWithText(TextButton, 'الفواتير'));
      await tester.pumpAndSettle();
      final searchField = find.widgetWithText(
        TextFormField,
        'بحث برقم الفاتورة أو الملاحظات',
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(
                of: searchField,
                matching: find.byType(EditableText),
              ),
            )
            .controller
            .text,
        'SAL-',
      );
      expect(find.text('SAL-000001'), findsOneWidget);

      router.go('/parties/party');
      await tester.pumpAndSettle();
      expect(find.text('كشف الحساب'), findsWidgets);
      expect(find.widgetWithText(TextFormField, 'اسم الطرف'), findsNothing);
      await tester.tap(find.text('تعديل البيانات'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'اسم الطرف'), findsOneWidget);
      await _capture(tester, 'party-edit-1440');
      expect(tester.takeException(), isNull);
      await _leave(tester);
    },
  );

  testWidgets(
    'Desktop invoice survives resizing, enlarged text and a product picker',
    (tester) async {
      final d = _shop();
      final router = await _mount(tester, d);
      router.go('/sales/new/desktop-draft');
      await tester.pumpAndSettle();
      final quantity = find.widgetWithText(TextFormField, '');
      // Barcode entry updates the shared draft, then desktop reflow retains it.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'إضافة بالباركود — امسح ثم Enter'),
        '1234567890123',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(quantity, findsWidgets);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final size in const [
        Size(900, 720),
        Size(600, 800),
        Size(1440, 900),
      ]) {
        tester.view.physicalSize = size;
        await tester.pumpAndSettle();
        expect(find.text('اعتماد فاتورة بيع').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await _capture(tester, 'invoice-enlarged-1440');
      await tester.ensureVisible(find.text('إضافة منتج'));
      await tester.tap(find.text('إضافة منتج'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await _capture(tester, 'product-picker-1440');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ مسودة'));
      await tester.pumpAndSettle();
      expect(
        (d.invoices.loadDraft('desktop-draft')!['lines'] as List)
            .first['quantity'],
        '3',
      );
      await _leave(tester);
    },
  );
}
