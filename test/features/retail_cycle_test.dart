import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/auth/data/passwords.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
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
      const Shop(name: 'اختبار', currency: 'YER').toJson(),
    );
    d.catalog.save(
      const Product(
        id: 'p',
        name: 'مصباح',
        salePrice: 150000,
        purchasePrice: 100000,
      ),
    );
    d.parties.save(
      const Party(id: 'party', name: 'طرف', customer: true, supplier: true),
    );
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });
  test(
    'Opening stock reads the saved buying price and preserves its posted value',
    () {
      d.catalog.save(
        d.catalog.get('p').copyWith(purchasePrice: 12345, fractional: true),
      );
      d.catalog.opening('p', 1500);
      expect(d.engine.stock('p').quantity, 1500);
      expect(d.engine.stock('p').value, 18518);
      expect(d.engine.balance('1300'), 18518);
      expect(d.engine.balance('3900'), -18518);
      d.catalog.save(d.catalog.get('p').copyWith(purchasePrice: 20000));
      expect(d.engine.stock('p').value, 18518);
      expect(
        () => d.catalog.opening('p', 1000),
        throwsA(isA<BusinessException>()),
      );
      d.catalog.save(const Product(id: 'zero', name: 'بدون سعر'));
      expect(
        () => d.catalog.opening('zero', 1000),
        throwsA(isA<BusinessException>()),
      );
      expect(d.engine.stock('zero').quantity, 0);
      d.catalog.save(
        const Product(id: 'whole', name: 'منتج كامل', purchasePrice: 100),
      );
      expect(
        () => d.catalog.opening('whole', 500),
        throwsA(isA<BusinessException>()),
      );
      d.catalog.save(
        const Product(
          id: 'service',
          name: 'خدمة',
          service: true,
          purchasePrice: 100,
        ),
      );
      expect(
        () => d.catalog.opening('service', 1000),
        throwsA(isA<BusinessException>()),
      );
      d.store.setSetting('opening_closed', 'true');
      expect(
        () => d.catalog.opening('whole', 1000),
        throwsA(isA<BusinessException>()),
      );
      expect(d.engine.stock('whole').quantity, 0);
    },
  );

  test('Approved operating cycle reconciles cash, stock, both party roles, and journal', () {
    d.finance.openAccount('1100', 2000000);
    d.invoices.post(
      requestId: 'buy',
      sale: false,
      partyId: 'party',
      lines: const [
        InvoiceLine(
          productId: 'p',
          name: 'مصباح',
          unit: 'حبة',
          quantity: 10000,
          price: 100000,
        ),
      ],
      payments: const [Payment(account: '1100', amount: 400000)],
    );
    final sell = d.invoices.post(
      requestId: 'sell',
      sale: true,
      partyId: 'party',
      lines: const [
        InvoiceLine(
          productId: 'p',
          name: 'مصباح',
          unit: 'حبة',
          quantity: 3000,
          price: 150000,
        ),
      ],
      payments: const [Payment(account: '1100', amount: 200000)],
    );
    expect(d.engine.stock('p').quantity, 7000);
    expect(d.engine.stock('p').value, 700000);
    expect(d.parties.balance('party', true), 250000);
    expect(d.parties.balance('party', false), 600000);
    d.finance.post(
      requestId: 'collect',
      kind: 'receipt',
      partyId: 'party',
      payments: const [Payment(account: '1100', amount: 250000)],
      allocations: d.finance.allocationPreview('party', true, 250000),
    );
    expect(d.engine.balance('1100'), 2050000);
    expect(d.invoices.due(sell.id), 0);
    expect(d.parties.balance('party', true), 0);
    expect(d.parties.balance('party', false), 600000);
    expect(d.reports.overview()['profit'], 150000);
    expect(
      d.reports.trialBalance().fold<int>(
        0,
        (n, r) => n + (r['debit'] as int) - (r['credit'] as int),
      ),
      0,
    );
  });
  test('Repeated approvals are idempotent, failures roll back, and duplicate lines cannot oversell', () {
    final input = [
      const InvoiceLine(
        productId: 'p',
        name: 'مصباح',
        unit: 'حبة',
        quantity: 10000,
        price: 100000,
      ),
    ];
    final purchase = d.invoices.post(
      requestId: 'buy',
      sale: false,
      partyId: 'party',
      lines: input,
      payments: [],
    );
    final retry = d.invoices.post(
      requestId: 'buy',
      sale: false,
      partyId: 'party',
      lines: input,
      payments: [],
    );
    expect(retry.id, purchase.id);
    expect(d.engine.stock('p').quantity, 10000);
    final count = d.store.database.handle
        .select('SELECT COUNT(*) AS n FROM documents')
        .first['n'];
    expect(
      () => d.invoices.post(
        requestId: 'bad',
        sale: true,
        partyId: 'party',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح',
            unit: 'حبة',
            quantity: 6000,
            price: 150000,
          ),
          InvoiceLine(
            productId: 'p',
            name: 'مصباح',
            unit: 'حبة',
            quantity: 6000,
            price: 150000,
          ),
        ],
        payments: [],
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => d.finance.post(
        requestId: 'bad-cash',
        kind: 'expense',
        category: 'تشغيل',
        payments: const [Payment(account: '1100', amount: 100)],
      ),
      throwsA(isA<BusinessException>()),
    );
    expect(d.engine.stock('p').quantity, 10000);
    expect(
      d.store.database.handle
          .select('SELECT COUNT(*) AS n FROM documents')
          .first['n'],
      count,
    );
    final sale = d.invoices.post(
      requestId: 'cancel-sale',
      sale: true,
      lines: const [
        InvoiceLine(
          productId: 'p',
          name: 'مصباح',
          unit: 'حبة',
          quantity: 1000,
          price: 150000,
        ),
      ],
      payments: const [Payment(account: '1100', amount: 150000)],
    );
    d.corrections.cancel(sale.id, 'reversal', 'تصحيح');
    expect(d.engine.stock('p').quantity, 10000);
    expect(d.engine.balance('1100'), 0);
    expect(d.corrections.isCancelled(sale.id), isTrue);
  });
  test(
    'Backup authentication rejects wrong keys and preserves encrypted content',
    () async {
      final key = Passwords.token(32), bytes = [1, 2, 3, 4, 5];
      final encrypted = await d.backups.encrypt(bytes, key);
      expect(await d.backups.decrypt(encrypted, key), bytes);
      await expectLater(
        d.backups.decrypt(encrypted, Passwords.token(32)),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('Quick receipt finalization adjusts sold and remaining costs without repeating stock', () {
    final selectedDate = DateTime.now().subtract(const Duration(hours: 1));
    final receipt = d.receiving.receive(
      requestId: 'receive',
      partyId: 'party',
      date: selectedDate.toIso8601String(),
      lines: const [
        InvoiceLine(
          productId: 'p',
          name: 'مصباح',
          unit: 'حبة',
          quantity: 10000,
          price: 100000,
        ),
      ],
    );
    expect(receipt.date, selectedDate.toIso8601String());
    final sale = d.invoices.post(
      requestId: 'sell',
      sale: true,
      partyId: 'party',
      lines: const [
        InvoiceLine(
          productId: 'p',
          name: 'مصباح',
          unit: 'حبة',
          quantity: 4000,
          price: 150000,
        ),
      ],
      payments: [],
    );
    d.returns.post(
      requestId: 'return-before-final',
      invoiceId: sale.id,
      selected: [(index: 0, quantity: 1000, serviceAmount: 0, damaged: false)],
      reason: 'صالح',
    );
    d.receiving.finalize(
      requestId: 'final',
      receiptId: receipt.id,
      actualPrices: [110000],
      payments: [],
    );
    expect(d.engine.stock('p').quantity, 7000);
    expect(d.engine.stock('p').value, 770000);
    expect(d.engine.balance('5100'), 330000);
    expect(d.engine.balance('2200'), 0);
    expect(d.parties.balance('party', false), 1100000);
    expect(d.returns.history(sale).corrections.single, 40000);
    expect(d.invoices.get(sale.id).lines.single.cost, 400000);
    expect(
      d.store.database.handle.select(
        'SELECT amount FROM cost_adjustments WHERE invoice_id = ?',
        [sale.id],
      ).single['amount'],
      40000,
    );
    d.returns.post(
      requestId: 'return-after-final',
      invoiceId: sale.id,
      selected: [(index: 0, quantity: 1000, serviceAmount: 0, damaged: false)],
      reason: 'صالح',
    );
    expect(d.engine.stock('p').value, 880000);
    expect(d.engine.balance('5100'), 220000);
    expect(d.returns.history(sale).returned.single.cost, 220000);
    expect(
      d.reports.trialBalance().fold<int>(
        0,
        (n, r) => n + (r['debit'] as int) - (r['credit'] as int),
      ),
      0,
    );
  });
  for (final price in [90000, 110000]) {
    test(
      'Final cost $price splits duplicate product lines across partial returns',
      () {
        final receipt = d.receiving.receive(
          requestId: 'receive',
          partyId: 'party',
          lines: const [
            InvoiceLine(
              productId: 'p',
              name: 'مصباح',
              unit: 'حبة',
              quantity: 10000,
              price: 100000,
            ),
          ],
        );
        final sale = d.invoices.post(
          requestId: 'sale',
          sale: true,
          partyId: 'party',
          payments: [],
          lines: const [
            InvoiceLine(
              productId: 'p',
              name: 'مصباح',
              unit: 'حبة',
              quantity: 2000,
              price: 150000,
            ),
            InvoiceLine(
              productId: 'p',
              name: 'مصباح',
              unit: 'حبة',
              quantity: 2000,
              price: 150000,
            ),
          ],
        );
        d.returns.post(
          requestId: 'before',
          invoiceId: sale.id,
          reason: 'صالح',
          selected: [
            (index: 0, quantity: 1000, serviceAmount: 0, damaged: false),
          ],
        );
        for (var retry = 0; retry < 2; retry++) {
          d.receiving.finalize(
            requestId: 'final',
            receiptId: receipt.id,
            actualPrices: [price],
            payments: [],
          );
        }
        expect(
          d.store.database.handle.select('SELECT * FROM cost_adjustments'),
          hasLength(1),
        );
        expect(
          d.returns.history(sale).corrections,
          List.filled(2, (price - 100000) * 2),
        );
        expect(d.returns.history(sale).returned.first.cost, price);
        d.returns.post(
          requestId: 'after',
          invoiceId: sale.id,
          reason: 'صالح',
          selected: [
            (index: 0, quantity: 1000, serviceAmount: 0, damaged: false),
            (index: 1, quantity: 2000, serviceAmount: 0, damaged: false),
          ],
        );
        expect(d.engine.stock('p').quantity, 10000);
        expect(d.engine.stock('p').value, price * 10);
        expect(d.engine.balance('5100'), 0);
        expect(d.invoices.get(sale.id).lines.map((l) => l.cost), [
          200000,
          200000,
        ]);
      },
    );
  }
  test(
    'Mixed invoice partial service refund changes money without moving stock',
    () {
      d.catalog.save(
        const Product(
          id: 'service',
          name: 'تركيب',
          service: true,
          salePrice: 50000,
        ),
      );
      d.catalog.opening('p', 2000);
      final sale = d.invoices.post(
        requestId: 'mixed',
        sale: true,
        partyId: 'party',
        lines: const [
          InvoiceLine(
            productId: 'p',
            name: 'مصباح',
            unit: 'حبة',
            quantity: 1000,
            price: 150000,
          ),
          InvoiceLine(
            productId: 'service',
            name: 'تركيب',
            unit: 'حبة',
            quantity: 1000,
            price: 50000,
            service: true,
          ),
        ],
        payments: const [Payment(account: '1100', amount: 100000)],
      );
      d.returns.post(
        requestId: 'refund-service',
        invoiceId: sale.id,
        selected: [
          (index: 1, quantity: 0, serviceAmount: 25000, damaged: false),
        ],
        reason: 'رد جزئي',
      );
      expect(d.engine.stock('p').quantity, 1000);
      expect(d.engine.balance('4200'), -25000);
      expect(d.invoices.due(sale.id), 75000);
      expect(
        () => d.returns.post(
          requestId: 'excess-return',
          invoiceId: sale.id,
          selected: [
            (index: 1, quantity: 0, serviceAmount: 30000, damaged: false),
          ],
          reason: 'زيادة',
        ),
        throwsA(isA<BusinessException>()),
      );
    },
  );

  test('Existing advances allocate without moving cash, and refunded credit cannot be used twice', () {
    final advance = d.finance.post(
      requestId: 'advance',
      kind: 'receipt',
      partyId: 'party',
      payments: const [Payment(account: '1100', amount: 300000)],
    );
    d.catalog.save(
      const Product(
        id: 'service',
        name: 'تركيب',
        service: true,
        salePrice: 100000,
      ),
    );
    final sale = d.invoices.post(
      requestId: 'credit-sale',
      sale: true,
      partyId: 'party',
      lines: const [
        InvoiceLine(
          productId: 'service',
          name: 'تركيب',
          unit: 'حبة',
          quantity: 1000,
          price: 100000,
          service: true,
        ),
      ],
      payments: [],
    );
    d.credits.allocate('allocation', advance.id, {sale.id: 100000});
    expect(d.engine.balance('1100'), 300000);
    expect(d.invoices.due(sale.id), 0);
    d.credits.refund(
      requestId: 'refund',
      partyId: 'party',
      customer: true,
      account: '1100',
      amount: 200000,
      reason: 'رد الزائد',
    );
    expect(d.engine.balance('1100'), 100000);
    expect(d.parties.balance('party', true), 0);
    expect(d.credits.sources('party', true), isEmpty);
    expect(
      () => d.credits.refund(
        requestId: 'refund-again',
        partyId: 'party',
        customer: true,
        account: '1100',
        amount: 1,
        reason: 'تكرار',
      ),
      throwsA(isA<BusinessException>()),
    );
  });
}
