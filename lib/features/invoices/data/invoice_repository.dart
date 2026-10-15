import 'dart:convert';

import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../parties/data/party_repository.dart';
import 'document.dart';

class InvoiceRepository {
  InvoiceRepository(this.store, this.engine, this.catalog, this.parties);
  final AppStore store;
  final PostingEngine engine;
  final CatalogRepository catalog;
  final PartyRepository parties;

  List<Document> list(String kind) {
    store.require(manage: kind != 'sale');
    return store.database.handle
        .select(
          'SELECT data FROM documents WHERE kind = ? ORDER BY rowid DESC',
          [kind],
        )
        .map((r) => DocumentMapper.fromJson(r['data'] as String))
        .toList();
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
      'date': DateTime.now().toIso8601String().substring(0, 10),
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

  List<Map<String, Object?>> drafts(String kind) {
    store.require(manage: kind != 'sale');
    return store.database.handle
        .select(
          'SELECT id, updated_at FROM drafts WHERE kind = ? AND user_id = ? ORDER BY updated_at DESC',
          [kind, store.user!.id],
        )
        .map((r) => Map<String, Object?>.from(r))
        .toList();
  }
}
