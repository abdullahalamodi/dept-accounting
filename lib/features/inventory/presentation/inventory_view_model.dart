import '../data/inventory_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../reports/data/export_service.dart';

class InventoryViewModel extends ActionViewModel {
  InventoryViewModel(this.d, this.productId) : requestId = d.store.id();
  final AppDependencies d;
  final String productId;
  String requestId;
  Future<ReportTable> get report =>
      d.store.run(InventoryTasks.report(productId));

  Future<bool> export({bool pdf = true}) => run(() async {
    if (pdf) {
      await d.exports.savePdf(d.store.shop!, await report);
    } else {
      await d.exports.saveExcel(d.store.shop!, await report);
    }
  });
  Future<bool> adjust(
    String counted,
    String cost,
    String reason,
    bool damaged,
  ) => run(() async {
    await d.store.run(
      InventoryTasks.adjust(
        requestId: requestId,
        productId: productId,
        counted: Numbers.parse(counted, decimals: 3),
        extraUnitCost: cost.trim().isEmpty
            ? null
            : Numbers.parse(cost, decimals: 6),
        reason: reason,
        damaged: damaged,
      ),
    );
    requestId = d.store.id();
  });
}
