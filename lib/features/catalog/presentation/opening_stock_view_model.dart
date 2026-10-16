import '../data/catalog_tasks.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/catalog_repository.dart';
import '../data/product.dart';

class OpeningStockViewModel extends ActionViewModel {
  OpeningStockViewModel(this.repository, this.productId);

  final CatalogRepository repository;
  final String productId;
  String quantity = '';

  Product get product => repository.get(productId);
  String? get unavailableReason =>
      repository.openingUnavailableReason(productId);

  int? get total {
    try {
      final count = Numbers.parse(quantity, decimals: 3);
      if (count <= 0 || (!product.fractional && count % 1000 != 0)) return null;
      return Numbers.ratio(product.purchasePrice, count, 1000);
    } on BusinessException {
      return null;
    }
  }

  void setQuantity(String value) {
    quantity = value;
    changed();
  }

  Future<bool> post() => run(
    () async => await repository.store.run(
      CatalogTasks.opening(productId, Numbers.parse(quantity, decimals: 3)),
    ),
  );
}
