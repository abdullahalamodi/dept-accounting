import '../../../core/data/app_store.dart';
import '../../../core/numbers.dart';
import '../../accounting/data/posting_engine.dart';
import '../../invoices/data/document.dart';

class ReconciliationRepository {
  ReconciliationRepository(this.store, this.engine);
  final AppStore store;
  final PostingEngine engine;
  Document reconcile({
    required String requestId,
    required String account,
    required int counted,
    required String reason,
  }) {
    store.require(manage: true);
    return store.write(() {
      final existing = engine.find(requestId);
      if (existing != null) return existing;
      engine.requireCash(account);
      if (counted < 0 || reason.trim().isEmpty) {
        throw const BusinessException('أدخل الرصيد الفعلي وسبب المطابقة.');
      }
      final old = engine.balance(account), delta = counted - old;
      final doc = engine.create(
        id: requestId,
        kind: 'cash_reconciliation',
        total: delta.abs(),
        reason: reason.trim(),
        notes: 'مطابقة وإغلاق الصندوق',
        extra: {'account': account, 'bookBalance': old, 'counted': counted},
      );
      engine.insert(
        doc,
        delta == 0
            ? []
            : delta > 0
            ? [debit(account, delta), credit('6200', delta)]
            : [debit('6200', -delta), credit(account, -delta)],
      );
      return doc;
    });
  }

  void closeOpening(String reason) {
    store.require(manage: true);
    store.write(() {
      if (store.setting('opening_closed') == 'true') {
        throw const BusinessException('الافتتاح مقفل بالفعل.');
      }
      if (reason.trim().isEmpty) {
        throw const BusinessException('أدخل ملاحظة المراجعة.');
      }
      final balance = engine.balance('3900');
      final doc = engine.create(
        id: store.id(),
        kind: 'opening_close',
        total: balance.abs(),
        reason: reason.trim(),
        notes: 'إقفال التسوية الافتتاحية إلى رأس المال',
      );
      engine.insert(
        doc,
        balance == 0
            ? []
            : balance > 0
            ? [credit('3900', balance), debit('3100', balance)]
            : [debit('3900', -balance), credit('3100', -balance)],
      );
      store.setSetting('opening_closed', 'true');
    });
  }
}
