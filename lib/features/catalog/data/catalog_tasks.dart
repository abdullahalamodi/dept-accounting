import '../../../core/data/query_page.dart';
import 'product.dart';
import '../../../core/data/database_task.dart';
import 'catalog_repository.dart';

abstract final class CatalogTasks {
  static DatabaseTask<void> save(Product item) =>
      DatabaseTask('catalog.save', (context) => context.catalog.save(item));
  static DatabaseTask<void> opening(String id, int quantity) => DatabaseTask(
    'catalog.opening',
    (context) => context.catalog.opening(id, quantity),
  );
  static DatabaseTask<QueryPage<CatalogRow>> page({
    String search = '',
    String category = '',
    bool lowOnly = false,
    bool servicesOnly = false,
    bool activeOnly = false,
    bool excludeServices = false,
    int page = 1,
    int pageSize = 10,
  }) => DatabaseTask(
    'catalog.page',
    (context) => context.catalog.page(
      search: search,
      category: category,
      lowOnly: lowOnly,
      servicesOnly: servicesOnly,
      page: page,
      pageSize: pageSize,
      activeOnly: activeOnly,
      excludeServices: excludeServices,
    ),
  );
}
