import '../../catalog/data/catalog_tasks.dart';

import 'dart:async';

import '../data/invoices_tasks.dart';
import '../../receiving/data/receiving_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../catalog/data/product.dart';
import '../../catalog/data/catalog_repository.dart';
import '../data/document.dart';

class InvoiceItemInput {
  InvoiceItemInput({
    required this.productId,
    required this.unit,
    this.quantity = '1',
    this.price = '0',
  });
  final String productId;
  String unit, quantity, price;
  Map<String, dynamic> toMap() => {
    'productId': productId,
    'unit': unit,
    'quantity': quantity,
    'price': price,
  };
  factory InvoiceItemInput.fromMap(Map<String, dynamic> m) => InvoiceItemInput(
    productId: m['productId'] as String,
    unit: m['unit'] as String,
    quantity: m['quantity'] as String,
    price: m['price'] as String,
  );
}

enum InvoicePaymentMode { cash, credit, partial }

class PaymentInput {
  PaymentInput({required this.account, this.amount = '0'});
  String account, amount;
  Map<String, dynamic> toMap() => {'account': account, 'amount': amount};
}

class InvoiceViewModel extends ActionViewModel {
  InvoiceViewModel(
    this.d, {
    required this.sale,
    required this.id,
    this.quick = false,
    this.receiptId,
  }) {
    final draft = d.invoices.loadDraft(id);
    if (draft != null) {
      lines.addAll(
        (draft['lines'] as List).map(
          (r) => InvoiceItemInput.fromMap(Map<String, dynamic>.from(r as Map)),
        ),
      );
      payments.addAll(
        (draft['payments'] as List).map(
          (r) => PaymentInput(
            account: r['account'] as String,
            amount: r['amount'] as String,
          ),
        ),
      );
      partyId = draft['partyId'] as String?;
      discount = draft['discount'] as String? ?? '0';
      // Older drafts and correction copies may contain line discounts.
      // Carry them into the single invoice discount without changing the total.
      final legacyDiscounts = (draft['lines'] as List).fold<int>(
        0,
        (sum, row) => sum + Numbers.parse(row['discount'] as String? ?? '0'),
      );
      if (legacyDiscounts != 0) {
        discount = Numbers.input(
          Numbers.parse(discount, emptyAsZero: true) + legacyDiscounts,
        );
      }
      paymentMode =
          InvoicePaymentMode.values
              .where((mode) => mode.name == draft['paymentMode'])
              .firstOrNull ??
          (payments.isEmpty
              ? InvoicePaymentMode.credit
              : InvoicePaymentMode.partial);
      shipping = draft['shipping'] as String? ?? '0';
      notes = draft['notes'] as String? ?? '';
      date = draft['date'] as String? ?? date;
      correctionOf = draft['correctionOf'] as String?;
    } else if (receiptId != null) {
      final receipt = d.invoices.get(receiptId!);
      partyId = receipt.partyId;
      lines.addAll(
        receipt.lines.map(
          (l) => InvoiceItemInput(
            productId: l.productId,
            unit: l.unit,
            quantity: Numbers.input(l.quantity, decimals: 3),
            price: Numbers.input(l.price),
          ),
        ),
      );
    }
    _normalizePaymentMode();
    if (paymentMode != InvoicePaymentMode.credit) _ensurePayment();
  }
  final AppDependencies d;
  final bool sale, quick;
  final String? receiptId;
  final String id;
  final lines = <InvoiceItemInput>[];
  final payments = <PaymentInput>[];
  InvoicePaymentMode paymentMode = InvoicePaymentMode.cash;
  String? partyId, correctionOf;
  String discount = '0',
      shipping = '0',
      notes = '',
      date = DateTime.now().toIso8601String();
  bool _posted = false;
  Timer? _draftTimer;
  String? draftError;
  bool get cashOnly => sale && partyId == null;

  bool canUsePaymentMode(InvoicePaymentMode mode) =>
      mode == InvoicePaymentMode.cash || !cashOnly;

  void _normalizePaymentMode() {
    if (!cashOnly || paymentMode == InvoicePaymentMode.cash) return;
    paymentMode = InvoicePaymentMode.cash;
    _ensurePayment();
    payments.removeRange(1, payments.length);
  }

  Future<QueryPage<CatalogRow>> searchProducts(String search, int page) =>
      d.store.run(
        CatalogTasks.page(
          search: search,
          page: page,
          pageSize: 5,
          activeOnly: true,
          excludeServices: !sale,
        ),
      );
  bool addBarcode(String barcode) => perform(() {
    final product = d.catalog.findBarcode(barcode);
    if (product == null || !product.active || (!sale && product.service)) {
      throw const BusinessException(
        'الباركود غير موجود. ابحث عن المنتج أو أضفه أولًا.',
      );
    }
    final existing = lines
        .where((l) => l.productId == product.id && l.unit == product.unit)
        .firstOrNull;
    if (existing == null) {
      add(product);
    } else {
      existing.quantity = Numbers.input(
        Numbers.parse(existing.quantity, decimals: 3) + 1000,
        decimals: 3,
      );
      edit();
    }
  });
  void add(Product p) {
    lines.add(
      InvoiceItemInput(
        productId: p.id,
        unit: p.unit,
        price: Numbers.input(sale ? p.salePrice : p.purchasePrice),
      ),
    );
    edit();
  }

  String priceForUnit(Product product, String unit) => Numbers.input(
    Numbers.ratio(
      sale ? product.salePrice : product.purchasePrice,
      unit == product.unit ? 1000 : product.factor,
      1000,
    ),
  );

  void changeUnit(InvoiceItemInput line, String unit) {
    final product = d.catalog.get(line.productId);
    line.unit = unit;
    line.price = priceForUnit(product, unit);
    edit();
  }

  List<InvoiceLine> buildLines() => [
    for (final l in lines)
      (() {
        final p = d.catalog.get(l.productId);
        return InvoiceLine(
          productId: p.id,
          name: p.name,
          unit: l.unit,
          quantity: Numbers.parse(l.quantity, decimals: 3),
          price: Numbers.parse(l.price, emptyAsZero: true),
          factor: l.unit == p.unit ? 1000 : p.factor,
          service: p.service,
        );
      })(),
  ];
  int get subtotal {
    try {
      return buildLines().fold<int>(0, (n, l) => n + l.total);
    } catch (_) {
      return 0;
    }
  }

  int get total {
    try {
      return subtotal -
          Numbers.parse(discount, emptyAsZero: true) +
          (sale ? 0 : Numbers.parse(shipping, emptyAsZero: true));
    } catch (_) {
      return 0;
    }
  }

  int get paid {
    if (quick || paymentMode == InvoicePaymentMode.credit) return 0;
    if (paymentMode == InvoicePaymentMode.cash) return total;
    try {
      return payments.fold<int>(0, (n, p) => n + Numbers.parse(p.amount));
    } catch (_) {
      return 0;
    }
  }

  void _ensurePayment() {
    if (payments.isEmpty) {
      payments.add(
        PaymentInput(account: d.finance.accountOptions().first.code),
      );
    }
  }

  void changePaymentMode(InvoicePaymentMode mode) {
    if (!canUsePaymentMode(mode)) return;
    if (paymentMode == mode) return;
    paymentMode = mode;
    if (mode != InvoicePaymentMode.credit) _ensurePayment();
    if (mode == InvoicePaymentMode.cash) {
      payments.removeRange(1, payments.length);
    }
    edit();
  }

  void addPayment() {
    payments.add(PaymentInput(account: d.finance.accountOptions().first.code));
    edit();
  }

  List<Payment> buildPayments() => switch (paymentMode) {
    InvoicePaymentMode.credit => [],
    InvoicePaymentMode.cash => [
      Payment(account: payments.first.account, amount: total),
    ],
    InvoicePaymentMode.partial => [
      for (final payment in payments)
        Payment(
          account: payment.account,
          amount: Numbers.parse(payment.amount),
        ),
    ],
  };

  void edit() {
    _normalizePaymentMode();
    changed();
    _draftTimer?.cancel();
    _draftTimer = Timer(
      const Duration(milliseconds: 250),
      () => saveDraft(silent: true),
    );
  }

  Map<String, dynamic> get draft => {
    'lines': lines.map((l) => l.toMap()).toList(),
    'payments': payments.map((p) => p.toMap()).toList(),
    'paymentMode': paymentMode.name,
    'partyId': partyId,
    'discount': discount,
    'shipping': shipping,
    'notes': notes,
    'date': date,
    'receiptId': receiptId,
    'correctionOf': correctionOf,
  };
  Future<void> saveDraft({bool silent = false}) async {
    _draftTimer?.cancel();
    if (busy || _posted || lines.isEmpty || d.store.user == null) return;
    try {
      await d.store.run(
        InvoiceTasks.saveDraft(
          id,
          quick
              ? 'quick_receipt'
              : receiptId != null
              ? 'receipt_invoice'
              : sale
              ? 'sale'
              : 'purchase',
          draft,
          notify: !silent,
        ),
      );
      draftError = null;
    } catch (e) {
      draftError = errorMessage(e);
    }
  }

  Future<Document?> post() async {
    Document? result;
    _draftTimer?.cancel();
    await run(() async {
      if (quick) {
        if (partyId == null) throw const BusinessException('اختر المورد.');
        result = await d.store.run(
          ReceivingTasks.receive(
            requestId: id,
            partyId: partyId!,
            lines: buildLines(),
            notes: notes,
            date: date,
          ),
        );
      } else if (receiptId != null) {
        result = await d.store.run(
          ReceivingTasks.finalize(
            requestId: id,
            receiptId: receiptId!,
            actualPrices: lines
                .map((l) => Numbers.parse(l.price, emptyAsZero: true))
                .toList(),
            payments: buildPayments(),
            shipping: Numbers.parse(shipping, emptyAsZero: true),
            date: date,
            notes: notes,
          ),
        );
      } else {
        result = await d.store.run(
          InvoiceTasks.post(
            requestId: id,
            sale: sale,
            lines: buildLines(),
            payments: buildPayments(),
            partyId: partyId,
            discount: Numbers.parse(discount, emptyAsZero: true),
            shipping: sale ? 0 : Numbers.parse(shipping, emptyAsZero: true),
            notes: notes,
            date: date,
            correctionOf: correctionOf,
          ),
        );
      }
      _posted = true;
    });
    return result;
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    unawaited(saveDraft(silent: true));
    super.dispose();
  }
}
