import 'package:flutter_test/flutter_test.dart';
import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/catalog/data/product.dart';
import 'package:dept_accounting/features/parties/data/party.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';

void main() {
  test(
    'period report pages preserve complete totals and cumulative balances',
    () {
      final d = AppDependencies(LocalDatabase.memory());
      try {
        d.store.user = const AppUser(
          id: 'owner',
          name: 'Owner',
          username: 'owner',
          role: 'owner',
        );
        d.store.setSetting(
          'shop',
          const Shop(name: 'Fixture', currency: 'SAR').toJson(),
        );
        d.parties.save(const Party(id: 'party', name: 'Party', supplier: true));
        d.catalog.save(
          const Product(id: 'p', name: 'Product', purchasePrice: 100),
        );
        d.catalog.save(
          const Product(id: 'service', name: 'Service', service: true),
        );
        d.catalog.opening('p', 100000);
        d.finance.openAccount('1100', 100000);
        for (var i = 0; i < 14; i++) {
          d.invoices.post(
            requestId: 'sale$i',
            sale: true,
            partyId: 'party',
            lines: const [
              InvoiceLine(
                productId: 'p',
                name: 'Product',
                unit: 'حبة',
                quantity: 1000,
                price: 500,
              ),
            ],
            payments: const [Payment(account: '1100', amount: 200)],
          );
        }
        d.corrections.cancel('sale13', 'cancel', 'Reason');
        d.invoices.post(
          requestId: 'buy',
          sale: false,
          partyId: 'party',
          lines: const [
            InvoiceLine(
              productId: 'p',
              name: 'Product',
              unit: 'حبة',
              quantity: 1000,
              price: 200,
            ),
          ],
          payments: [],
        );
        d.finance.post(
          requestId: 'expense',
          kind: 'expense',
          category: 'Utilities',
          payments: const [Payment(account: '1100', amount: 100)],
        );
        d.returns.post(
          requestId: 'return',
          invoiceId: 'sale0',
          reason: 'Return',
          selected: [
            (index: 0, quantity: 1000, serviceAmount: 0, damaged: false),
          ],
        );
        final now = DateTime.now();
        final day = DateTime(now.year, now.month, now.day);
        for (final from in [day, day.subtract(const Duration(days: 7))]) {
          for (final kind in [
            'profit',
            'stock',
            'parties',
            'cash',
            'trial',
            'sales',
            'purchases',
            'returns',
            'expenses',
            'other',
          ]) {
            final actual = d.reports.table(kind, from, day);
            final clamped = d.reports.page(
              kind,
              from,
              day,
              page: 99999,
              pageSize: 3,
            );
            expect(clamped.report.rows.length, lessThanOrEqualTo(3));
            expect(clamped.report.summary, actual.summary);
            final rows = <List<String>>[];
            for (var page = 1; page <= (actual.rows.length + 2) ~/ 3; page++) {
              final result = d.reports.page(
                kind,
                from,
                day,
                page: page,
                pageSize: 3,
              );
              expect(result.total, actual.rows.length);
              expect(result.report.summary, actual.summary);
              rows.addAll(result.report.rows);
            }
            expect(rows, actual.rows, reason: 'paged $kind');
          }
        }
        final before = d.reports.page('sales', day, day, pageSize: 3);
        expect(before.total, 14);
        expect(before.report.summary, isNotEmpty);
        d.invoices.post(
          requestId: 'extra',
          sale: true,
          partyId: 'party',
          lines: const [
            InvoiceLine(
              productId: 'service',
              name: 'Service',
              unit: 'حبة',
              quantity: 1000,
              price: 100,
            ),
          ],
          payments: [],
        );
        final after = d.reports.page('sales', day, day, pageSize: 3);
        expect(after.total, 15);
        expect(after.report.summary, isNot(before.report.summary));
        for (var i = 0; i < 8; i++) {
          d.catalog.save(Product(id: 'low$i', name: 'Low$i', minStock: 1000));
        }
        final alerts = d.overview.stockAlerts();
        expect(alerts.items.length, 4);
        expect(alerts.total, 8);
      } finally {
        d.backups.dispose();
        d.store.dispose();
        d.store.database.close();
      }
    },
  );
}
