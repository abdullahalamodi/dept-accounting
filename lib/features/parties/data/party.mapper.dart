// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'party.dart';

class PartyMapper extends ClassMapperBase<Party> {
  PartyMapper._();

  static PartyMapper? _instance;
  static PartyMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PartyMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Party';

  static String _$id(Party v) => v.id;
  static const Field<Party, String> _f$id = Field('id', _$id);
  static String _$name(Party v) => v.name;
  static const Field<Party, String> _f$name = Field('name', _$name);
  static String _$phone(Party v) => v.phone;
  static const Field<Party, String> _f$phone = Field(
    'phone',
    _$phone,
    opt: true,
    def: '',
  );
  static String _$address(Party v) => v.address;
  static const Field<Party, String> _f$address = Field(
    'address',
    _$address,
    opt: true,
    def: '',
  );
  static bool _$customer(Party v) => v.customer;
  static const Field<Party, bool> _f$customer = Field(
    'customer',
    _$customer,
    opt: true,
    def: true,
  );
  static bool _$supplier(Party v) => v.supplier;
  static const Field<Party, bool> _f$supplier = Field(
    'supplier',
    _$supplier,
    opt: true,
    def: false,
  );
  static bool _$active(Party v) => v.active;
  static const Field<Party, bool> _f$active = Field(
    'active',
    _$active,
    opt: true,
    def: true,
  );

  @override
  final MappableFields<Party> fields = const {
    #id: _f$id,
    #name: _f$name,
    #phone: _f$phone,
    #address: _f$address,
    #customer: _f$customer,
    #supplier: _f$supplier,
    #active: _f$active,
  };

  static Party _instantiate(DecodingData data) {
    return Party(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      phone: data.dec(_f$phone),
      address: data.dec(_f$address),
      customer: data.dec(_f$customer),
      supplier: data.dec(_f$supplier),
      active: data.dec(_f$active),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Party fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Party>(map);
  }

  static Party fromJson(String json) {
    return ensureInitialized().decodeJson<Party>(json);
  }
}

mixin PartyMappable {
  String toJson() {
    return PartyMapper.ensureInitialized().encodeJson<Party>(this as Party);
  }

  Map<String, dynamic> toMap() {
    return PartyMapper.ensureInitialized().encodeMap<Party>(this as Party);
  }

  PartyCopyWith<Party, Party, Party> get copyWith =>
      _PartyCopyWithImpl<Party, Party>(this as Party, $identity, $identity);
  @override
  String toString() {
    return PartyMapper.ensureInitialized().stringifyValue(this as Party);
  }

  @override
  bool operator ==(Object other) {
    return PartyMapper.ensureInitialized().equalsValue(this as Party, other);
  }

  @override
  int get hashCode {
    return PartyMapper.ensureInitialized().hashValue(this as Party);
  }
}

extension PartyValueCopy<$R, $Out> on ObjectCopyWith<$R, Party, $Out> {
  PartyCopyWith<$R, Party, $Out> get $asParty =>
      $base.as((v, t, t2) => _PartyCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PartyCopyWith<$R, $In extends Party, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? name,
    String? phone,
    String? address,
    bool? customer,
    bool? supplier,
    bool? active,
  });
  PartyCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PartyCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Party, $Out>
    implements PartyCopyWith<$R, Party, $Out> {
  _PartyCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Party> $mapper = PartyMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? name,
    String? phone,
    String? address,
    bool? customer,
    bool? supplier,
    bool? active,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (phone != null) #phone: phone,
      if (address != null) #address: address,
      if (customer != null) #customer: customer,
      if (supplier != null) #supplier: supplier,
      if (active != null) #active: active,
    }),
  );
  @override
  Party $make(CopyWithData data) => Party(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    phone: data.get(#phone, or: $value.phone),
    address: data.get(#address, or: $value.address),
    customer: data.get(#customer, or: $value.customer),
    supplier: data.get(#supplier, or: $value.supplier),
    active: data.get(#active, or: $value.active),
  );

  @override
  PartyCopyWith<$R2, Party, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PartyCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

