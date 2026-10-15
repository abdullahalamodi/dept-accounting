import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../catalog/data/product.dart';
import '../data/document.dart';

class InvoiceItemInput {
  InvoiceItemInput({
    required this.productId,
    required this.unit,
    this.quantity = '1',
    this.price = '0',
    this.discount = '0',
    this.description = '',
  });
  final String productId;
  String unit, quantity, price, discount, description;
  Map<String, dynamic> toMap() => {
    'productId': productId,
    'unit': unit,
    'quantity': quantity,
    'price': price,
    'discount': discount,
    'description': description,
  };
  factory InvoiceItemInput.fromMap(Map<String, dynamic> m) => InvoiceItemInput(
    productId: m['productId'] as String,
    unit: m['unit'] as String,
    quantity: m['quantity'] as String,
    price: m['price'] as String,
    discount: m['discount'] as String,
    description: m['description'] as String? ?? '',
  );
}

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
  }
  final AppDependencies d;
  final bool sale, quick;
  final String? receiptId;
  final String id;
  final lines = <InvoiceItemInput>[];
  final payments = <PaymentInput>[];
  String? partyId, correctionOf;
  String discount = '0',
      shipping = '0',
      notes = '',
      date = DateTime.now().toIso8601String().substring(0, 10);
  bool _posted = false;
  String? draftError;
  List<Product> get products =>
      d.catalog.all().where((p) => p.active && (sale || !p.service)).toList();
  bool addBarcode(String barcode) => perform(() {
    final product = products
        .where((p) => p.barcode == barcode.trim() && p.barcode.isNotEmpty)
        .firstOrNull;
    if (product == null) {
      throw const BusinessException(
        'الباركود غير موجود. ابحث عن الصنف أو أضفه أولًا.',
      );
    }
    final existing = lines
        .where(
          (l) =>
              l.productId == product.id &&
              l.unit == product.unit &&
              l.discount == '0',
        )
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

  void changeUnit(InvoiceItemInput line, String unit) {
    final p = d.catalog.get(line.productId);
    line.unit = unit;
    line.price = Numbers.input(
      Numbers.ratio(
        sale ? p.salePrice : p.purchasePrice,
        unit == p.unit ? 1000 : p.factor,
        1000,
      ),
    );
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
          price: Numbers.parse(l.price),
          discount: Numbers.parse(l.discount),
          factor: l.unit == p.unit ? 1000 : p.factor,
          service: p.service,
          description: l.description,
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
          Numbers.parse(discount) +
          (sale ? 0 : Numbers.parse(shipping));
    } catch (_) {
      return 0;
    }
  }

  int get paid {
    try {
      return payments.fold<int>(0, (n, p) => n + Numbers.parse(p.amount));
    } catch (_) {
      return 0;
    }
  }

  void edit() {
    changed();
    saveDraft(silent: true);
  }

  Map<String, dynamic> get draft => {
    'lines': lines.map((l) => l.toMap()).toList(),
    'payments': payments.map((p) => p.toMap()).toList(),
    'partyId': partyId,
    'discount': discount,
    'shipping': shipping,
    'notes': notes,
    'date': date,
    'receiptId': receiptId,
    'correctionOf': correctionOf,
  };
  void saveDraft({bool silent = false}) {
    if (_posted || lines.isEmpty || d.store.user == null) return;
    try {
      d.invoices.saveDraft(
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
      );
      draftError = null;
    } catch (e) {
      draftError = errorMessage(e);
    }
  }

  Future<Document?> post() async {
    Document? result;
    await run(() async {
      if (quick) {
        if (partyId == null) throw const BusinessException('اختر المورد.');
        result = d.receiving.receive(
          requestId: id,
          partyId: partyId!,
          lines: buildLines(),
          notes: notes,
        );
      } else if (receiptId != null) {
        result = d.receiving.finalize(
          requestId: id,
          receiptId: receiptId!,
          actualPrices: lines.map((l) => Numbers.parse(l.price)).toList(),
          payments: payments
              .map(
                (p) => Payment(
                  account: p.account,
                  amount: Numbers.parse(p.amount),
                ),
              )
              .toList(),
          shipping: Numbers.parse(shipping),
          date: date,
          notes: notes,
        );
      } else {
        result = d.invoices.post(
          requestId: id,
          sale: sale,
          lines: buildLines(),
          payments: [
            for (final p in payments)
              Payment(account: p.account, amount: Numbers.parse(p.amount)),
          ],
          partyId: partyId,
          discount: Numbers.parse(discount),
          shipping: sale ? 0 : Numbers.parse(shipping),
          notes: notes,
          date: date,
          correctionOf: correctionOf,
        );
      }
      d.invoices.deleteDraft(id);
      _posted = true;
    });
    return result;
  }

  @override
  void dispose() {
    saveDraft(silent: true);
    super.dispose();
  }
}
