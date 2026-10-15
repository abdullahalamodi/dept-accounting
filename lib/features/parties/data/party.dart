import 'package:dart_mappable/dart_mappable.dart';
part 'party.mapper.dart';

@MappableClass()
class Party with PartyMappable {
  const Party({
    required this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.customer = true,
    this.supplier = false,
    this.active = true,
  });
  final String id;
  final String name;
  final String phone;
  final String address;
  final bool customer;
  final bool supplier;
  final bool active;
}
