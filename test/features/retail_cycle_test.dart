import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/core/numbers.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/features/auth/data/passwords.dart';
import 'package:dukan_app/features/catalog/data/product.dart';
import 'package:dukan_app/features/invoices/data/document.dart';
import 'package:dukan_app/features/parties/data/party.dart';
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
    d.returns.post(
      requestId: 'return-after-final',
      invoiceId: sale.id,
      selected: [(index: 0, quantity: 1000, serviceAmount: 0, damaged: false)],
      reason: 'صالح',
    );
    expect(d.engine.stock('p').value, 880000);
    expect(d.engine.balance('5100'), 220000);
    expect(
      d.reports.trialBalance().fold<int>(
        0,
        (n, r) => n + (r['debit'] as int) - (r['credit'] as int),
      ),
      0,
    );
  });
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
      d.catalog.opening('p', 2000, 1000000000);
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
