import '../../../core/data/query_page.dart';
import 'catalog_reference.dart';
import '../../../core/data/database_task.dart';

abstract final class CatalogReferenceTasks {
  static DatabaseTask<CatalogReference> save(
    CatalogReferenceKind kind, {
    String? id,
    required String name,
  }) => DatabaseTask(
    'catalogReferences.save',
    (context) => context.catalogReferences.save(kind, id: id, name: name),
  );
  static DatabaseTask<void> setActive(
    CatalogReferenceKind kind,
    String id,
    bool active,
  ) => DatabaseTask(
    'catalogReferences.setActive',
    (context) => context.catalogReferences.setActive(kind, id, active),
  );
  static DatabaseTask<QueryPage<CatalogReference>> page(
    CatalogReferenceKind kind, {
    String search = '',
    bool showInactive = false,
    String excludeId = '',
    bool counts = true,
    int page = 1,
    int pageSize = 10,
  }) => DatabaseTask(
    'catalogReferences.page',
    (context) => context.catalogReferences.page(
      kind,
      search: search,
      showInactive: showInactive,
      page: page,
      pageSize: pageSize,
      counts: counts,
      excludeId: excludeId,
    ),
  );
}
