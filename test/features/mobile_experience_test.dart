import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_items_table.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_summary_panel.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/load_app_fonts.dart';

const captureRoot = String.fromEnvironment('MOBILE_CAPTURE_DIR');
const boundaryKey = ValueKey('mobile-capture');

AppDependencies seededShop() {
  final d = AppDependencies(LocalDatabase.memory());
  d.store.user = const AppUser(
    id: 'owner',
    name: 'عبدالله محمد',
    username: 'abdullah',
    role: 'owner',
  );
  d.store.database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
    'owner',
    'abdullah',
    d.store.user!.toJson(),
    'test-only',
  ]);
  d.store.setSetting(
    'shop',
    const Shop(name: 'محل النخبة', currency: 'SAR').toJson(),
  );
  d.catalog.save(
    const Product(
      id: 'p',
      name: 'مصباح موفر للطاقة',
      barcode: '123',
      purchasePrice: 1000,
      salePrice: 2000,
      fractional: true,
    ),
  );
  d.catalog.opening('p', 20000);
  d.parties.save(
    const Party(
      id: 'party',
      name: 'مؤسسة نواة',
      phone: '0551234567',
      supplier: true,
    ),
  );
  return d;
}

Future<GoRouter> mount(
  WidgetTester tester,
  AppDependencies d,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetViewInsets);
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundaryKey,
      child: DeptAccountingApp(dependencies: d),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(DeptAccountingWorkspace)));
}

Future<void> capture(WidgetTester tester, String name) async {
  if (captureRoot.isEmpty) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(captureRoot).create(recursive: true);
    await File('$captureRoot/$name.png')
        .writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'Mobile sale edits, survives resizing and draft restore, and posts once',
    (tester) async {
      final d = seededShop();
      final router = await mount(tester, d, const Size(390, 844));
      router.go('/sales/new/mobile-sale');
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.text('إضافة منتج'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('مصباح موفر للطاقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصباح موفر للطاقة'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'الكمية'),
        '2.5',
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 290);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('حفظ البند'));
      await tester.tap(find.text('حفظ البند'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await capture(tester, 'invoice-items');
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(1440, 1000);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InvoiceItemsTable>(find.byType(InvoiceItemsTable))
            .vm
            .lines
            .single
            .quantity,
        '2.5',
      );
      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      await tester.tap(find.text('حفظ مسودة'));
      await tester.pumpAndSettle();
      expect(
        d.invoices.loadDraft('mobile-sale')!['lines'][0]['quantity'],
        '2.5',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/sales');
      await tester.ensureVisible(find.text('استكمال'));
      await tester.tap(find.text('استكمال'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة إلى الدفع'));
      await tester.pumpAndSettle();
      final summary = tester.widget<InvoiceSummaryPanel>(
        find.byType(InvoiceSummaryPanel),
      );
      expect(summary.vm.total, 5000);
      await tester.tap(find.widgetWithText(TextFormField, 'العميل'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مؤسسة نواة'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('دفع جزئي'));
      await tester.tap(find.text('دفع جزئي'));
      await tester.pumpAndSettle();
      final paidField = find.widgetWithText(TextFormField, 'المدفوع (ر.س)');
      await tester.ensureVisible(paidField);
      await tester.enterText(paidField, '20');
      await tester.pumpAndSettle();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await capture(tester, 'invoice-payment');
      expect(summary.vm.paid, 2000);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('اعتماد الفاتورة'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'اعتماد'));
      await tester.pumpAndSettle();
      expect(
        router.routeInformationProvider.value.uri.path,
        startsWith('/documents/'),
      );
      expect(d.engine.stock('p').quantity, 17500);
      expect(d.parties.balance('party', true), 3000);
      expect(d.invoices.loadDraft('mobile-sale'), isNull);
      await capture(tester, 'document');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Mobile purchases and receipt finalization keep supplier and stock rules',
    (tester) async {
      final d = seededShop();
      final router = await mount(tester, d, const Size(390, 844));

      Future<void> pickSupplier() async {
        final field = find.widgetWithText(TextFormField, 'المورد');
        await tester.ensureVisible(field);
        await tester.tap(field);
        await tester.pumpAndSettle();
        await tester.tap(find.text('مؤسسة نواة'));
        await tester.pumpAndSettle();
      }

      Future<void> approve() async {
        await tester.tap(find.text('اعتماد الفاتورة'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(DeptAccountingButton, 'اعتماد'));
        await tester.pumpAndSettle();
        expect(
          router.routeInformationProvider.value.uri.path,
          startsWith('/documents/'),
        );
      }

      router.go('/purchases/new/mobile-buy');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة منتج'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصباح موفر للطاقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة إلى الدفع'));
      await tester.pumpAndSettle();
      await pickSupplier();
      await tester.ensureVisible(find.text('آجل'));
      await tester.tap(find.text('آجل'));
      await tester.pumpAndSettle();
      await approve();
      expect(d.engine.stock('p').quantity, 21000);
      expect(d.parties.balance('party', false), 1000);

      router.go('/receiving/new/mobile-receive');
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة منتج'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصباح موفر للطاقة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('مراجعة الاستلام'));
      await tester.pumpAndSettle();
      await pickSupplier();
      await tester.tap(find.text('اعتماد الاستلام'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DeptAccountingButton, 'اعتماد'));
      await tester.pumpAndSettle();
      final receiptId =
          router.routeInformationProvider.value.uri.pathSegments.last;
      expect(d.invoices.get(receiptId).kind, 'quick_receipt');
      expect(d.engine.stock('p').quantity, 22000);

      router.go('/receiving/finalize/$receiptId/mobile-finalize');
      await tester.pumpAndSettle();
      await tester.tap(find.text('مصباح موفر للطاقة'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'الكمية'))
            .enabled,
        isFalse,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'سعر الوحدة'),
        '12',
      );
      await tester.tap(find.text('حفظ البند'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('متابعة إلى الدفع'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'المورد'))
            .enabled,
        isFalse,
      );
      await tester.ensureVisible(find.text('آجل'));
      await tester.tap(find.text('آجل'));
      await tester.pumpAndSettle();
      await approve();
      expect(d.engine.stock('p').quantity, 22000);
      expect(d.parties.balance('party', false), 2200);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Populated mobile features fit narrow screens and respect roles',
    (tester) async {
      final d = seededShop();
      final sale = d.invoices.post(
        requestId: 'sale',
        sale: true,
        partyId: 'party',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح موفر للطاقة',
            unit: 'حبة',
            quantity: 1000,
            price: 2000,
          ),
        ],
        payments: const [Payment(account: '1100', amount: 500)],
      );
      final purchase = d.invoices.post(
        requestId: 'purchase',
        sale: false,
        partyId: 'party',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح موفر للطاقة',
            unit: 'حبة',
            quantity: 3000,
            price: 1000,
          ),
        ],
        payments: [],
      );
      final receiving = d.receiving.receive(
        requestId: 'receiving',
        partyId: 'party',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح موفر للطاقة',
            unit: 'حبة',
            quantity: 1000,
            price: 1000,
          ),
        ],
      );
      d.finance.post(
        requestId: 'receipt',
        kind: 'receipt',
        partyId: 'party',
        payments: const [Payment(account: '1100', amount: 500)],
      );
      final router = await mount(tester, d, const Size(360, 800));
      final paths = {
        'home': '/',
        'sales': '/sales',
        'products': '/catalog',
        'product': '/catalog/p',
        'stock-list': '/inventory',
        'stock': '/inventory/p',
        'parties': '/parties',
        'party': '/parties/party',
        'purchases': '/purchases',
        'purchase': '/documents/${purchase.id}',
        'receiving': '/receiving',
        'finalize': '/receiving/finalize/${receiving.id}/finalize',
        'finance': '/finance',
        'finance-editor': '/finance/new',
        'return': '/returns/${sale.id}',
        'reports': '/reports',
        'settings': '/settings',
        'profile': '/profile',
        'more': '/more',
      };
      for (final entry in paths.entries) {
        router.go(entry.value);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: entry.key);
        expect(find.byType(DataTable), findsNothing, reason: entry.key);
        if (const [
          'home',
          'stock-list',
          'stock',
          'settings',
          'profile',
          'return',
          'purchases',
          'sales',
          'products',
          'finance',
          'more',
          'product',
          'party',
          'receiving',
          'reports',
        ].contains(entry.key)) {
          await capture(tester, entry.key);
        }
      }
      for (final size in [
        const Size(320, 640),
        const Size(430, 932),
        const Size(568, 320),
      ]) {
        tester.view.physicalSize = size;
        for (final path in paths.values) {
          router.go(path);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$path at $size');
        }
      }
      tester.view.physicalSize = const Size(360, 800);
      router.go('/more');
      await tester.pumpAndSettle();
      await tester.tap(find.text('المنتجات'));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/catalog');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      router.go('/purchases');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/more');
      router.go('/catalog/p');
      await tester.pumpAndSettle();
      await tester.tap(find.text('تعديل المنتج'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      final save = find.widgetWithText(DeptAccountingButton, 'حفظ المنتج');
      expect(tester.getBottomRight(save).dy, lessThanOrEqualTo(520));
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      d.store.user = d.store.user!.copyWith(role: 'seller');
      router.go('/more');
      await tester.pumpAndSettle();
      expect(find.text('المشتريات'), findsNothing);
      expect(find.text('الإعدادات والنسخ'), findsNothing);
      expect(find.text('التقارير والمحاسبة'), findsNothing);
      router.go('/purchases');
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
