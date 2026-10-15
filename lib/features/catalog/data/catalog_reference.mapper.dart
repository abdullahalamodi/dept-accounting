// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'catalog_reference.dart';

class CatalogReferenceMapper extends ClassMapperBase<CatalogReference> {
  CatalogReferenceMapper._();

  static CatalogReferenceMapper? _instance;
  static CatalogReferenceMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = CatalogReferenceMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'CatalogReference';

  static String _$id(CatalogReference v) => v.id;
  static const Field<CatalogReference, String> _f$id = Field('id', _$id);
  static String _$name(CatalogReference v) => v.name;
  static const Field<CatalogReference, String> _f$name = Field('name', _$name);
  static bool _$active(CatalogReference v) => v.active;
  static const Field<CatalogReference, bool> _f$active = Field(
    'active',
    _$active,
    opt: true,
    def: true,
  );
  static int _$productCount(CatalogReference v) => v.productCount;
  static const Field<CatalogReference, int> _f$productCount = Field(
    'productCount',
    _$productCount,
    opt: true,
    def: 0,
  );

  @override
  final MappableFields<CatalogReference> fields = const {
    #id: _f$id,
    #name: _f$name,
    #active: _f$active,
    #productCount: _f$productCount,
  };

  static CatalogReference _instantiate(DecodingData data) {
    return CatalogReference(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      active: data.dec(_f$active),
      productCount: data.dec(_f$productCount),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static CatalogReference fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<CatalogReference>(map);
  }

  static CatalogReference fromJson(String json) {
    return ensureInitialized().decodeJson<CatalogReference>(json);
  }
}

mixin CatalogReferenceMappable {
  String toJson() {
    return CatalogReferenceMapper.ensureInitialized()
        .encodeJson<CatalogReference>(this as CatalogReference);
  }

  Map<String, dynamic> toMap() {
    return CatalogReferenceMapper.ensureInitialized()
        .encodeMap<CatalogReference>(this as CatalogReference);
  }

  CatalogReferenceCopyWith<CatalogReference, CatalogReference, CatalogReference>
  get copyWith =>
      _CatalogReferenceCopyWithImpl<CatalogReference, CatalogReference>(
        this as CatalogReference,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return CatalogReferenceMapper.ensureInitialized().stringifyValue(
      this as CatalogReference,
    );
  }

  @override
  bool operator ==(Object other) {
    return CatalogReferenceMapper.ensureInitialized().equalsValue(
      this as CatalogReference,
      other,
    );
  }

  @override
  int get hashCode {
    return CatalogReferenceMapper.ensureInitialized().hashValue(
      this as CatalogReference,
    );
  }
}

extension CatalogReferenceValueCopy<$R, $Out>
    on ObjectCopyWith<$R, CatalogReference, $Out> {
  CatalogReferenceCopyWith<$R, CatalogReference, $Out>
  get $asCatalogReference =>
      $base.as((v, t, t2) => _CatalogReferenceCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class CatalogReferenceCopyWith<$R, $In extends CatalogReference, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? id, String? name, bool? active, int? productCount});
  CatalogReferenceCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _CatalogReferenceCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, CatalogReference, $Out>
    implements CatalogReferenceCopyWith<$R, CatalogReference, $Out> {
  _CatalogReferenceCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<CatalogReference> $mapper =
      CatalogReferenceMapper.ensureInitialized();
  @override
  $R call({String? id, String? name, bool? active, int? productCount}) =>
      $apply(
        FieldCopyWithData({
          if (id != null) #id: id,
          if (name != null) #name: name,
          if (active != null) #active: active,
          if (productCount != null) #productCount: productCount,
        }),
      );
  @override
  CatalogReference $make(CopyWithData data) => CatalogReference(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    active: data.get(#active, or: $value.active),
    productCount: data.get(#productCount, or: $value.productCount),
  );

  @override
  CatalogReferenceCopyWith<$R2, CatalogReference, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _CatalogReferenceCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

