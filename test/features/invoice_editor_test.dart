import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/features/catalog/data/product.dart';
import 'package:dukan_app/features/invoices/presentation/invoice_items_table.dart';
import 'package:dukan_app/features/invoices/presentation/invoice_summary_panel.dart';
import 'package:dukan_app/features/invoices/presentation/invoice_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDependencies d;
  setUp(() {
    d = AppDependencies(LocalDatabase.memory());
    d.store.user = const AppUser(
      id: 'owner',
      name: 'مالك',
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
      const Shop(name: 'اختبار', currency: 'SAR').toJson(),
    );
    d.catalog.save(
      const Product(
        id: 'p',
        name: 'حليب',
        salePrice: 1200,
        alternateUnit: 'كرتون',
        factor: 12000,
      ),
    );
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  test(
    'Cash tracks edits, partial splits and credit survive draft restore',
    () async {
      final vm = InvoiceViewModel(d, sale: true, id: 'payment');
      vm.add(d.catalog.get('p'));
      vm.lines.single.quantity = '2';
      vm.discount = '4';
      vm.edit();
      expect(vm.total, 2000);
      expect(vm.buildPayments().single.amount, 2000);
      vm.changePaymentMode(InvoicePaymentMode.partial);
      vm.payments.single.amount = '5';
      vm.addPayment();
      vm.payments.last.amount = '3';
      vm.edit();
      expect(vm.paid, 800);
      final restored = InvoiceViewModel(d, sale: true, id: 'payment');
      expect(restored.paymentMode, InvoicePaymentMode.partial);
      expect(
        restored.buildPayments().fold<int>(0, (sum, p) => sum + p.amount),
        800,
      );
      restored.changePaymentMode(InvoicePaymentMode.credit);
      expect(restored.buildPayments(), isEmpty);
      expect(restored.paid, 0);
      restored.changePaymentMode(InvoicePaymentMode.cash);
      restored.changeUnit(restored.lines.single, 'كرتون');
      expect(restored.buildPayments().single.amount, 28400);
      restored.dispose();
      vm.dispose();
    },
  );

  test(
    'Legacy item discounts become one invoice discount without changing net',
    () {
      d.invoices.saveDraft('old', 'sale', {
        'lines': [
          {
            'productId': 'p',
            'unit': 'حبة',
            'quantity': '2',
            'price': '12',
            'discount': '3',
            'description': 'قديم',
          },
        ],
        'payments': <Map<String, dynamic>>[],
        'discount': '2',
      });
      final vm = InvoiceViewModel(d, sale: true, id: 'old');
      expect(vm.discount, '5');
      expect(vm.total, 1900);
      expect(vm.buildLines().single.discount, 0);
      vm.saveDraft();
      final restored = InvoiceViewModel(d, sale: true, id: 'old');
      expect(restored.total, 1900);
      restored.dispose();
      vm.dispose();
    },
  );

  testWidgets(
    'Single item row edits update summary; compact and narrow layouts fit',
    (tester) async {
      final vm = InvoiceViewModel(d, sale: true, id: 'ui');
      vm.add(d.catalog.get('p'));
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: DukanTheme.light(),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => DukanEditorLayout(
                    minFormWidth: 688,
                    form: InvoiceItemsTable(vm: vm),
                    summary: InvoiceSummaryPanel(vm: vm, onConfirm: () {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final quantity = find
          .descendant(
            of: find.byType(InvoiceItemsTable),
            matching: find.byType(TextFormField),
          )
          .first;
      final price = find
          .descendant(
            of: find.byType(InvoiceItemsTable),
            matching: find.byType(TextFormField),
          )
          .last;
      expect(tester.getCenter(quantity).dy, tester.getCenter(price).dy);
      expect(tester.getSize(quantity).height, lessThan(48));
      await tester.enterText(quantity, '3');
      await tester.pump();
      expect(vm.paid, 3600);
      await tester.tap(find.text('آجل'));
      await tester.pump();
      expect(vm.paid, 0);
      expect(find.text('وصف البند (اختياري)'), findsNothing);
      expect(find.textContaining('خصم البند'), findsNothing);
      tester.view.physicalSize = const Size(390, 900);
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    },
  );
}
