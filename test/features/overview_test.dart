import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:dept_accounting/features/overview/presentation/overview_view_model.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../support/load_app_fonts.dart';

AppDependencies shop() {
  final d = AppDependencies(LocalDatabase.memory());
  d.store.setSetting(
    'shop',
    const Shop(name: 'بقالة البركة', currency: 'SAR').toJson(),
  );
  d.store.user = const AppUser(
    id: 'owner',
    name: 'أحمد',
    username: 'owner',
    role: 'owner',
  );
  return d;
}

void seed(AppDependencies d) {
  for (final (id, name, quantity) in [
    ('rice', 'أرز بسمتي 5 كجم', 15000),
    ('oil', 'زيت زيتون 500 مل', 6000),
    ('coffee', 'قهوة عربية 250 جم', 4000),
    ('juice', 'عصير برتقال 1 لتر', 7000),
  ]) {
    d.catalog.save(
      Product(id: id, name: name, minStock: 10000, purchasePrice: 10000),
    );
    d.catalog.opening(id, quantity);
  }
  d.parties.save(const Party(id: 'customer', name: 'أحمد العتيبي'));
  final now = DateTime.now();
  for (var i = 0; i < 7; i++) {
    final total = [34050, 42000, 29500, 58000, 46000, 65000, 48550][i];
    final paid = i == 5
        ? 20000
        : i == 3
        ? 0
        : total;
    final doc = d.invoices.post(
      requestId: 'sale-$i',
      sale: true,
      partyId: paid < total ? 'customer' : null,
      lines: [
        InvoiceLine(
          productId: 'rice',
          name: 'أرز بسمتي 5 كجم',
          unit: 'حبة',
          quantity: 1000,
          price: total,
        ),
      ],
      payments: paid == 0 ? [] : [Payment(account: '1100', amount: paid)],
    );
    final at = DateTime(
      now.year,
      now.month,
      now.day - 6 + i,
      10,
    ).toUtc().toIso8601String();
    final updated = doc.copyWith(postedAt: at, date: at.substring(0, 10));
    d.store.database.handle.execute(
      'UPDATE documents SET posted_at=?,data=? WHERE id=?',
      [at, updated.toJson(), doc.id],
    );
  }
}

void main() {
  test('Overview uses posted movement, live allocations and hides profit for sellers', () async {
    final d = shop();
    expect(d.overview.activity(7).every((day) => day.sales == 0), isTrue);
    expect(d.overview.recentInvoices(), isEmpty);
    expect(d.overview.lowStock(), isEmpty);
    seed(d);
    final vm = OverviewViewModel(d.overview);
    await vm.refresh();
    expect(vm.activity.length, 7);
    expect(vm.activity.last.sales, 48550);
    expect(vm.activity.last.profit, 38550);
    expect(
      vm.lowStock.map((p) => p.id),
      containsAll(['rice', 'oil', 'coffee', 'juice']),
    );
    final partial = vm.invoices.firstWhere((r) => r.document.id == 'sale-5');
    expect(partial.paid, 20000);
    expect(partial.due, 45000);
    d.finance.post(
      requestId: 'collect',
      kind: 'receipt',
      partyId: 'customer',
      payments: const [Payment(account: '1100', amount: 45000)],
      allocations: {'sale-5': 45000},
    );
    await vm.refresh();
    expect(vm.invoices.firstWhere((r) => r.document.id == 'sale-5').due, 0);
    d.corrections.cancel('sale-6', 'cancel-sale', 'تصحيح فاتورة');
    await vm.refresh();
    expect(vm.invoices.first.cancelled, isTrue);
    expect(vm.activity.last.sales, 0);
    expect(vm.activity.last.profit, 0);
    d.returns.post(
      requestId: 'return-sale',
      invoiceId: 'sale-3',
      reason: 'مرتجع عميل',
      selected: [(index: 0, quantity: 1000, serviceAmount: 0, damaged: false)],
    );
    await vm.refresh();
    expect(vm.invoices.firstWhere((r) => r.document.id == 'sale-3').paid, 0);
    expect(vm.invoices.firstWhere((r) => r.document.id == 'sale-3').due, 0);
    expect(vm.activity.last.sales, -58000);
    expect(vm.activity.last.profit, -48000);
    await vm.changePeriod(30);
    expect(vm.activity.length, 30);
    d.store.user = d.store.user!.copyWith(role: 'seller');
    await vm.refresh();
    expect(vm.activity.every((p) => p.profit == null), isTrue);
    vm.dispose();
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  testWidgets(
    'Overview adapts and its period, stock link and quick actions work',
    (tester) async {
      const capture = String.fromEnvironment('DEPT_ACCOUNTING_CAPTURE_DIR');
      await loadAppFonts();
      final key = GlobalKey();
      for (final width in [1920.0, 1440.0, 800.0, 390.0]) {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        final d = shop();
        seed(d);
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: DeptAccountingApp(dependencies: d),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('حركة المبيعات'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'overview at $width');
        final actions = tester.getRect(
          find.byKey(const ValueKey('overview-quick-actions')),
        );
        final chart = tester.getRect(
          find.widgetWithText(DeptAccountingPanel, 'حركة المبيعات'),
        );
        if (width >= 1440) {
          expect(actions.left, greaterThan(chart.right));
          expect(actions.top, chart.top);
        } else {
          expect(actions.bottom, lessThan(chart.top));
        }
        if (width >= 1440) {
          final scroll = tester.widget<SingleChildScrollView>(
            find.descendant(
              of: find.byType(DeptAccountingDataTable),
              matching: find.byType(SingleChildScrollView),
            ),
          );
          expect(
            scroll.controller!.position.maxScrollExtent,
            lessThanOrEqualTo(1),
          );
        }
        if (capture.isNotEmpty) {
          await tester.runAsync(() async {
            final boundary =
                key.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory(capture).create(recursive: true);
            await File('$capture/overview-${width.toInt()}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.ensureVisible(find.byTooltip('فترة حركة المبيعات'));
        await tester.tap(find.byTooltip('فترة حركة المبيعات'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('آخر ٣٠ يومًا'));
        await tester.pumpAndSettle();
        expect(find.text('آخر ٣٠ يومًا'), findsOneWidget);
        final router = GoRouter.of(
          tester.element(find.byType(DeptAccountingWorkspace)),
        );
        if (width == 1440) {
          await tester.ensureVisible(find.text('تسجيل مصروف'));
          await tester.tap(find.text('تسجيل مصروف'));
          await tester.pumpAndSettle();
          expect(router.state.uri.queryParameters['kind'], 'expense');
          expect(find.text('تصنيف المصروف'), findsOneWidget);
          router.go('/');
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.text('عرض المنتجات منخفضة المخزون ←'),
          );
          await tester.tap(find.text('عرض المنتجات منخفضة المخزون ←'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<FilterChip>(
                  find.widgetWithText(FilterChip, 'مخزون منخفض'),
                )
                .selected,
            isTrue,
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
