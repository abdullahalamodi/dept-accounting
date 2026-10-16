import 'package:dart_mappable/dart_mappable.dart';

import '../../../core/numbers.dart';
part 'document.mapper.dart';

@MappableClass()
class InvoiceLine with InvoiceLineMappable {
  const InvoiceLine({
    required this.productId,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.price,
    this.factor = 1000,
    this.discount = 0,
    this.service = false,
    this.cost = 0,
    this.description = '',
  });
  final String productId;
  final String name;
  final String unit;
  final int quantity;
  final int factor;
  final int price;
  final int discount;
  final bool service;
  final int cost;
  final String description;
  int get baseQuantity => Numbers.baseQuantity(quantity, factor);
  int get gross => Numbers.ratio(price, quantity, 1000);
  int get total => gross - discount;
}

@MappableClass()
class Payment with PaymentMappable {
  const Payment({required this.account, required this.amount});
  final String account;
  final int amount;
}

@MappableClass()
class Document with DocumentMappable {
  const Document({
    required this.id,
    required this.kind,
    required this.number,
    required this.date,
    required this.postedAt,
    required this.userId,
    this.partyId,
    this.lines = const [],
    this.payments = const [],
    this.discount = 0,
    this.shipping = 0,
    this.total = 0,
    this.notes = '',
    this.sourceId,
    this.reason = '',
    this.extra = const {},
  });
  final String id;
  final String kind;
  final String number;
  final String date;
  final String postedAt;
  final String userId;
  final String? partyId;
  final List<InvoiceLine> lines;
  final List<Payment> payments;
  final int discount;
  final int shipping;
  final int total;
  final String notes;
  final String? sourceId;
  final String reason;
  final Map<String, dynamic> extra;
  bool get isSale => kind == 'sale';
  int get paid => payments.fold(0, (a, b) => a + b.amount);
  String get label => labelFor(kind);
  static String labelFor(String kind) => switch (kind) {
    'sale' => 'فاتورة بيع',
    'purchase' => 'فاتورة شراء',
    'receipt' => 'سند قبض',
    'customer_refund' => 'رد رصيد عميل',
    'supplier_refund' => 'استرداد رصيد مورد',
    'party_adjustment' => 'تسوية رصيد طرف',
    'allocation' => 'تخصيص دفعة',
    'cash_reconciliation' => 'مطابقة الصندوق',
    'opening_close' => 'إقفال الافتتاح',
    'payment' => 'سند صرف',
    'expense' => 'مصروف',
    'transfer' => 'تحويل',
    'capital' => 'إضافة رأس مال',
    'drawing' => 'مسحوبات شخصية',
    'opening' => 'رصيد افتتاحي',
    'sale_return' => 'مرتجع بيع',
    'purchase_return' => 'مرتجع شراء',
    'stock_adjustment' => 'تسوية مخزون',
    'quick_receipt' => 'استلام سريع',
    'reversal' => 'إلغاء مستند',
    _ => 'تسوية',
  };
}
