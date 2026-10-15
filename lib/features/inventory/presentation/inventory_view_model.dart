import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../reports/data/export_service.dart';

class InventoryViewModel extends ActionViewModel {
  InventoryViewModel(this.d, this.productId) : requestId = d.store.id();
  final AppDependencies d;
  final String productId;
  String requestId;
  ReportTable get report {
    final p = d.catalog.get(productId),
        moves = d.inventory.movements(productId);
    return ReportTable(
      title: 'حركة ${p.name}',
      subtitle: 'من بداية التشغيل · ${p.unit} · ${d.store.shop!.currencyLabel}',
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
  }

  Future<bool> export({bool pdf = true}) => run(() async {
    if (pdf) {
      await d.exports.savePdf(d.store.shop!, report);
    } else {
      await d.exports.saveExcel(d.store.shop!, report);
    }
  });
  bool adjust(String counted, String cost, String reason, bool damaged) =>
      perform(() {
        d.inventory.adjust(
          requestId: requestId,
          productId: productId,
          counted: Numbers.parse(counted, decimals: 3),
          extraUnitCost: cost.trim().isEmpty
              ? null
              : Numbers.parse(cost, decimals: 6),
          reason: reason,
          damaged: damaged,
        );
        requestId = d.store.id();
      });
}
