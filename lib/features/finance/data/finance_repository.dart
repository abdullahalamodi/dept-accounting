import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../parties/data/party_repository.dart';

typedef CashAccount = ({String code, String name, int balance});

class FinanceRepository {
  FinanceRepository(this.store, this.engine, this.invoices, this.parties);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  final PartyRepository parties;
  List<CashAccount> accounts() {
    store.require();
    return store.database.handle
        .select('SELECT code,name FROM accounts WHERE cash = 1 ORDER BY code')
        .map(
          (r) => (
            code: r['code'] as String,
            name: r['name'] as String,
            balance: engine.balance(r['code'] as String),
          ),
        )
        .toList();
  }

  void addAccount(String name) {
    store.require(manage: true);
    if (name.trim().isEmpty) throw const BusinessException('اسم الحساب مطلوب.');
    store.write(() {
      final next =
          (store.database.handle
                  .select('SELECT COUNT(*) AS n FROM accounts WHERE cash = 1')
                  .first['n']
              as int) +
          1;
      store.database.handle.execute(
        "INSERT INTO accounts VALUES (?, ?, 'asset', 1)",
        ['11${next.toString().padLeft(2, '0')}', name.trim()],
      );
      store.audit('إضافة حساب نقدي', name);
    });
  }

  void openAccount(String code, int amount) {
    store.require(manage: true);
    if (store.setting('opening_closed') == 'true') {
      throw const BusinessException('تم إقفال الافتتاح؛ استخدم تسوية موثقة.');
    }
    if (amount <= 0) {
      throw const BusinessException('أدخل رصيدًا افتتاحيًا موجبًا.');
    }
    store.write(() {
      engine.requireCash(code);
      if (store.database.handle.select(
        'SELECT id FROM journal WHERE account = ? LIMIT 1',
        [code],
      ).isNotEmpty) {
        throw const BusinessException(
          'بدأت حركة الحساب؛ استخدم إضافة رأس مال أو تسوية.',
        );
      }
      final doc = engine.create(
        id: store.id(),
        kind: 'opening',
        total: amount,
        notes: 'افتتاح حساب نقدي',
      );
      engine.insert(doc, [debit(code, amount), credit('3900', amount)]);
    });
  }

  List<Document> documents() {
    store.require();
    final kinds = store.user!.canManage
        ? "'receipt','payment','expense','transfer','capital','drawing','opening','customer_refund','supplier_refund','cash_reconciliation','opening_close'"
        : "'receipt'";
    return store.database.handle
        .select(
          'SELECT data FROM documents WHERE kind IN ($kinds) ORDER BY rowid DESC',
        )
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
  }

  Map<String, int> allocationPreview(
    String partyId,
    bool customer,
    int amount,
  ) {
    final candidates =
        invoices
            .list(customer ? 'sale' : 'purchase')
            .where((d) => d.partyId == partyId)
            .toList()
          ..sort((a, b) {
            final date = a.date.compareTo(b.date);
            return date != 0 ? date : a.postedAt.compareTo(b.postedAt);
          });
    final result = <String, int>{};
    for (final d in candidates) {
      if (amount <= 0) break;
      final part = invoices.due(d.id).clamp(0, amount);
      if (part > 0) {
        result[d.id] = part;
        amount -= part;
      }
    }
    return result;
  }

  Document post({
    required String requestId,
    required String kind,
    required List<Payment> payments,
    String? partyId,
    String? toAccount,
    String notes = '',
    String category = '',
    Map<String, int> allocations = const {},
  }) {
    store.require(manage: kind != 'receipt');
    if (![
      'receipt',
      'payment',
      'expense',
      'transfer',
      'capital',
      'drawing',
    ].contains(kind)) {
      throw const BusinessException('نوع العملية غير مدعوم.');
    }
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      final total = payments.fold<int>(0, (a, p) => a + p.amount);
      if (total <= 0 || payments.any((p) => p.amount <= 0)) {
        throw const BusinessException('أدخل مبلغًا موجبًا لكل حساب.');
      }
      for (final p in payments) {
        engine.requireCash(p.account);
      }
      final receipt = kind == 'receipt',
          voucher = ['receipt', 'payment'].contains(kind);
      if (voucher) {
        if (partyId == null) throw const BusinessException('اختر الطرف.');
        final party = parties.get(partyId);
        if (!party.active || (receipt ? !party.customer : !party.supplier)) {
          throw const BusinessException('دور الطرف غير مناسب.');
        }
      }
      if (kind == 'expense' && category.trim().isEmpty) {
        throw const BusinessException('تصنيف المصروف مطلوب.');
      }
      final incoming = ['receipt', 'capital'].contains(kind);
      final journal = <JournalLine>[
        for (final p in payments)
          incoming ? debit(p.account, p.amount) : credit(p.account, p.amount),
      ];
      switch (kind) {
        case 'receipt':
          journal.add(credit('1200', total, partyId));
        case 'payment':
          journal.add(debit('2100', total, partyId));
        case 'expense':
          journal.add(debit('6100', total));
        case 'capital':
          journal.add(credit('3100', total));
        case 'drawing':
          journal.add(debit('3200', total));
        case 'transfer':
          if (toAccount == null ||
              payments.any((p) => p.account == toAccount)) {
            throw const BusinessException('اختر حساب تحويل مختلفًا.');
          }
          engine.requireCash(toAccount);
          journal.add(debit(toAccount, total));
      }
      if (allocations.values.fold<int>(0, (a, b) => a + b) > total) {
        throw const BusinessException('التخصيص يتجاوز قيمة السند.');
      }
      for (final entry in allocations.entries) {
        final invoice = invoices.get(entry.key);
        if (!voucher ||
            invoice.partyId != partyId ||
            invoice.kind != (receipt ? 'sale' : 'purchase') ||
            entry.value <= 0 ||
            entry.value > invoices.due(entry.key)) {
          throw const BusinessException(
            'تخصيص الدفعة غير صالح أو يتجاوز المتبقي.',
          );
        }
      }
      final doc = engine.create(
        id: requestId,
        kind: kind,
        total: total,
        partyId: partyId,
        payments: payments,
        notes: notes,
        extra: {'category': category, 'toAccount': toAccount},
      );
      engine.insert(doc, journal);
      for (final e in allocations.entries) {
        store.database.handle.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [doc.id, e.key, e.value],
        );
      }
      return doc;
    });
  }
}
