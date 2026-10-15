// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'auth_models.dart';

class ShopMapper extends ClassMapperBase<Shop> {
  ShopMapper._();

  static ShopMapper? _instance;
  static ShopMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = ShopMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Shop';

  static String _$name(Shop v) => v.name;
  static const Field<Shop, String> _f$name = Field('name', _$name);
  static String _$currency(Shop v) => v.currency;
  static const Field<Shop, String> _f$currency = Field('currency', _$currency);
  static String _$phone(Shop v) => v.phone;
  static const Field<Shop, String> _f$phone = Field(
    'phone',
    _$phone,
    opt: true,
    def: '',
  );
  static String _$address(Shop v) => v.address;
  static const Field<Shop, String> _f$address = Field(
    'address',
    _$address,
    opt: true,
    def: '',
  );

  @override
  final MappableFields<Shop> fields = const {
    #name: _f$name,
    #currency: _f$currency,
    #phone: _f$phone,
    #address: _f$address,
  };

  static Shop _instantiate(DecodingData data) {
    return Shop(
      name: data.dec(_f$name),
      currency: data.dec(_f$currency),
      phone: data.dec(_f$phone),
      address: data.dec(_f$address),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Shop fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Shop>(map);
  }

  static Shop fromJson(String json) {
    return ensureInitialized().decodeJson<Shop>(json);
  }
}

mixin ShopMappable {
  String toJson() {
    return ShopMapper.ensureInitialized().encodeJson<Shop>(this as Shop);
  }

  Map<String, dynamic> toMap() {
    return ShopMapper.ensureInitialized().encodeMap<Shop>(this as Shop);
  }

  ShopCopyWith<Shop, Shop, Shop> get copyWith =>
      _ShopCopyWithImpl<Shop, Shop>(this as Shop, $identity, $identity);
  @override
  String toString() {
    return ShopMapper.ensureInitialized().stringifyValue(this as Shop);
  }

  @override
  bool operator ==(Object other) {
    return ShopMapper.ensureInitialized().equalsValue(this as Shop, other);
  }

  @override
  int get hashCode {
    return ShopMapper.ensureInitialized().hashValue(this as Shop);
  }
}

extension ShopValueCopy<$R, $Out> on ObjectCopyWith<$R, Shop, $Out> {
  ShopCopyWith<$R, Shop, $Out> get $asShop =>
      $base.as((v, t, t2) => _ShopCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class ShopCopyWith<$R, $In extends Shop, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? name, String? currency, String? phone, String? address});
  ShopCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _ShopCopyWithImpl<$R, $Out> extends ClassCopyWithBase<$R, Shop, $Out>
    implements ShopCopyWith<$R, Shop, $Out> {
  _ShopCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Shop> $mapper = ShopMapper.ensureInitialized();
  @override
  $R call({String? name, String? currency, String? phone, String? address}) =>
      $apply(
        FieldCopyWithData({
          if (name != null) #name: name,
          if (currency != null) #currency: currency,
          if (phone != null) #phone: phone,
          if (address != null) #address: address,
        }),
      );
  @override
  Shop $make(CopyWithData data) => Shop(
    name: data.get(#name, or: $value.name),
    currency: data.get(#currency, or: $value.currency),
    phone: data.get(#phone, or: $value.phone),
    address: data.get(#address, or: $value.address),
  );

  @override
  ShopCopyWith<$R2, Shop, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _ShopCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class AppUserMapper extends ClassMapperBase<AppUser> {
  AppUserMapper._();

  static AppUserMapper? _instance;
  static AppUserMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AppUserMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'AppUser';

  static String _$id(AppUser v) => v.id;
  static const Field<AppUser, String> _f$id = Field('id', _$id);
  static String _$name(AppUser v) => v.name;
  static const Field<AppUser, String> _f$name = Field('name', _$name);
  static String _$username(AppUser v) => v.username;
  static const Field<AppUser, String> _f$username = Field(
    'username',
    _$username,
  );
  static String _$role(AppUser v) => v.role;
  static const Field<AppUser, String> _f$role = Field('role', _$role);
  static int _$discountLimit(AppUser v) => v.discountLimit;
  static const Field<AppUser, int> _f$discountLimit = Field(
    'discountLimit',
    _$discountLimit,
    opt: true,
    def: 0,
  );
  static bool _$canChangePrice(AppUser v) => v.canChangePrice;
  static const Field<AppUser, bool> _f$canChangePrice = Field(
    'canChangePrice',
    _$canChangePrice,
    opt: true,
    def: false,
  );
  static bool _$active(AppUser v) => v.active;
  static const Field<AppUser, bool> _f$active = Field(
    'active',
    _$active,
    opt: true,
    def: true,
  );

  @override
  final MappableFields<AppUser> fields = const {
    #id: _f$id,
    #name: _f$name,
    #username: _f$username,
    #role: _f$role,
    #discountLimit: _f$discountLimit,
    #canChangePrice: _f$canChangePrice,
    #active: _f$active,
  };

  static AppUser _instantiate(DecodingData data) {
    return AppUser(
      id: data.dec(_f$id),
      name: data.dec(_f$name),
      username: data.dec(_f$username),
      role: data.dec(_f$role),
      discountLimit: data.dec(_f$discountLimit),
      canChangePrice: data.dec(_f$canChangePrice),
      active: data.dec(_f$active),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AppUser fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AppUser>(map);
  }

  static AppUser fromJson(String json) {
    return ensureInitialized().decodeJson<AppUser>(json);
  }
}

mixin AppUserMappable {
  String toJson() {
    return AppUserMapper.ensureInitialized().encodeJson<AppUser>(
      this as AppUser,
    );
  }

  Map<String, dynamic> toMap() {
    return AppUserMapper.ensureInitialized().encodeMap<AppUser>(
      this as AppUser,
    );
  }

  AppUserCopyWith<AppUser, AppUser, AppUser> get copyWith =>
      _AppUserCopyWithImpl<AppUser, AppUser>(
        this as AppUser,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AppUserMapper.ensureInitialized().stringifyValue(this as AppUser);
  }

  @override
  bool operator ==(Object other) {
    return AppUserMapper.ensureInitialized().equalsValue(
      this as AppUser,
      other,
    );
  }

  @override
  int get hashCode {
    return AppUserMapper.ensureInitialized().hashValue(this as AppUser);
  }
}

extension AppUserValueCopy<$R, $Out> on ObjectCopyWith<$R, AppUser, $Out> {
  AppUserCopyWith<$R, AppUser, $Out> get $asAppUser =>
      $base.as((v, t, t2) => _AppUserCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AppUserCopyWith<$R, $In extends AppUser, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? id,
    String? name,
    String? username,
    String? role,
    int? discountLimit,
    bool? canChangePrice,
    bool? active,
  });
  AppUserCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _AppUserCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AppUser, $Out>
    implements AppUserCopyWith<$R, AppUser, $Out> {
  _AppUserCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AppUser> $mapper =
      AppUserMapper.ensureInitialized();
  @override
  $R call({
    String? id,
    String? name,
    String? username,
    String? role,
    int? discountLimit,
    bool? canChangePrice,
    bool? active,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (name != null) #name: name,
      if (username != null) #username: username,
      if (role != null) #role: role,
      if (discountLimit != null) #discountLimit: discountLimit,
      if (canChangePrice != null) #canChangePrice: canChangePrice,
      if (active != null) #active: active,
    }),
  );
  @override
  AppUser $make(CopyWithData data) => AppUser(
    id: data.get(#id, or: $value.id),
    name: data.get(#name, or: $value.name),
    username: data.get(#username, or: $value.username),
    role: data.get(#role, or: $value.role),
    discountLimit: data.get(#discountLimit, or: $value.discountLimit),
    canChangePrice: data.get(#canChangePrice, or: $value.canChangePrice),
    active: data.get(#active, or: $value.active),
  );

  @override
  AppUserCopyWith<$R2, AppUser, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _AppUserCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

