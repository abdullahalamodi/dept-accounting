import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_items_table.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_summary_panel.dart';
import 'package:dept_accounting/features/invoices/presentation/invoice_view_model.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/load_app_fonts.dart';

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
    d.parties.save(const Party(id: 'customer', name: 'عميل تجريبي'));
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  test(
    'Barcode scans preserve eligibility, quantity and price visibility',
    () async {
      d.catalog.save(
        d.catalog.get('p').copyWith(barcode: '123', purchasePrice: 700),
      );
      d.catalog.save(
        const Product(
          id: 'inactive',
          name: 'موقوف',
          barcode: '456',
          active: false,
        ),
      );
      d.catalog.save(
        const Product(
          id: 'service',
          name: 'خدمة',
          barcode: '789',
          service: true,
        ),
      );
      final sale = InvoiceViewModel(d, sale: true, id: 'scan-sale');
      final purchase = InvoiceViewModel(d, sale: false, id: 'scan-purchase');
      expect(
        (await purchase.searchProducts('', 1)).items.map((r) => r.product.id),
        ['p'],
      );
      expect(
        (await sale.searchProducts('', 1)).items.map((r) => r.product.id),
        contains('service'),
      );
      expect(sale.addBarcode(' 123 '), isTrue);
      expect(sale.addBarcode('123'), isTrue);
      expect(sale.lines.single.quantity, '2');
      expect(sale.lines.single.price, '12');
      expect(purchase.addBarcode('123'), isTrue);
      expect(purchase.lines.single.price, '7');
      expect(sale.addBarcode('456'), isFalse);
      expect(sale.addBarcode('missing'), isFalse);
      expect(sale.addBarcode(' '), isFalse);
      expect(sale.addBarcode('789'), isTrue);
      expect(purchase.addBarcode('789'), isFalse);
      d.store.user = d.store.user!.copyWith(role: 'seller');
      expect(d.catalog.findBarcode('123')!.purchasePrice, 0);
      expect(sale.addBarcode('123'), isTrue);
      expect(sale.lines.first.quantity, '3');
      sale.dispose();
      purchase.dispose();
    },
  );

  test(
    'Cash tracks edits, partial splits and credit survive draft restore',
    () async {
      final vm = InvoiceViewModel(d, sale: true, id: 'payment');
      vm.partyId = 'customer';
      final selectedDate = DateTime.now().subtract(const Duration(hours: 1));
      vm.date = selectedDate.toIso8601String();
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
      await vm.saveDraft(silent: true);
      final restored = InvoiceViewModel(d, sale: true, id: 'payment');
      expect(restored.date, selectedDate.toIso8601String());
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
      restored.partyId = null;
      restored.edit();
      expect(restored.paymentMode, InvoicePaymentMode.cash);
      for (final mode in [
        InvoicePaymentMode.credit,
        InvoicePaymentMode.partial,
      ]) {
        restored.changePaymentMode(mode);
        expect(restored.paymentMode, InvoicePaymentMode.cash);
      }
      expect(restored.paid, restored.total);
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
      await loadAppFonts();
      final vm = InvoiceViewModel(d, sale: true, id: 'ui');
      vm.add(d.catalog.get('p'));
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: SingleChildScrollView(
                child: ListenableBuilder(
                  listenable: vm,
                  builder: (context, _) => DeptAccountingEditorLayout(
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
      final unit = find.descendant(
        of: find.byType(InvoiceItemsTable),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      expect(tester.getSize(quantity).height, tester.getSize(unit).height);
      expect(tester.getSize(price).height, tester.getSize(unit).height);
      final quantityValue = find.descendant(
        of: quantity,
        matching: find.byType(EditableText),
      );
      final unitValue = find
          .descendant(of: unit, matching: find.text('حبة'))
          .first;
      expect(
        InputDecorator.containerOf(tester.element(quantityValue))!.size.height,
        InputDecorator.containerOf(tester.element(unitValue))!.size.height,
      );
      expect(
        tester.widget<EditableText>(quantityValue).textAlign,
        TextAlign.end,
      );
      final rowTotal = find.descendant(
        of: find.byType(InvoiceItemsTable),
        matching: find.byWidgetPredicate(
          (widget) => widget is Text && widget.data == '12',
        ),
      );
      expect(tester.widget<Text>(rowTotal).textAlign, TextAlign.start);
      final priceValue = find.descendant(
        of: price,
        matching: find.byType(EditableText),
      );
      for (final pair in [
        (find.text('الكمية'), quantityValue),
        (find.text('سعر الوحدة'), priceValue),
      ]) {
        expect(
          tester.getTopRight(pair.$1).dx,
          closeTo(tester.getTopRight(pair.$2).dx, 1),
        );
      }
      expect(
        tester.getTopLeft(find.text('الإجمالي').first).dx,
        tester.getTopLeft(rowTotal).dx,
      );
      final discount = find.descendant(
        of: find.byKey(const ValueKey('invoice-discount')),
        matching: find.byType(TextFormField),
      );
      expect(tester.widget<TextFormField>(discount).initialValue, isEmpty);
      expect(
        tester.getCenter(discount).dy,
        closeTo(tester.getCenter(find.text('خصم الفاتورة')).dy, 1),
      );
      expect(tester.getSize(discount).width, lessThan(140));
      expect(
        tester.getTopRight(find.text('خصم الفاتورة')).dx,
        tester.getTopRight(find.text('مجموع البنود')).dx,
      );
      await tester.enterText(discount, '1');
      await tester.pump();
      expect(vm.total, 1100);
      await tester.enterText(discount, '');
      await tester.pump();
      expect(vm.total, 1200);
      await tester.enterText(quantity, '3');
      await tester.pump();
      expect(vm.paid, 3600);
      for (final label in ['آجل', 'دفع جزئي']) {
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, label),
              )
              .onPressed,
          isNull,
        );
      }
      expect(
        find.text('اختر عميلًا لتفعيل البيع الآجل أو الدفع الجزئي.'),
        findsOneWidget,
      );
      vm.partyId = 'customer';
      vm.edit();
      await tester.pump();
      expect(
        find.text('اختر عميلًا لتفعيل البيع الآجل أو الدفع الجزئي.'),
        findsNothing,
      );
      await tester.tap(find.text('دفع جزئي'));
      await tester.pumpAndSettle();
      final summaryAccount = find.descendant(
        of: find.byType(InvoiceSummaryPanel),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      final paidInput = find.widgetWithText(TextFormField, 'المدفوع (ر.س)');
      expect(tester.getSize(discount).height, 44);
      expect(
        tester.getSize(paidInput).height,
        tester.getSize(summaryAccount).height,
      );
      expect(
        tester.getSize(discount).height,
        tester.getSize(summaryAccount).height,
      );
      await tester.tap(find.text('آجل'));
      await tester.pump();
      expect(vm.paid, 0);
      vm.partyId = null;
      vm.edit();
      await tester.pump();
      expect(vm.paymentMode, InvoicePaymentMode.cash);
      expect(vm.paid, vm.total);
      expect(find.text('وصف البند (اختياري)'), findsNothing);
      expect(find.textContaining('خصم البند'), findsNothing);
      tester.view.physicalSize = const Size(390, 900);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();
      expect(
        tester.getSize(quantity).height,
        closeTo(tester.getSize(unit).height, 0.5),
      );
      expect(
        tester.getSize(price).height,
        closeTo(tester.getSize(unit).height, 0.5),
      );
      expect(
        InputDecorator.containerOf(tester.element(quantityValue))!.size.height,
        closeTo(
          InputDecorator.containerOf(tester.element(unitValue))!.size.height,
          0.5,
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      vm.dispose();
    },
  );
}
