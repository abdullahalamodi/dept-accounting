import 'package:dart_mappable/dart_mappable.dart';
part 'product.mapper.dart';

@MappableClass()
class Product with ProductMappable {
  const Product({
    required this.id,
    required this.name,
    this.barcode = '',
    this.category = '',
    this.unit = 'حبة',
    this.alternateUnit = '',
    this.factor = 1000,
    this.fractional = false,
    this.service = false,
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.minStock = 0,
    this.active = true,
  });
  final String id;
  final String name;
  final String barcode;
  final String category;
  final String unit;
  final String alternateUnit;
  final int factor;
  final bool fractional;
  final bool service;
  final int salePrice;
  final int purchasePrice;
  final int minStock;
  final bool active;
}
