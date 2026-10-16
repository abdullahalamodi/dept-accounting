import 'package:dept_accounting/core/data/local_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Fresh database uses indexes for growing history lookups', () {
    final database = LocalDatabase.memory();
    addTearDown(database.close);
    final db = database.handle;
    for (final query in [
      "SELECT id FROM documents WHERE source_id = 'invoice' AND kind = 'reversal'",
      "SELECT id FROM documents WHERE kind = 'sale' ORDER BY posted_at DESC LIMIT 5",
      "SELECT id FROM documents WHERE kind = 'sale' ORDER BY rowid DESC LIMIT 10",
      "SELECT id FROM documents WHERE posted_at >= '2026-01-01' AND posted_at < '2026-02-01'",
      "SELECT SUM(amount) FROM allocations WHERE payment_id = 'payment'",
      "SELECT quantity FROM stock_moves WHERE product_id = 'product'",
      "SELECT data FROM products WHERE barcode = '123'",
      "SELECT id FROM drafts WHERE user_id = 'owner' AND kind = 'sale' ORDER BY updated_at DESC,id DESC LIMIT 5",
      "SELECT SUM(amount) FROM cost_adjustments WHERE invoice_id = 'invoice' AND product_id = 'product'",
    ]) {
      final plan = db
          .select('EXPLAIN QUERY PLAN $query')
          .map((row) => row['detail'])
          .join('\n');
      expect(plan, contains('SEARCH'), reason: '$query\n$plan');
      expect(plan, isNot(contains('SCAN')), reason: '$query\n$plan');
      expect(plan, isNot(contains('TEMP B-TREE')), reason: '$query\n$plan');
    }
  });
}
