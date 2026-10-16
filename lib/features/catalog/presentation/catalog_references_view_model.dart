import '../data/catalog_references_tasks.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/catalog_reference.dart';
import '../data/catalog_references_repository.dart';

class CatalogReferencesViewModel extends ActionViewModel {
  CatalogReferencesViewModel(this.repository, this.kind);
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  String search = '';
  bool showInactive = false;
  int page = 1, pageSize = 10;

  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }

  Future<CatalogReference?> save({String? id, required String name}) async {
    CatalogReference? saved;
    await run(
      () async => saved = await repository.store.run(
        CatalogReferenceTasks.save(kind, id: id, name: name),
      ),
    );
    return saved;
  }

  Future<void> setActive(CatalogReference entry) async {
    if (await run(
      () async => repository.store.run(
        CatalogReferenceTasks.setActive(kind, entry.id, !entry.active),
      ),
    )) {
      page = 1;
    }
  }
}
