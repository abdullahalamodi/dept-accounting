import '../../../core/numbers.dart';
import '../../reports/data/export_service.dart';
import '../../../core/data/query_page.dart';
import '../../invoices/data/document.dart';
import '../../../core/data/database_task.dart';

typedef InventorySnapshot = ({
  QueryPage<Map<String, Object?>> movements,
  ({int quantity, int value, int unitCost}) stock,
});

abstract final class InventoryTasks {
  static DatabaseTask<Document> adjust({
    required String requestId,
    required String productId,
    required int counted,
    required String reason,
    int? extraUnitCost,
    bool damaged = false,
  }) => DatabaseTask(
    'inventory.adjust',
    (context) => context.inventory.adjust(
      requestId: requestId,
      productId: productId,
      counted: counted,
      reason: reason,
      extraUnitCost: extraUnitCost,
      damaged: damaged,
    ),
  );

  static DatabaseTask<InventorySnapshot> snapshot(String id, int page) =>
      DatabaseTask(
        'inventory.snapshot',
        (data) => (
          movements: data.inventory.movementPage(id, page: page),
          stock: data.engine.stock(id),
        ),
      );
  static DatabaseTask<ReportTable> report(String id) => DatabaseTask(
    'inventory.report',
    (data) {
      final p = data.catalog.get(id), moves = data.inventory.movements(id);
      return ReportTable(
        title: 'حركة ${p.name}',
        subtitle:
            'من بداية التشغيل · ${p.unit} · ${data.store.shop!.currencyLabel}',
        columns: ['التاريخ', 'المرجع', 'الكمية', 'القيمة', 'البيان'],
        rows: [
          for (final m in moves)
            [
              (m['posted_at'] as String).substring(0, 10),
              m['number'] as String,
              Numbers.format(m['quantity'] as int, decimals: 3),
              Numbers.format(m['value'] as int),
              m['note'] as String,
            ],
        ],
      );
    },
  );
}
