import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../invoices/data/document.dart';
import '../../invoices/presentation/invoice_view_model.dart';

class FinanceViewModel extends ActionViewModel {
  FinanceViewModel(this.d) : requestId = d.store.id() {
    payments.add(PaymentInput(account: d.finance.accounts().first.code));
  }
  final AppDependencies d;
  String requestId;
  String kind = 'receipt', notes = '', category = '', allocationMode = 'auto';
  String? partyId, toAccount;
  final payments = <PaymentInput>[];
  final manual = <String, String>{};
  int get total {
    try {
      return payments.fold<int>(0, (a, p) => a + Numbers.parse(p.amount));
    } catch (_) {
      return 0;
    }
  }

  bool get voucher => ['receipt', 'payment'].contains(kind);
  Map<String, int> get allocations {
    if (!voucher || partyId == null || allocationMode == 'none') return {};
    if (allocationMode == 'auto') {
      return d.finance.allocationPreview(partyId!, kind == 'receipt', total);
    }
    return {
      for (final e in manual.entries)
        if (e.value.trim().isNotEmpty && Numbers.parse(e.value) > 0)
          e.key: Numbers.parse(e.value),
    };
  }

  Map<String, int> get safePreview {
    try {
      return allocations;
    } catch (_) {
      return {};
    }
  }

  void changeKind(String value) {
    kind = value;
    partyId = null;
    manual.clear();
    changed();
  }

  Future<Document?> post() async {
    Document? doc;
    await run(() async {
      doc = d.finance.post(
        requestId: requestId,
        kind: kind,
        payments: [
          for (final p in payments)
            Payment(account: p.account, amount: Numbers.parse(p.amount)),
        ],
        partyId: partyId,
        toAccount: toAccount,
        notes: notes,
        category: category,
        allocations: allocations,
      );
    });
    return doc;
  }

  bool opening(String code, String amount) =>
      perform(() => d.finance.setOpening(code, Numbers.parse(amount)));
  bool removeOpening(String code) =>
      perform(() => d.finance.removeOpening(code));
  bool closeOpening() => perform(
    () => d.reconciliation.closeOpening('تمت مراجعة الحسابات وأرصدة البداية'),
  );
  bool addAccount(String name) => perform(() => d.finance.addAccount(name));
}
