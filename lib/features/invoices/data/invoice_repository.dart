import 'dart:convert';

import '../../../core/data/app_store.dart';
import '../../../core/data/query_page.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../parties/data/party_repository.dart';
import 'document.dart';
import 'invoice_summary.dart';

typedef InvoiceDraft = ({String id, String updatedAt, String? receiptId});

class InvoiceRepository {
  InvoiceRepository(this.store, this.engine, this.catalog, this.parties);
  final AppStore store;
  final PostingEngine engine;
  final CatalogRepository catalog;
  final PartyRepository parties;

  QueryPage<InvoiceSummary> page(
    String kind, {
    String search = '',
    int page = 1,
    int pageSize = 10,
  }) {
    store.require(manage: kind != 'sale');
    final where =
        '''kind = ? ${search.isEmpty ? '' : "AND instr(app_lower(number || ' ' || json_extract(data, '\$.notes')), ?) > 0"}''';
    final parameters = <Object?>[
      kind,
      if (search.isNotEmpty) search.toLowerCase(),
    ];
    return QueryPage.read(
      total:
          store.database.handle
                  .select(
                    'SELECT COUNT(*) AS n FROM documents WHERE $where',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => _summaries(
        'SELECT rowid AS position,* FROM documents WHERE $where ORDER BY rowid DESC LIMIT ? OFFSET ?',
        [...parameters, limit, offset],
        order: 'position DESC',
      ),
    );
  }

  List<InvoiceSummary> outstanding(String partyId, bool customer) {
    store.require(manage: !customer);
    return _summaries(
      'SELECT rowid AS position,* FROM documents WHERE party_id = ? AND kind = ?',
      [partyId, customer ? 'sale' : 'purchase'],
      order: 'date, posted_at, position DESC',
      onlyOutstanding: true,
    );
  }

  String _summaryCte(String selected) =>
      '''
    WITH selected AS ($selected), balances AS (
    SELECT d.id,d.number,d.posted_at,d.party_id,d.position,
      json_extract(d.data, '\$.date') AS date,
      json_extract(d.data, '\$.total') AS total,
      COALESCE(json_extract(p.data, '\$.name'), '') AS party_name,
      COALESCE((SELECT SUM(amount) FROM allocations WHERE invoice_id = d.id), 0) AS allocated,
      COALESCE((SELECT SUM(json_extract(r.data, '\$.total')) FROM documents r
        WHERE r.source_id = d.id AND r.kind IN ('sale_return','purchase_return','reversal')), 0) AS returned
    FROM selected d LEFT JOIN parties p ON p.id = d.party_id)
  ''';

  List<InvoiceSummary> _summaries(
    String selected,
    List<Object?> parameters, {
    required String order,
    bool onlyOutstanding = false,
    int? limit,
    int offset = 0,
  }) => store.database.handle
      .select(
        '''
    ${_summaryCte(selected)}
    SELECT * FROM balances ${onlyOutstanding ? 'WHERE total > allocated + returned' : ''}
    ORDER BY $order ${limit == null ? '' : 'LIMIT ? OFFSET ?'}
  ''',
        [
          ...parameters,
          if (limit != null) ...[limit, offset],
        ],
      )
      .map((row) {
        final total = row['total'] as int;
        return (
          id: row['id'] as String,
          number: row['number'] as String,
          date: row['date'] as String,
          postedAt: row['posted_at'] as String,
          partyId: row['party_id'] as String?,
          partyName: row['party_name'] as String,
          total: total,
          due: (total - (row['allocated'] as int) - (row['returned'] as int))
              .clamp(0, total),
        );
      })
      .toList();

  QueryPage<InvoiceSummary> outstandingPage(
    String partyId,
    bool customer, {
    int page = 1,
    int pageSize = 5,
  }) {
    store.require(manage: !customer);
    const selected =
        'SELECT rowid AS position,* FROM documents WHERE party_id = ? AND kind = ?';
    final parameters = <Object?>[partyId, customer ? 'sale' : 'purchase'];
    return QueryPage.read(
      total:
          store.database.handle
                  .select(
                    '${_summaryCte(selected)} SELECT COUNT(*) AS n FROM balances WHERE total > allocated + returned',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => _summaries(
        selected,
        parameters,
        order: 'date,posted_at,position DESC',
        onlyOutstanding: true,
        limit: limit,
        offset: offset,
      ),
    );
  }

  Map<String, int> allocationPreview(
    String partyId,
    bool customer,
    int amount,
  ) {
    store.require(manage: !customer);
    if (amount <= 0) return {};
    final cte = _summaryCte(
      'SELECT rowid AS position,* FROM documents WHERE party_id = ? AND kind = ?',
    );
    final rows = store.database.handle.select(
      '''
      $cte, open_invoices AS (
        SELECT *,total-allocated-returned AS due FROM balances WHERE total > allocated + returned
      ), ordered AS (
        SELECT *, SUM(due) OVER (ORDER BY date,posted_at,position DESC ROWS UNBOUNDED PRECEDING) AS cumulative FROM open_invoices
      ) SELECT id,MIN(due,?-cumulative+due) AS amount FROM ordered WHERE cumulative-due < ? ORDER BY date,posted_at,position DESC
    ''',
      [partyId, customer ? 'sale' : 'purchase', amount, amount],
    );
    return {for (final row in rows) row['id'] as String: row['amount'] as int};
  }

  Document get(String id) {
    store.require();
    final doc = engine.find(id);
    if (doc == null) throw const BusinessException('المستند غير موجود.');
    if (!store.user!.canManage && !['sale', 'receipt'].contains(doc.kind)) {
      throw const BusinessException('لا تملك صلاحية عرض هذا المستند.');
    }
    return store.user!.canManage
        ? doc
        : doc.copyWith(
            lines: doc.lines.map((l) => l.copyWith(cost: 0)).toList(),
          );
  }

  int due(String id) {
    final doc = get(id);
    final allocated =
        store.database.handle.select(
              'SELECT COALESCE(SUM(amount),0) AS n FROM allocations WHERE invoice_id = ?',
              [id],
            ).first['n']
            as int;
    final returns =
        store.database.handle.select(
              "SELECT COALESCE(SUM(json_extract(data, '\$.total')),0) AS n FROM documents WHERE source_id = ? AND kind IN ('sale_return','purchase_return','reversal')",
              [id],
            ).first['n']
            as int;
    return (doc.total - allocated - returns).clamp(0, doc.total);
  }

  List<int> distribute(int amount, List<int> weights) {
    if (amount == 0) return List.filled(weights.length, 0);
    var remaining = amount, weight = weights.fold<int>(0, (a, b) => a + b);
    if (weight <= 0) {
      throw const BusinessException('لا يمكن توزيع المبلغ على بنود بلا قيمة.');
    }
    return [
      for (final w in weights)
        (() {
          final share = weight == 0 ? 0 : Numbers.ratio(remaining, w, weight);
          remaining -= share;
          weight -= w;
          return share;
        })(),
    ];
  }

  Document post({
    required String requestId,
    required bool sale,
    required List<InvoiceLine> lines,
    required List<Payment> payments,
    String? partyId,
    int discount = 0,
    int shipping = 0,
    String notes = '',
    String? date,
    String? correctionOf,
  }) {
    store.require(manage: !sale);
    return store.write(() {
      final duplicate = engine.find(requestId);
      if (duplicate != null) return duplicate;
      if (correctionOf != null) {
        final previous = engine.find(correctionOf);
        if (previous == null ||
            previous.kind != (sale ? 'sale' : 'purchase') ||
            store.database.handle.select(
              "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
              [correctionOf],
            ).isEmpty) {
          throw const BusinessException(
            'التصحيح يتطلب فاتورة أصلية ملغاة بمستند عكسي.',
          );
        }
        if (store.database.handle.select(
          "SELECT id FROM documents WHERE source_id = ? AND kind IN ('sale','purchase')",
          [correctionOf],
        ).isNotEmpty) {
          throw const BusinessException('تم إنشاء فاتورة مصححة لهذا المستند.');
        }
      }
      if (lines.isEmpty) {
        throw const BusinessException('أضف بندًا واحدًا على الأقل.');
      }
      if (discount < 0 || shipping < 0 || (sale && shipping != 0)) {
        throw const BusinessException('راجع الخصم والشحن.');
      }
      if (partyId != null) {
        final party = parties.get(partyId);
        if (!party.active || (sale ? !party.customer : !party.supplier)) {
          throw const BusinessException('اختر طرفًا نشطًا بدور مناسب.');
        }
      }
      final snapshots = <InvoiceLine>[];
      for (final line in lines) {
        final item = catalog.get(line.productId);
        if (!item.active) throw BusinessException('المنتج ${item.name} موقوف.');
        final alternate =
            line.unit == item.alternateUnit && item.alternateUnit.isNotEmpty;
        final factor = alternate ? item.factor : 1000;
        if ((line.unit != item.unit && !alternate) ||
            line.factor != factor ||
            line.quantity <= 0 ||
            line.price < 0 ||
            line.discount < 0 ||
            line.discount > line.gross) {
          throw BusinessException('راجع وحدات وكمية وسعر ${item.name}.');
        }
        final base = line.baseQuantity;
        if (!item.fractional && base % 1000 != 0) {
          throw BusinessException('${item.name} لا يقبل كسر الوحدة الأساسية.');
        }
        if (!sale && item.service) {
          throw const BusinessException('سجل تكلفة تنفيذ الخدمة كمصروف.');
        }
        if (sale && !store.user!.canManage) {
          final standard = Numbers.ratio(item.salePrice, factor, 1000);
          if (line.price != standard && !store.user!.canChangePrice) {
            throw const BusinessException('تغيير السعر يحتاج صلاحية إضافية.');
          }
        }
        snapshots.add(
          line.copyWith(name: item.name, service: item.service, cost: 0),
        );
      }
      final subtotal = snapshots.fold<int>(0, (a, l) => a + l.total);
      if (discount > subtotal || subtotal <= 0) {
        throw const BusinessException(
          'الخصم يتجاوز قيمة الفاتورة أو الإجمالي صفر.',
        );
      }
      final total = subtotal - discount + shipping;
      final gross = snapshots.fold<int>(0, (a, l) => a + l.gross);
      final allDiscount =
          discount + snapshots.fold<int>(0, (a, l) => a + l.discount);
      if (sale &&
          !store.user!.canManage &&
          allDiscount * 100 > gross * store.user!.discountLimit) {
        throw BusinessException(
          'الخصم يتجاوز حدك المسموح (${store.user!.discountLimit}٪).',
        );
      }
      if (payments.any((p) => p.amount <= 0)) {
        throw const BusinessException('مبلغ كل دفعة يجب أن يكون موجبًا.');
      }
      for (final p in payments) {
        engine.requireCash(p.account);
      }
      final paid = payments.fold<int>(0, (a, p) => a + p.amount);
      if (paid > total) {
        throw const BusinessException(
          'المدفوع أكبر من الفاتورة؛ سجل الزائد بسند مستقل.',
        );
      }
      if ((!sale || paid < total) && partyId == null) {
        throw const BusinessException(
          'اختيار العميل إلزامي للآجل، والمورد إلزامي للشراء.',
        );
      }
      final discounts = distribute(
        discount,
        snapshots.map((l) => l.total).toList(),
      );
      final shippingShares = distribute(
        shipping,
        snapshots
            .map((l) => l.total - discounts[snapshots.indexOf(l)])
            .toList(),
      );
      final requiredStock = <String, int>{};
      if (sale) {
        for (final l in snapshots.where((l) => !l.service)) {
          requiredStock.update(
            l.productId,
            (n) => n + l.baseQuantity,
            ifAbsent: () => l.baseQuantity,
          );
        }
        for (final e in requiredStock.entries) {
          if (engine.stock(e.key).quantity < e.value) {
            throw BusinessException(
              'المخزون لا يكفي للمنتج ${catalog.get(e.key).name}.',
            );
          }
        }
      }
      final docId = requestId;
      final journal = <JournalLine>[];
      final movements = <({String id, int q, int value})>[];
      final virtual = <String, ({int q, int value, int unitCost})>{};
      for (var i = 0; i < snapshots.length; i++) {
        var line = snapshots[i];
        final value = line.total - discounts[i];
        if (sale) {
          journal.add(credit(line.service ? '4200' : '4100', value));
          if (!line.service) {
            final s =
                virtual[line.productId] ??
                (() {
                  final s = engine.stock(line.productId);
                  return (q: s.quantity, value: s.value, unitCost: s.unitCost);
                })();
            final cost = line.baseQuantity == s.q
                ? s.value
                : Numbers.ratio(
                    s.unitCost,
                    line.baseQuantity,
                    10000000,
                  ).clamp(0, s.value);
            virtual[line.productId] = (
              q: s.q - line.baseQuantity,
              value: s.value - cost,
              unitCost: s.unitCost,
            );
            line = line.copyWith(cost: cost);
            journal.addAll([debit('5100', cost), credit('1300', cost)]);
            movements.add((
              id: line.productId,
              q: -line.baseQuantity,
              value: -cost,
            ));
          }
        } else {
          final landed = value + shippingShares[i];
          line = line.copyWith(cost: landed);
          journal.add(debit('1300', landed));
          movements.add((
            id: line.productId,
            q: line.baseQuantity,
            value: landed,
          ));
        }
        snapshots[i] = line;
      }
      for (final p in payments) {
        journal.add(
          sale ? debit(p.account, p.amount) : credit(p.account, p.amount),
        );
      }
      if (total > paid) {
        journal.add(
          sale
              ? debit('1200', total - paid, partyId)
              : credit('2100', total - paid, partyId),
        );
      }
      final doc = engine.create(
        id: docId,
        kind: sale ? 'sale' : 'purchase',
        sourceId: correctionOf,
        total: total,
        partyId: partyId,
        lines: snapshots,
        payments: payments,
        discount: discount,
        shipping: shipping,
        notes: notes,
        date: date,
      );
      engine.insert(doc, journal);
      for (final move in movements) {
        engine.moveStock(docId, move.id, move.q, move.value);
      }
      if (paid > 0) {
        store.database.handle.execute(
          'INSERT INTO allocations(payment_id, invoice_id, amount) VALUES (?, ?, ?)',
          [docId, docId, paid],
        );
      }
      store.database.handle.execute('DELETE FROM drafts WHERE id = ?', [
        requestId,
      ]);
      return doc;
    });
  }

  String correctionDraft(String originalId) {
    store.require(manage: true);
    final original = get(originalId);
    if (!['sale', 'purchase'].contains(original.kind) ||
        store.database.handle.select(
          "SELECT id FROM documents WHERE source_id = ? AND kind = 'reversal'",
          [originalId],
        ).isEmpty) {
      throw const BusinessException(
        'ألغِ الفاتورة أولًا قبل إنشاء نسخة مصححة.',
      );
    }
    final id = store.id();
    saveDraft(id, original.kind, {
      'lines': [
        for (final l in original.lines)
          {
            'productId': l.productId,
            'unit': l.unit,
            'quantity': Numbers.input(l.quantity, decimals: 3),
            'price': Numbers.input(l.price),
            'discount': Numbers.input(l.discount),
            'description': l.description,
          },
      ],
      'payments': <Map<String, dynamic>>[],
      'partyId': original.partyId,
      'discount': Numbers.input(original.discount),
      'shipping': Numbers.input(original.shipping),
      'date': DateTime.now().toIso8601String(),
      'notes': 'تصحيح ${original.number}',
      'correctionOf': originalId,
    });
    return id;
  }

  void deleteDraft(String id) {
    store.require();
    store.write(
      () => store.database.handle.execute(
        'DELETE FROM drafts WHERE id = ? AND user_id = ?',
        [id, store.user!.id],
      ),
    );
  }

  void saveDraft(
    String id,
    String kind,
    Map<String, dynamic> data, {
    bool notify = true,
  }) {
    store.require(manage: kind != 'sale');
    if (store.database.handle.select('SELECT 1 FROM documents WHERE id = ?', [
      id,
    ]).isNotEmpty) {
      return;
    }
    final owners = store.database.handle.select(
      'SELECT user_id FROM drafts WHERE id = ?',
      [id],
    );
    if (owners.isNotEmpty && owners.first['user_id'] != store.user!.id) {
      throw const BusinessException('المسودة تخص مستخدمًا آخر.');
    }
    store.write(
      () => store.database.handle.execute(
        'INSERT INTO drafts VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at',
        [
          id,
          store.user!.id,
          kind,
          DateTime.now().toUtc().toIso8601String(),
          jsonEncode(data),
        ],
      ),
      notify: notify,
    );
  }

  Map<String, dynamic>? loadDraft(String id) {
    store.require();
    final rows = store.database.handle.select(
      'SELECT data FROM drafts WHERE id = ? AND user_id = ?',
      [id, store.user!.id],
    );
    return rows.isEmpty
        ? null
        : jsonDecode(rows.first['data'] as String) as Map<String, dynamic>;
  }

  QueryPage<InvoiceDraft> drafts(
    String kind, {
    int page = 1,
    int pageSize = 5,
  }) {
    store.require(manage: kind != 'sale');
    final db = store.database.handle, parameters = [kind, store.user!.id];
    return QueryPage.read(
      total:
          db
                  .select(
                    'SELECT COUNT(*) AS n FROM drafts WHERE kind = ? AND user_id = ?',
                    parameters,
                  )
                  .first['n']
              as int,
      page: page,
      pageSize: pageSize,
      read: (limit, offset) => db
          .select(
            "SELECT id,updated_at,json_extract(data, '\$.receiptId') AS receipt_id FROM drafts WHERE kind = ? AND user_id = ? ORDER BY updated_at DESC,id DESC LIMIT ? OFFSET ?",
            [...parameters, limit, offset],
          )
          .map(
            (row) => (
              id: row['id'] as String,
              updatedAt: row['updated_at'] as String,
              receiptId: row['receipt_id'] as String?,
            ),
          )
          .toList(),
    );
  }
}
