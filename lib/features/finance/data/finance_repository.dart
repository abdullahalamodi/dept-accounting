import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../invoices/data/document.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../parties/data/party_repository.dart';

typedef CashAccount = ({String code, String name, int balance});
typedef OpeningBalance = ({String code, String name, int amount});

class FinanceRepository {
  FinanceRepository(this.store, this.engine, this.invoices, this.parties);
  final AppStore store;
  final PostingEngine engine;
  final InvoiceRepository invoices;
  final PartyRepository parties;
  List<({String code, String name})> accountOptions() {
    store.require();
    return store.database.handle
        .select('SELECT code,name FROM accounts WHERE cash=1 ORDER BY code')
        .map((r) => (code: r['code'] as String, name: r['name'] as String))
        .toList();
  }

  List<CashAccount> accounts() {
    store.require();
    return store.database.handle
        .select(
          '''SELECT a.code,a.name,COALESCE(SUM(j.debit-j.credit),0) AS balance
          FROM accounts a LEFT JOIN journal j ON j.account = a.code
          WHERE a.cash = 1 GROUP BY a.code ORDER BY a.code''',
        )
        .map(
          (r) => (
            code: r['code'] as String,
            name: r['name'] as String,
            balance: r['balance'] as int,
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
    if (amount <= 0) {
      throw const BusinessException('أدخل رصيدًا افتتاحيًا موجبًا.');
    }
    store.write(() {
      _requireOpeningEditable(code);
      if (_openingDocument(code) != null) {
        throw const BusinessException(
          'للحساب رصيد افتتاحي؛ عدّله من نموذج الافتتاح.',
        );
      }
      _postOpening(code, amount);
    });
  }

  List<OpeningBalance> openingBalances() {
    store.require(manage: true);
    return [
      for (final account in accounts())
        if (_openingDocument(account.code) case final Document opening)
          (code: account.code, name: account.name, amount: opening.total),
    ];
  }

  Document? _openingDocument(String code) {
    final rows = store.database.handle.select(
      '''
      SELECT d.data FROM documents d JOIN journal j ON j.document_id = d.id
      WHERE d.kind = 'opening' AND j.account = ?
      AND NOT EXISTS (SELECT 1 FROM documents r WHERE r.source_id = d.id AND r.kind = 'reversal')
    ''',
      [code],
    );
    return rows.isEmpty
        ? null
        : DocumentMapper.fromJson(rows.first['data'] as String);
  }

  bool canEditOpening(String code) {
    store.require(manage: true);
    return store.setting('opening_closed') != 'true' &&
        store.database.handle
            .select(
              '''
          SELECT d.id FROM documents d
          WHERE (EXISTS (SELECT 1 FROM journal j WHERE j.document_id = d.id AND j.account = ?)
            AND d.kind != 'opening'
            AND NOT (d.kind = 'reversal' AND EXISTS (
              SELECT 1 FROM documents original WHERE original.id = d.source_id AND original.kind = 'opening')))
          OR (d.kind = 'cash_reconciliation' AND json_extract(d.data, '\$.extra.account') = ?)
          LIMIT 1
        ''',
              [code, code],
            )
            .isEmpty;
  }

  void _requireOpeningEditable(String code) {
    engine.requireCash(code);
    if (store.setting('opening_closed') == 'true') {
      throw const BusinessException('تم إقفال الافتتاح؛ استخدم تسوية موثقة.');
    }
    if (!canEditOpening(code)) {
      throw const BusinessException(
        'بدأت حركة الحساب؛ استخدم إضافة رأس مال أو تسوية.',
      );
    }
  }

  void _postOpening(String code, int amount) {
    final doc = engine.create(
      id: store.id(),
      kind: 'opening',
      total: amount,
      notes: 'افتتاح حساب نقدي',
    );
    engine.insert(doc, [debit(code, amount), credit('3900', amount)]);
  }

  void _reverseOpening(String code, Document original, String reason) {
    final reversal = engine.create(
      id: store.id(),
      kind: 'reversal',
      sourceId: original.id,
      total: original.total,
      reason: reason,
      notes: '$reason — ${original.number}',
    );
    engine.insert(reversal, [
      credit(code, original.total),
      debit('3900', original.total),
    ]);
  }

  void setOpening(String code, int amount) {
    store.require(manage: true);
    if (amount <= 0) {
      throw const BusinessException('أدخل رصيدًا افتتاحيًا موجبًا.');
    }
    store.write(() {
      _requireOpeningEditable(code);
      final original = _openingDocument(code);
      if (original?.total == amount) return;
      if (original != null) {
        _reverseOpening(code, original, 'تعديل رصيد البداية');
      }
      _postOpening(code, amount);
    });
  }

  void removeOpening(String code) {
    store.require(manage: true);
    store.write(() {
      _requireOpeningEditable(code);
      final original = _openingDocument(code);
      if (original == null) {
        throw const BusinessException('لا يوجد رصيد افتتاحي لهذا الحساب.');
      }
      _reverseOpening(code, original, 'إزالة رصيد البداية');
    });
  }

  String get _documentsWhere {
    store.require();
    final kinds = store.user!.canManage
        ? "'receipt','payment','expense','transfer','capital','drawing','opening','customer_refund','supplier_refund','cash_reconciliation','opening_close'"
        : "'receipt'";
    return "kind IN ($kinds) ${store.user!.canManage ? "OR (kind = 'reversal' AND source_id IN (SELECT id FROM documents WHERE kind = 'opening'))" : ''}";
  }

  QueryPage<Document> documentPage({int page = 1, int pageSize = 10}) {
    store.require();
    return QueryPage.read(
      total:
          store.database.handle
                  .select(
                    'SELECT COUNT(*) AS n FROM documents WHERE $_documentsWhere',
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => documents(limit: limit, offset: offset),
    );
  }

  List<Document> documents({int? limit, int offset = 0}) {
    store.require();
    return store.database.handle
        .select(
          'SELECT data FROM documents WHERE $_documentsWhere ORDER BY rowid DESC ${limit == null ? '' : 'LIMIT ? OFFSET ?'}',
          [
            if (limit != null) ...[limit, offset],
          ],
        )
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
  }

  Map<String, int> allocationPreview(
    String partyId,
    bool customer,
    int amount,
  ) => invoices.allocationPreview(partyId, customer, amount);

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
