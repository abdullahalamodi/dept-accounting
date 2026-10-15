import 'package:dart_mappable/dart_mappable.dart';

part 'auth_models.mapper.dart';

@MappableClass()
class Shop with ShopMappable {
  const Shop({
    required this.name,
    required this.currency,
    this.phone = '',
    this.address = '',
  });
  final String name;
  final String currency;
  final String phone;
  final String address;
  String get currencyLabel => currency == 'SAR' ? 'ر.س' : 'ر.ي';
}

@MappableClass()
class AppUser with AppUserMappable {
  const AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.role,
    this.discountLimit = 0,
    this.canChangePrice = false,
    this.active = true,
  });
  final String id;
  final String name;
  final String username;
  final String role;
  String get displayName => name.isEmpty ? username : name;
  final int discountLimit;
  final bool canChangePrice;
  final bool active;
  bool get isOwner => role == 'owner';
  bool get canManage => role != 'seller';
  String get roleLabel => switch (role) {
    'owner' => 'المالك',
    'accountant' => 'المحاسب',
    _ => 'البائع',
  };
}
