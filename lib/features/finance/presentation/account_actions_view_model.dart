import '../data/reconciliation_tasks.dart';
import '../data/credit_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';

class AccountActionsViewModel extends ActionViewModel {
  AccountActionsViewModel(this.d);
  final AppDependencies d;
  Future<bool> allocate(
    String sourceId,
    Map<String, int> automatic,
    Map<String, String>? manual,
  ) => run(() async {
    final allocations = manual == null
        ? automatic
        : {
            for (final e in manual.entries)
              if (Numbers.parse(e.value) > 0) e.key: Numbers.parse(e.value),
          };
    await d.store.run(
      CreditTasks.allocate(d.store.id(), sourceId, allocations),
    );
  });
  Future<bool> refund(
    String partyId,
    bool customer,
    String? account,
    String amount,
    String reason,
  ) => run(() async {
    if (account == null) throw const BusinessException('اختر الحساب النقدي.');
    await d.store.run(
      CreditTasks.refund(
        requestId: d.store.id(),
        partyId: partyId,
        customer: customer,
        account: account,
        amount: Numbers.parse(amount),
        reason: reason,
      ),
    );
  });
  Future<bool> reconcile(String account, String counted, String reason) => run(
    () async => await d.store.run(
      ReconciliationTasks.reconcile(
        requestId: d.store.id(),
        account: account,
        counted: Numbers.parse(counted),
        reason: reason,
      ),
    ),
  );
  Future<bool> closeOpening(String reason) => run(
    () async => await d.store.run(ReconciliationTasks.closeOpening(reason)),
  );
}
