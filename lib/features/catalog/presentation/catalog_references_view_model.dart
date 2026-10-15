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

  List<CatalogReference> get filtered => repository
      .all(kind)
      .where(
        (r) =>
            (showInactive || r.active) &&
            r.name.toLowerCase().contains(search.trim().toLowerCase()),
      )
      .toList();
  List<CatalogReference> get visible =>
      filtered.skip((page - 1) * pageSize).take(pageSize).toList();

  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }

  CatalogReference? save({String? id, required String name}) {
    CatalogReference? saved;
    perform(() => saved = repository.save(kind, id: id, name: name));
    return saved;
  }

  void setActive(CatalogReference entry) {
    if (perform(() => repository.setActive(kind, entry.id, !entry.active))) {
      page = 1;
    }
  }
}
