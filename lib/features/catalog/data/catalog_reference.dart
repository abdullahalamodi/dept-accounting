import 'package:dart_mappable/dart_mappable.dart';

part 'catalog_reference.mapper.dart';

enum CatalogReferenceKind {
  unit('units', 'الوحدات', 'الوحدة', 'إضافة وحدة'),
  category('categories', 'التصنيفات', 'التصنيف', 'إضافة تصنيف');

  const CatalogReferenceKind(this.table, this.title, this.label, this.addLabel);
  final String table, title, label, addLabel;
}

@MappableClass()
class CatalogReference with CatalogReferenceMappable {
  const CatalogReference({
    required this.id,
    required this.name,
    this.active = true,
    this.productCount = 0,
  });

  final String id, name;
  final bool active;
  final int productCount;
}
