import '../../../core/ui/form_widgets.dart';
import '../../../core/numbers.dart';
import '../data/catalog_repository.dart';
import '../data/product.dart';

class CatalogViewModel extends ActionViewModel {
  CatalogViewModel(this.repository);
  final CatalogRepository repository;
  String search = '', category = '';
  bool lowOnly = false, servicesOnly = false;
  int page = 1, pageSize = 10;
  List<Product> get products => repository.all();
  List<Product> get filtered => products
      .where(
        (p) =>
            ('${p.name} ${p.barcode}'.toLowerCase().contains(
              search.toLowerCase(),
            )) &&
            (category.isEmpty || p.category == category) &&
            (!servicesOnly || p.service) &&
            (!lowOnly ||
                (p.active &&
                    !p.service &&
                    repository.engine.stock(p.id).quantity <= p.minStock)),
      )
      .toList();
  List<Product> get visible {
    final items = filtered;
    return items.skip((page - 1) * pageSize).take(pageSize).toList();
  }

  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }

  void go(int value) {
    page = value;
    changed();
  }

  bool save({
    required String id,
    required Map<String, String> values,
    required bool service,
    required bool fractional,
    required bool active,
  }) => perform(
    () => repository.save(
      Product(
        id: id,
        name: values['name']!.trim(),
        barcode: values['barcode']!.trim(),
        category: values['category']!.trim(),
        unit: values['unit']!.trim(),
        alternateUnit: service ? '' : values['alternateUnit']!.trim(),
        factor: service || values['alternateUnit']!.trim().isEmpty
            ? 1000
            : Numbers.parse(values['factor']!, decimals: 3),
        fractional: fractional,
        service: service,
        salePrice: Numbers.parse(values['salePrice']!),
        purchasePrice: Numbers.parse(values['purchasePrice']!),
        minStock: Numbers.parse(values['minStock']!, decimals: 3),
        active: active,
      ),
    ),
  );
  bool opening(String id, String quantity, String cost) => perform(
    () => repository.opening(
      id,
      Numbers.parse(quantity, decimals: 3),
      Numbers.parse(cost, decimals: 6),
    ),
  );
}
