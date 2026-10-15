// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'document.dart';

class InvoiceLineMapper extends ClassMapperBase<InvoiceLine> {
  InvoiceLineMapper._();

  static InvoiceLineMapper? _instance;
  static InvoiceLineMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = InvoiceLineMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'InvoiceLine';

  static String _$productId(InvoiceLine v) => v.productId;
  static const Field<InvoiceLine, String> _f$productId = Field(
    'productId',
    _$productId,
  );
  static String _$name(InvoiceLine v) => v.name;
  static const Field<InvoiceLine, String> _f$name = Field('name', _$name);
  static String _$unit(InvoiceLine v) => v.unit;
  static const Field<InvoiceLine, String> _f$unit = Field('unit', _$unit);
  static int _$quantity(InvoiceLine v) => v.quantity;
  static const Field<InvoiceLine, int> _f$quantity = Field(
    'quantity',
    _$quantity,
  );
  static int _$price(InvoiceLine v) => v.price;
  static const Field<InvoiceLine, int> _f$price = Field('price', _$price);
  static int _$factor(InvoiceLine v) => v.factor;
  static const Field<InvoiceLine, int> _f$factor = Field(
    'factor',
    _$factor,
    opt: true,
    def: 1000,
  );
  static int _$discount(InvoiceLine v) => v.discount;
  static const Field<InvoiceLine, int> _f$discount = Field(
    'discount',
    _$discount,
    opt: true,
    def: 0,
  );
  static bool _$service(InvoiceLine v) => v.service;
  static const Field<InvoiceLine, bool> _f$service = Field(
    'service',
    _$service,
    opt: true,
    def: false,
  );
  static int _$cost(InvoiceLine v) => v.cost;
  static const Field<InvoiceLine, int> _f$cost = Field(
    'cost',
    _$cost,
    opt: true,
    def: 0,
  );
  static String _$description(InvoiceLine v) => v.description;
  static const Field<InvoiceLine, String> _f$description = Field(
    'description',
    _$description,
    opt: true,
    def: '',
  );

  @override
  final MappableFields<InvoiceLine> fields = const {
    #productId: _f$productId,
    #name: _f$name,
    #unit: _f$unit,
    #quantity: _f$quantity,
    #price: _f$price,
    #factor: _f$factor,
    #discount: _f$discount,
    #service: _f$service,
    #cost: _f$cost,
    #description: _f$description,
  };

  static InvoiceLine _instantiate(DecodingData data) {
    return InvoiceLine(
      productId: data.dec(_f$productId),
      name: data.dec(_f$name),
      unit: data.dec(_f$unit),
      quantity: data.dec(_f$quantity),
      price: data.dec(_f$price),
      factor: data.dec(_f$factor),
      discount: data.dec(_f$discount),
      service: data.dec(_f$service),
      cost: data.dec(_f$cost),
      description: data.dec(_f$description),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static InvoiceLine fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<InvoiceLine>(map);
  }

  static InvoiceLine fromJson(String json) {
    return ensureInitialized().decodeJson<InvoiceLine>(json);
  }
}

mixin InvoiceLineMappable {
  String toJson() {
    return InvoiceLineMapper.ensureInitialized().encodeJson<InvoiceLine>(
      this as InvoiceLine,
    );
  }

  Map<String, dynamic> toMap() {
    return InvoiceLineMapper.ensureInitialized().encodeMap<InvoiceLine>(
      this as InvoiceLine,
    );
  }

  InvoiceLineCopyWith<InvoiceLine, InvoiceLine, InvoiceLine> get copyWith =>
      _InvoiceLineCopyWithImpl<InvoiceLine, InvoiceLine>(
        this as InvoiceLine,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return InvoiceLineMapper.ensureInitialized().stringifyValue(
      this as InvoiceLine,
    );
  }

  @override
  bool operator ==(Object other) {
    return InvoiceLineMapper.ensureInitialized().equalsValue(
      this as InvoiceLine,
      other,
    );
  }

  @override
  int get hashCode {
    return InvoiceLineMapper.ensureInitialized().hashValue(this as InvoiceLine);
  }
}

extension InvoiceLineValueCopy<$R, $Out>
    on ObjectCopyWith<$R, InvoiceLine, $Out> {
  InvoiceLineCopyWith<$R, InvoiceLine, $Out> get $asInvoiceLine =>
      $base.as((v, t, t2) => _InvoiceLineCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class InvoiceLineCopyWith<$R, $In extends InvoiceLine, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? productId,
    String? name,
    String? unit,
    int? quantity,
    int? price,
    int? factor,
    int? discount,
    bool? service,
    int? cost,
    String? description,
  });
  InvoiceLineCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _InvoiceLineCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, InvoiceLine, $Out>
    implements InvoiceLineCopyWith<$R, InvoiceLine, $Out> {
  _InvoiceLineCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<InvoiceLine> $mapper =
      InvoiceLineMapper.ensureInitialized();
  @override
  $R call({
    String? productId,
    String? name,
    String? unit,
    int? quantity,
    int? price,
    int? factor,
    int? discount,
    bool? service,
    int? cost,
    String? description,
  }) => $apply(
    FieldCopyWithData({
      if (productId != null) #productId: productId,
      if (name != null) #name: name,
      if (unit != null) #unit: unit,
      if (quantity != null) #quantity: quantity,
      if (price != null) #price: price,
      if (factor != null) #factor: factor,
      if (discount != null) #discount: discount,
      if (service != null) #service: service,
      if (cost != null) #cost: cost,
      if (description != null) #description: description,
    }),
  );
  @override
  InvoiceLine $make(CopyWithData data) => InvoiceLine(
    productId: data.get(#productId, or: $value.productId),
    name: data.get(#name, or: $value.name),
    unit: data.get(#unit, or: $value.unit),
    quantity: data.get(#quantity, or: $value.quantity),
    price: data.get(#price, or: $value.price),
    factor: data.get(#factor, or: $value.factor),
    discount: data.get(#discount, or: $value.discount),
    service: data.get(#service, or: $value.service),
    cost: data.get(#cost, or: $value.cost),
    description: data.get(#description, or: $value.description),
  );

  @override
  InvoiceLineCopyWith<$R2, InvoiceLine, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _InvoiceLineCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class PaymentMapper extends ClassMapperBase<Payment> {
  PaymentMapper._();

  static PaymentMapper? _instance;
  static PaymentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = PaymentMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'Payment';

  static String _$account(Payment v) => v.account;
  static const Field<Payment, String> _f$account = Field('account', _$account);
  static int _$amount(Payment v) => v.amount;
  static const Field<Payment, int> _f$amount = Field('amount', _$amount);

  @override
  final MappableFields<Payment> fields = const {
    #account: _f$account,
    #amount: _f$amount,
  };

  static Payment _instantiate(DecodingData data) {
    return Payment(account: data.dec(_f$account), amount: data.dec(_f$amount));
  }

  @override
  final Function instantiate = _instantiate;

  static Payment fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Payment>(map);
  }

  static Payment fromJson(String json) {
    return ensureInitialized().decodeJson<Payment>(json);
  }
}

mixin PaymentMappable {
  String toJson() {
    return PaymentMapper.ensureInitialized().encodeJson<Payment>(
      this as Payment,
    );
  }

  Map<String, dynamic> toMap() {
    return PaymentMapper.ensureInitialized().encodeMap<Payment>(
      this as Payment,
    );
  }

  PaymentCopyWith<Payment, Payment, Payment> get copyWith =>
      _PaymentCopyWithImpl<Payment, Payment>(
        this as Payment,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return PaymentMapper.ensureInitialized().stringifyValue(this as Payment);
  }

  @override
  bool operator ==(Object other) {
    return PaymentMapper.ensureInitialized().equalsValue(
      this as Payment,
      other,
    );
  }

  @override
  int get hashCode {
    return PaymentMapper.ensureInitialized().hashValue(this as Payment);
  }
}

extension PaymentValueCopy<$R, $Out> on ObjectCopyWith<$R, Payment, $Out> {
  PaymentCopyWith<$R, Payment, $Out> get $asPayment =>
      $base.as((v, t, t2) => _PaymentCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class PaymentCopyWith<$R, $In extends Payment, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({String? account, int? amount});
  PaymentCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _PaymentCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Payment, $Out>
    implements PaymentCopyWith<$R, Payment, $Out> {
  _PaymentCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Payment> $mapper =
      PaymentMapper.ensureInitialized();
  @override
  $R call({String? account, int? amount}) => $apply(
    FieldCopyWithData({
      if (account != null) #account: account,
      if (amount != null) #amount: amount,
    }),
  );
  @override
  Payment $make(CopyWithData data) => Payment(
    account: data.get(#account, or: $value.account),
    amount: data.get(#amount, or: $value.amount),
  );

  @override
  PaymentCopyWith<$R2, Payment, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t) =>
      _PaymentCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class DocumentMapper extends ClassMapperBase<Document> {
  DocumentMapper._();

  static DocumentMapper? _instance;
  static DocumentMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = DocumentMapper._());
      InvoiceLineMapper.ensureInitialized();
      PaymentMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'Document';

  static String _$id(Document v) => v.id;
  static const Field<Document, String> _f$id = Field('id', _$id);
  static String _$kind(Document v) => v.kind;
  static const Field<Document, String> _f$kind = Field('kind', _$kind);
  static String _$number(Document v) => v.number;
  static const Field<Document, String> _f$number = Field('number', _$number);
  static String _$date(Document v) => v.date;
  static const Field<Document, String> _f$date = Field('date', _$date);
  static String _$postedAt(Document v) => v.postedAt;
  static const Field<Document, String> _f$postedAt = Field(
    'postedAt',
    _$postedAt,
  );
  static String _$userId(Document v) => v.userId;
  static const Field<Document, String> _f$userId = Field('userId', _$userId);
  static String? _$partyId(Document v) => v.partyId;
  static const Field<Document, String> _f$partyId = Field(
    'partyId',
    _$partyId,
    opt: true,
  );
  static List<InvoiceLine> _$lines(Document v) => v.lines;
  static const Field<Document, List<InvoiceLine>> _f$lines = Field(
    'lines',
    _$lines,
    opt: true,
    def: const [],
  );
  static List<Payment> _$payments(Document v) => v.payments;
  static const Field<Document, List<Payment>> _f$payments = Field(
    'payments',
    _$payments,
    opt: true,
    def: const [],
  );
  static int _$discount(Document v) => v.discount;
  static const Field<Document, int> _f$discount = Field(
    'discount',
    _$discount,
    opt: true,
    def: 0,
  );
  static int _$shipping(Document v) => v.shipping;
  static const Field<Document, int> _f$shipping = Field(
    'shipping',
    _$shipping,
    opt: true,
    def: 0,
  );
  static int _$total(Document v) => v.total;
  static const Field<Document, int> _f$total = Field(
    'total',
    _$total,
    opt: true,
    def: 0,
  );
  static String _$notes(Document v) => v.notes;
  static const Field<Document, String> _f$notes = Field(
    'notes',
    _$notes,
    opt: true,
    def: '',
  );
  static String? _$sourceId(Document v) => v.sourceId;
  static const Field<Document, String> _f$sourceId = Field(
    'sourceId',
    _$sourceId,
    opt: true,
  );
  static String _$reason(Document v) => v.reason;
  static const Field<Document, String> _f$reason = Field(
    'reason',
    _$reason,
    opt: true,
    def: '',
  );
  static Map<String, dynamic> _$extra(Document v) => v.extra;
  static const Field<Document, Map<String, dynamic>> _f$extra = Field(
    'extra',
    _$extra,
    opt: true,
    def: const {},
  );

  @override
  final MappableFields<Document> fields = const {
    #id: _f$id,
    #kind: _f$kind,
    #number: _f$number,
    #date: _f$date,
    #postedAt: _f$postedAt,
    #userId: _f$userId,
    #partyId: _f$partyId,
    #lines: _f$lines,
    #payments: _f$payments,
    #discount: _f$discount,
    #shipping: _f$shipping,
    #total: _f$total,
    #notes: _f$notes,
    #sourceId: _f$sourceId,
    #reason: _f$reason,
    #extra: _f$extra,
  };

  static Document _instantiate(DecodingData data) {
    return Document(
      id: data.dec(_f$id),
      kind: data.dec(_f$kind),
      number: data.dec(_f$number),
      date: data.dec(_f$date),
      postedAt: data.dec(_f$postedAt),
      userId: data.dec(_f$userId),
      partyId: data.dec(_f$partyId),
      lines: data.dec(_f$lines),
      payments: data.dec(_f$payments),
      discount: data.dec(_f$discount),
      shipping: data.dec(_f$shipping),
      total: data.dec(_f$total),
      notes: data.dec(_f$notes),
      sourceId: data.dec(_f$sourceId),
      reason: data.dec(_f$reason),
      extra: data.dec(_f$extra),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static Document fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<Document>(map);
  }

  static Document fromJson(String json) {
    return ensureInitialized().decodeJson<Document>(json);
  }
}

mixin DocumentMappable {
  String toJson() {
    return DocumentMapper.ensureInitialized().encodeJson<Document>(
      this as Document,
    );
  }

  Map<String, dynamic> toMap() {
    return DocumentMapper.ensureInitialized().encodeMap<Document>(
      this as Document,
    );
  }

  DocumentCopyWith<Document, Document, Document> get copyWith =>
      _DocumentCopyWithImpl<Document, Document>(
        this as Document,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return DocumentMapper.ensureInitialized().stringifyValue(this as Document);
  }

  @override
  bool operator ==(Object other) {
    return DocumentMapper.ensureInitialized().equalsValue(
      this as Document,
      other,
    );
  }

  @override
  int get hashCode {
    return DocumentMapper.ensureInitialized().hashValue(this as Document);
  }
}

extension DocumentValueCopy<$R, $Out> on ObjectCopyWith<$R, Document, $Out> {
  DocumentCopyWith<$R, Document, $Out> get $asDocument =>
      $base.as((v, t, t2) => _DocumentCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class DocumentCopyWith<$R, $In extends Document, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  ListCopyWith<
    $R,
    InvoiceLine,
    InvoiceLineCopyWith<$R, InvoiceLine, InvoiceLine>
  >
  get lines;
  ListCopyWith<$R, Payment, PaymentCopyWith<$R, Payment, Payment>> get payments;
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>
  get extra;
  $R call({
    String? id,
    String? kind,
    String? number,
    String? date,
    String? postedAt,
    String? userId,
    String? partyId,
    List<InvoiceLine>? lines,
    List<Payment>? payments,
    int? discount,
    int? shipping,
    int? total,
    String? notes,
    String? sourceId,
    String? reason,
    Map<String, dynamic>? extra,
  });
  DocumentCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(Then<$Out2, $R2> t);
}

class _DocumentCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, Document, $Out>
    implements DocumentCopyWith<$R, Document, $Out> {
  _DocumentCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<Document> $mapper =
      DocumentMapper.ensureInitialized();
  @override
  ListCopyWith<
    $R,
    InvoiceLine,
    InvoiceLineCopyWith<$R, InvoiceLine, InvoiceLine>
  >
  get lines => ListCopyWith(
    $value.lines,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(lines: v),
  );
  @override
  ListCopyWith<$R, Payment, PaymentCopyWith<$R, Payment, Payment>>
  get payments => ListCopyWith(
    $value.payments,
    (v, t) => v.copyWith.$chain(t),
    (v) => call(payments: v),
  );
  @override
  MapCopyWith<$R, String, dynamic, ObjectCopyWith<$R, dynamic, dynamic>?>
  get extra => MapCopyWith(
    $value.extra,
    (v, t) => ObjectCopyWith(v, $identity, t),
    (v) => call(extra: v),
  );
  @override
  $R call({
    String? id,
    String? kind,
    String? number,
    String? date,
    String? postedAt,
    String? userId,
    Object? partyId = $none,
    List<InvoiceLine>? lines,
    List<Payment>? payments,
    int? discount,
    int? shipping,
    int? total,
    String? notes,
    Object? sourceId = $none,
    String? reason,
    Map<String, dynamic>? extra,
  }) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (kind != null) #kind: kind,
      if (number != null) #number: number,
      if (date != null) #date: date,
      if (postedAt != null) #postedAt: postedAt,
      if (userId != null) #userId: userId,
      if (partyId != $none) #partyId: partyId,
      if (lines != null) #lines: lines,
      if (payments != null) #payments: payments,
      if (discount != null) #discount: discount,
      if (shipping != null) #shipping: shipping,
      if (total != null) #total: total,
      if (notes != null) #notes: notes,
      if (sourceId != $none) #sourceId: sourceId,
      if (reason != null) #reason: reason,
      if (extra != null) #extra: extra,
    }),
  );
  @override
  Document $make(CopyWithData data) => Document(
    id: data.get(#id, or: $value.id),
    kind: data.get(#kind, or: $value.kind),
    number: data.get(#number, or: $value.number),
    date: data.get(#date, or: $value.date),
    postedAt: data.get(#postedAt, or: $value.postedAt),
    userId: data.get(#userId, or: $value.userId),
    partyId: data.get(#partyId, or: $value.partyId),
    lines: data.get(#lines, or: $value.lines),
    payments: data.get(#payments, or: $value.payments),
    discount: data.get(#discount, or: $value.discount),
    shipping: data.get(#shipping, or: $value.shipping),
    total: data.get(#total, or: $value.total),
    notes: data.get(#notes, or: $value.notes),
    sourceId: data.get(#sourceId, or: $value.sourceId),
    reason: data.get(#reason, or: $value.reason),
    extra: data.get(#extra, or: $value.extra),
  );

  @override
  DocumentCopyWith<$R2, Document, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _DocumentCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

