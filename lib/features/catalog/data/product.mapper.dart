// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'product.dart';

class ProductMapper extends ClassMapperBase<Product> {
  ProductMapper._();

  static ProductMapper? _instance;
  static ProductMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ProductMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Product';

  static String _$id(Product v) => v.id;
  static const Field<Product, String> _f$id = Field('id', _$id);
  static String _$name(Product v) => v.name;
  static const Field<Product, String> _f$name = Field('name', _$name);
  static String _$barcode(Product v) => v.barcode;
  static const Field<Product, String> _f$barcode = Field(
    'barcode',
    _$barcode,
    opt: true,
    def: '',
  );
  static String _$category(Product v) => v.category;
  static const Field<Product, String> _f$category = Field(
    'category',
    _$category,
    opt: true,
    def: '',
  );
  static String _$unit(Product v) => v.unit;
  static const Field<Product, String> _f$unit = Field(
    'unit',
    _$unit,
    opt: true,
    def: 'حبة',
  );
  static String _$alternateUnit(Product v) => v.alternateUnit;
  static const Field<Product, String> _f$alternateUnit = Field(
    'alternateUnit',
    _$alternateUnit,
    opt: true,
    def: '',
  );
  static int _$factor(Product v) => v.factor;
  static const Field<Product, int> _f$factor = Field(
    'factor',
    _$factor,
    opt: true,
    def: 1000,
  );
  static bool _$fractional(Product v) => v.fractional;
  static const Field<Product, bool> _f$fractional = Field(
    'fractional',
    _$fractional,
    opt: true,
    def: false,
  );
  static bool _$service(Product v) => v.service;
  static const Field<Product, bool> _f$service = Field(
    'service',
    _$service,
    opt: true,
    def: false,
  );
  static int _$salePrice(Product v) => v.salePrice;
  static const Field<Product, int> _f$salePrice = Field(
    'salePrice',
    _$salePrice,
    opt: true,
    def: 0,
  );
  static int _$purchasePrice(Product v) => v.purchasePrice;
  static const Field<Product, int> _f$purchasePrice = Field(
    'purchasePrice',
    _$purchasePrice,
    opt: true,
    def: 0,
  );
  static int _$minStock(Product v) => v.minStock;
  static const Field<Product, int> _f$minStock = Field(
    'minStock',
    _$minStock,
    opt: true,
    def: 0,
  );
  static bool _$active(Product v) => v.active;
  static const Field<Product, bool> _f$active = Field(
    'active',
    _$active,
    opt: true,
    def: true,
  );

  @override
  final MappableFields<Product> fields = const {
    #id: _f$id,
    #name: _f$name,
    #barcode: _f$barcode,
    #category: _f$category,
    #unit: _f$unit,
    #alternateUnit: _f$alternateUnit,
    #factor: _f$factor,
    #fractional: _f$fractional,
    #service: _f$service,
    #salePrice: _f$salePrice,
    #purchasePrice: _f$purchasePrice,
    #minStock: _f$minStock,
    #active: _f$active,
  };

  static Product _instantiate(DecodingData data) {
    return Product(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      barcode: data.dec(_f$barcode),
      category: data.dec(_f$category),
      unit: data.dec(_f$unit),
      alternateUnit: data.dec(_f$alternateUnit),
      factor: data.dec(_f$factor),
      fractional: data.dec(_f$fractional),
      service: data.dec(_f$service),
      salePrice: data.dec(_f$salePrice),
      purchasePrice: data.dec(_f$purchasePrice),
      minStock: data.dec(_f$minStock),
      active: data.dec(_f$active),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Product fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Product>(map);
  }

  static Product fromJson(String json) {
    return ensureInitialized().decodeJson<Product>(json);
  }
}

mixin ProductMappable {
  String toJson() {
    return ProductMapper.ensureInitialized().encodeJson<Product>(
      this as Product,
    );
  }

  Map<String, dynamic> toMap() {
    return ProductMapper.ensureInitialized().encodeMap<Product>(
      this as Product,
    );
  }

  ProductCopyWith<Product, Product, Product> get copyWith =>
      _ProductCopyWithImpl<Product, Product>(
        this as Product,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return ProductMapper.ensureInitialized().stringifyValue(this as Product);
  }

  @override
  bool operator ==(Object other) {
    return ProductMapper.ensureInitialized().equalsValue(
      this as Product,
      other,
    );
  }

  @override
  int get hashCode {
    return ProductMapper.ensureInitialized().hashValue(this as Product);
  }
}

extension ProductValueCopy<$R, $Out> on ObjectCopyWith<$R, Product, $Out> {
  ProductCopyWith<$R, Product, $Out> get $asProduct =>
      $base.as((v, t, t2) => _ProductCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ProductCopyWith<$R, $In extends Product, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? name,
    String? barcode,
    String? category,
    String? unit,
    String? alternateUnit,
    int? factor,
    bool? fractional,
    bool? service,
    int? salePrice,
    int? purchasePrice,
    int? minStock,
    bool? active,
  });
  ProductCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ProductCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Product, $Out>
    implements ProductCopyWith<$R, Product, $Out> {
  _ProductCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Product> $mapper =
      ProductMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? name,
    String? barcode,
    String? category,
    String? unit,
    String? alternateUnit,
    int? factor,
    bool? fractional,
    bool? service,
    int? salePrice,
    int? purchasePrice,
    int? minStock,
    bool? active,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (barcode != null) #barcode: barcode,
      if (category != null) #category: category,
      if (unit != null) #unit: unit,
      if (alternateUnit != null) #alternateUnit: alternateUnit,
      if (factor != null) #factor: factor,
      if (fractional != null) #fractional: fractional,
      if (service != null) #service: service,
      if (salePrice != null) #salePrice: salePrice,
      if (purchasePrice != null) #purchasePrice: purchasePrice,
      if (minStock != null) #minStock: minStock,
      if (active != null) #active: active,
    }),
  );
  @override
  Product $make(CopyWithData data) => Product(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    barcode: data.get(#barcode, or: $value.barcode),
    category: data.get(#category, or: $value.category),
    unit: data.get(#unit, or: $value.unit),
    alternateUnit: data.get(#alternateUnit, or: $value.alternateUnit),
    factor: data.get(#factor, or: $value.factor),
    fractional: data.get(#fractional, or: $value.fractional),
    service: data.get(#service, or: $value.service),
    salePrice: data.get(#salePrice, or: $value.salePrice),
    purchasePrice: data.get(#purchasePrice, or: $value.purchasePrice),
    minStock: data.get(#minStock, or: $value.minStock),
    active: data.get(#active, or: $value.active),
  );

  @override
  ProductCopyWith<$R2, Product, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ProductCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

