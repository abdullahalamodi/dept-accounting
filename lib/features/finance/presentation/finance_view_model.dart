import '../data/reconciliation_tasks.dart';
import '../data/finance_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../invoices/data/document.dart';
import '../../invoices/presentation/invoice_view_model.dart';

class FinanceViewModel extends ActionViewModel {
  FinanceViewModel(this.d) : requestId = d.store.id() {
    payments.add(PaymentInput(account: d.finance.accountOptions().first.code));
  }
  final AppDependencies d;
  String requestId;
  String kind = 'receipt', notes = '', category = '', allocationMode = 'auto';
  String? partyId, toAccount;
  final payments = <PaymentInput>[];
  final manual = <String, String>{};
  int invoicePage = 1;
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
    if (allocationMode == 'auto') return {};
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
    invoicePage = 1;
    changed();
  }

  void changeParty(String? value) {
    partyId = value;
    manual.clear();
    invoicePage = 1;
    changed();
  }

  void goInvoices(int value) {
    invoicePage = value;
    changed();
  }

  Future<Document?> post() async {
    Document? doc;
    await run(() async {
      doc = await d.store.run(
        FinanceTasks.post(
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
          automatic: voucher && allocationMode == 'auto',
        ),
      );
    });
    return doc;
  }

  Future<bool> opening(String code, String amount) => run(
    () async =>
        d.store.run(FinanceTasks.setOpening(code, Numbers.parse(amount))),
  );
  Future<bool> removeOpening(String code) =>
      run(() async => await d.store.run(FinanceTasks.removeOpening(code)));
  Future<bool> closeOpening() => run(
    () async => await d.store.run(
      ReconciliationTasks.closeOpening('تمت مراجعة الحسابات وأرصدة البداية'),
    ),
  );
  Future<bool> addAccount(String name) =>
      run(() async => await d.store.run(FinanceTasks.addAccount(name)));
}
