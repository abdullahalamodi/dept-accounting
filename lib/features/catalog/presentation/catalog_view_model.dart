import '../data/catalog_tasks.dart';
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

  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }

  void go(int value) {
    page = value;
    changed();
  }

  Future<bool> save({
    required String id,
    required Map<String, String> values,
    required bool service,
    required bool fractional,
    required bool active,
  }) => run(
    () async => await repository.store.run(
      CatalogTasks.save(
        Product(
          id: id,
          name: values['name']!.trim(),
          barcode: values['barcode']!.trim(),
          categoryId: values['category']!.trim(),
          unitId: values['unit']!.trim(),
          alternateUnitId: service ? '' : values['alternateUnit']!.trim(),
          factor: service || values['alternateUnit']!.trim().isEmpty
              ? 1000
              : Numbers.parse(values['factor']!, decimals: 3),
          fractional: fractional,
          service: service,
          salePrice: Numbers.parse(values['salePrice']!, emptyAsZero: true),
          purchasePrice: Numbers.parse(
            values['purchasePrice']!,
            emptyAsZero: true,
          ),
          minStock: Numbers.parse(
            values['minStock']!,
            decimals: 3,
            emptyAsZero: true,
          ),
          active: active,
        ),
      ),
    ),
  );
}
