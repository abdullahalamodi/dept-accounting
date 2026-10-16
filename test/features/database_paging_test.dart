import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/catalog/data/catalog_reference.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
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
    d.store.setSetting(
      'shop',
      const Shop(name: 'اختبار', currency: 'SAR').toJson(),
    );
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  test('Catalog and party SQL pages preserve literal search and filters', () {
    for (var i = 0; i < 23; i++) {
      final key = i.toString().padLeft(2, '0');
      d.catalog.save(
        Product(
          id: key,
          name: 'منتج $key',
          barcode: key,
          minStock: 1000,
          purchasePrice: 100,
        ),
      );
      d.parties.save(Party(id: key, name: 'طرف $key', phone: '55$key'));
    }
    d.catalog.opening('00', 2000);
    d.catalog.save(d.catalog.get('01').copyWith(active: false));
    d.catalog.save(d.catalog.get('02').copyWith(service: true));
    d.catalog.save(
      const Product(
        id: 'unicode',
        name: 'ÉCOLE %_',
        categoryId: 'category_tools',
      ),
    );
    d.parties.save(const Party(id: 'unicode', name: 'ÉCOLE %_'));
    final first = d.catalog.page(), second = d.catalog.page(page: 2);
    expect(first.total, 24);
    expect(first.items, hasLength(10));
    expect(
      first.items
          .map((r) => r.product.id)
          .toSet()
          .intersection(second.items.map((r) => r.product.id).toSet()),
      isEmpty,
    );
    expect(d.catalog.page(page: 99).page, 3);
    expect(d.catalog.page(page: 99).items, hasLength(4));
    expect(d.parties.page(page: 3).items, hasLength(4));
    expect(
      d.catalog.page(search: 'école %_').items.single.product.id,
      'unicode',
    );
    expect(d.parties.page(search: 'école %_').items.single.id, 'unicode');
    expect(d.catalog.page(search: 'unknown').items, isEmpty);
    expect(d.catalog.page(servicesOnly: true).items.single.product.id, '02');
    expect(
      d.catalog
          .page(lowOnly: true, pageSize: 50)
          .items
          .map((r) => r.product.id),
      isNot(anyOf(contains('00'), contains('01'), contains('02'))),
    );
    expect(
      d.catalog.page(category: 'category_tools').items.single.product.id,
      'unicode',
    );
    expect(d.catalog.page(search: 'منتج 00').items.single.quantity, 2000);
    final movements = d.inventory.movementPage('00', pageSize: 1);
    expect(movements.total, 1);
    expect(movements.items.single['quantity'], 2000);
    d.parties.save(d.parties.get('00').copyWith(supplier: true));
    d.parties.opening('00', false, 1234);
    expect(d.parties.statementPage('00', false).items.single['balance'], 1234);
    d.store.user = d.store.user!.copyWith(role: 'seller');
    expect(
      d.catalog.page().items.every((r) => r.product.purchasePrice == 0),
      isTrue,
    );
  });

  test(
    'Invoice summaries and oldest-first allocation match live dues and reports',
    () {
      d.parties.save(const Party(id: 'party', name: 'طرف'));
      d.parties.save(const Party(id: 'other', name: 'آخر'));
      d.catalog.save(const Product(id: 'service', name: 'خدمة', service: true));
      final today = DateTime.now();
      final old = today
          .subtract(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10);
      for (var i = 0; i < 23; i++) {
        d.invoices.post(
          requestId: 'invoice-$i',
          sale: true,
          partyId: i == 22 ? 'other' : 'party',
          date: i == 1 ? old : null,
          notes: i == 2 ? 'ÉCOLE %_' : '',
          lines: const [
            InvoiceLine(
              productId: 'service',
              name: 'خدمة',
              unit: 'حبة',
              quantity: 1000,
              price: 1000,
            ),
          ],
          payments: const [],
        );
      }
      d.finance.post(
        requestId: 'paid',
        kind: 'receipt',
        partyId: 'party',
        payments: const [Payment(account: '1100', amount: 1500)],
        allocations: {'invoice-0': 1000, 'invoice-1': 500},
      );
      d.returns.post(
        requestId: 'returned',
        invoiceId: 'invoice-2',
        reason: 'مرتجع',
        selected: [(index: 0, quantity: 0, serviceAmount: 250, damaged: false)],
      );
      d.corrections.cancel('invoice-3', 'cancelled', 'تصحيح');
      final first = d.invoices.page('sale'),
          last = d.invoices.page('sale', page: 3);
      expect(first.total, 23);
      expect(first.items, hasLength(10));
      expect(first.items.first.id, 'invoice-22');
      expect(last.items.map((r) => r.id), [
        'invoice-2',
        'invoice-1',
        'invoice-0',
      ]);
      expect(last.items.map((r) => r.due), [750, 500, 0]);
      expect(last.items.every((r) => r.partyName == 'طرف'), isTrue);
      expect(
        d.invoices.page('sale', search: 'école %_').items.single.id,
        'invoice-2',
      );
      final outstanding = d.invoices.outstanding('party', true);
      expect(outstanding.first.id, 'invoice-1');
      expect(
        outstanding.map((r) => r.id),
        isNot(
          anyOf(
            contains('invoice-0'),
            contains('invoice-3'),
            contains('invoice-22'),
          ),
        ),
      );
      for (final invoice in outstanding) {
        expect(invoice.due, d.invoices.due(invoice.id));
      }
      final allocation = d.finance.allocationPreview('party', true, 1100);
      expect(allocation, {'invoice-1': 500, 'invoice-2': 600});
      final duePage = d.invoices.outstandingPage('party', true, page: 2);
      expect(duePage.total, outstanding.length);
      expect(
        duePage.items.map((i) => i.id),
        outstanding.skip(5).take(5).map((i) => i.id),
      );
      final acrossPages = d.finance.allocationPreview('party', true, 8000);
      expect(acrossPages.length, greaterThan(5));
      expect(acrossPages.values.fold<int>(0, (a, b) => a + b), 8000);
      expect(acrossPages['invoice-10'], 750);
      expect(acrossPages.containsKey('invoice-11'), isFalse);
      final reportDay = DateTime(today.year, today.month, today.day);
      final report = d.reports.table('sales', reportDay, reportDay);
      expect(report.rows, hasLength(23));
      expect(report.rows.where((row) => row.last == 'ملغى'), hasLength(1));
      expect(
        report.summary['إجمالي المستندات المعتمدة'],
        Numbers.format(22000),
      );
      expect(report.rows.first[3], 'طرف');
      final fullStatement = d.parties.statement('party', true);
      final statementRows = [
        for (var page = 1; page <= (fullStatement.length + 4) ~/ 5; page++)
          ...d.parties
              .statementPage('party', true, page: page, pageSize: 5)
              .items,
      ];
      expect(
        statementRows.map((r) => r['id']),
        fullStatement.map((r) => r['id']),
      );
      var running = 0;
      for (var i = 0; i < fullStatement.length; i++) {
        running +=
            (fullStatement[i]['debit'] as int) -
            (fullStatement[i]['credit'] as int);
        expect(statementRows[i]['balance'], running);
      }
      final ledger = d.reports.ledger('1200', page: 2, pageSize: 5);
      expect(ledger.items, hasLength(5));
      expect(
        ledger.total,
        fullStatement.length + 1,
      ); // Includes the other party.
      final financial = d.finance.documentPage(pageSize: 1);
      expect(financial.items.single.id, 'paid');
      expect(financial.total, d.finance.documents().length);
      d.store.user = d.store.user!.copyWith(role: 'seller');
      expect(
        () => d.invoices.page('purchase'),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.invoices.outstanding('party', false),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('Paged selectors preserve roles, reference counts, draft ownership and pending receipts', () {
    d.parties.save(const Party(id: 'customer', name: 'A', customer: true));
    d.parties.save(
      const Party(id: 'dual', name: 'B', customer: true, supplier: true),
    );
    d.parties.save(
      const Party(id: 'supplier', name: 'C', customer: false, supplier: true),
    );
    d.parties.save(
      const Party(id: 'inactive', name: 'D', active: false, supplier: true),
    );
    expect(
      d.parties.page(activeOnly: true, customer: true, pageSize: 1).total,
      2,
    );
    expect(
      d.parties
          .page(activeOnly: true, customer: true, pageSize: 1, page: 2)
          .items
          .single
          .id,
      'dual',
    );
    expect(
      d.parties.page(activeOnly: true, customer: false).items.map((p) => p.id),
      ['dual', 'supplier'],
    );
    final category = d.catalogReferences.save(
      CatalogReferenceKind.category,
      name: 'École %_',
    );
    for (final id in ['p', 'q']) {
      d.catalog.save(
        Product(id: id, name: id, categoryId: category.id, purchasePrice: 100),
      );
    }
    expect(
      d.catalogReferences
          .page(CatalogReferenceKind.category, search: 'école %_')
          .items
          .single
          .productCount,
      2,
    );
    expect(
      d.catalogReferences
          .page(
            CatalogReferenceKind.category,
            search: 'école %_',
            counts: false,
          )
          .items
          .single
          .productCount,
      0,
    );
    d.catalogReferences.setActive(
      CatalogReferenceKind.category,
      category.id,
      false,
    );
    expect(
      d.catalogReferences
          .page(CatalogReferenceKind.category, search: 'école')
          .total,
      0,
    );
    expect(
      d.catalogReferences
          .page(
            CatalogReferenceKind.category,
            search: 'école',
            showInactive: true,
          )
          .total,
      1,
    );
    expect(
      d.catalogReferences
          .page(
            CatalogReferenceKind.category,
            showInactive: true,
            excludeId: category.id,
            search: 'école',
          )
          .total,
      0,
    );
    expect(d.catalogReferences.defaultUnit()!.id, 'unit_piece');
    for (var i = 0; i < 8; i++) {
      d.receiving.receive(
        requestId: 'receipt-$i',
        partyId: 'supplier',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'p',
            unit: 'حبة',
            quantity: 1000,
            price: 100,
          ),
        ],
      );
    }
    final pending = d.receiving.pending(pageSize: 5);
    expect(pending.total, 8);
    expect(pending.items, hasLength(5));
    expect(pending.items.first.id, 'receipt-7');
    expect(pending.items.every((r) => r.partyName == 'C'), isTrue);
    d.receiving.finalize(
      requestId: 'final',
      receiptId: 'receipt-0',
      actualPrices: [100],
      payments: [],
    );
    expect(d.receiving.pending().total, 7);
    final owner = d.store.user!;
    final other = owner.copyWith(
      id: 'other',
      username: 'other',
      role: 'accountant',
    );
    for (final user in [owner, other]) {
      d.store.database.handle.execute('INSERT INTO users VALUES (?,?,?,?)', [
        user.id,
        user.username,
        user.toJson(),
        'test-only',
      ]);
    }
    for (var i = 0; i < 12; i++) {
      d.invoices.saveDraft(
        'draft-${i.toString().padLeft(2, '0')}',
        'receipt_invoice',
        {'receiptId': 'receipt-${i % 8}'},
      );
    }
    d.store.user = other;
    d.invoices.saveDraft('other-draft', 'receipt_invoice', {
      'receiptId': 'receipt-0',
    });
    d.store.user = owner;
    d.invoices.saveDraft('sale-draft', 'sale', {});
    d.store.database.handle.execute(
      "UPDATE drafts SET updated_at='2026-10-16T12:00:00Z'",
    );
    final drafts = d.invoices.drafts('receipt_invoice', page: 2);
    expect(drafts.total, 12);
    expect(drafts.items.map((r) => r.id), [
      'draft-06',
      'draft-05',
      'draft-04',
      'draft-03',
      'draft-02',
    ]);
    expect(drafts.items.every((r) => r.receiptId != null), isTrue);
  });

  test(
    'Credit paging excludes used and cancelled sources; refunds span pages',
    () {
      d.parties.save(const Party(id: 'party', name: 'طرف'));
      d.catalog.save(const Product(id: 'service', name: 'خدمة', service: true));
      d.invoices.post(
        requestId: 'sale',
        sale: true,
        partyId: 'party',
        payments: [],
        lines: const [
          InvoiceLine(
            productId: 'service',
            name: 'خدمة',
            unit: 'حبة',
            quantity: 1000,
            price: 100,
          ),
        ],
      );
      for (var i = 0; i < 12; i++) {
        d.finance.post(
          requestId: 'credit-$i',
          kind: 'receipt',
          partyId: 'party',
          notes: i == 7 ? 'إيداع %_' : '',
          payments: const [Payment(account: '1100', amount: 100)],
        );
      }
      d.credits.allocate('allocated', 'credit-0', {'sale': 100});
      d.corrections.cancel('credit-1', 'cancelled', 'تصحيح');
      expect(d.credits.source('party', true, 'credit-0'), isNull);
      expect(d.credits.source('party', true, 'credit-1'), isNull);
      expect(d.credits.source('unrelated', true, 'credit-7'), isNull);
      final second = d.credits.sourcePage('party', true, page: 2);
      expect(second.total, 10);
      expect(second.items, hasLength(5));
      expect(
        d.credits.sourcePage('party', true, search: 'إيداع %_').items.single.id,
        'credit-7',
      );
      d.credits.refund(
        requestId: 'refund',
        partyId: 'party',
        customer: true,
        account: '1100',
        amount: 750,
        reason: 'رد',
      );
      expect(
        d.store.database.handle.select(
          "SELECT * FROM allocations WHERE invoice_id = 'refund'",
        ),
        hasLength(8),
      );
      expect(d.credits.sourcePage('party', true).total, 3);
      expect(d.credits.source('party', true, 'credit-9')!.available, 50);
      expect(d.parties.balance('party', true), -250);
      expect(d.engine.balance('1100'), 350);
    },
  );
}
