import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';

class AccountActionsViewModel extends ActionViewModel {
  AccountActionsViewModel(this.d);
  final AppDependencies d;
  bool allocate(
    String sourceId,
    Map<String, int> automatic,
    Map<String, String>? manual,
  ) => perform(() {
    final allocations = manual == null
        ? automatic
        : {
            for (final e in manual.entries)
              if (Numbers.parse(e.value) > 0) e.key: Numbers.parse(e.value),
          };
    d.credits.allocate(d.store.id(), sourceId, allocations);
  });
  bool refund(
    String partyId,
    bool customer,
    String? account,
    String amount,
    String reason,
  ) => perform(() {
    if (account == null) throw const BusinessException('اختر الحساب النقدي.');
    d.credits.refund(
      requestId: d.store.id(),
      partyId: partyId,
      customer: customer,
      account: account,
      amount: Numbers.parse(amount),
      reason: reason,
    );
  });
  bool reconcile(String account, String counted, String reason) => perform(
    () => d.reconciliation.reconcile(
      requestId: d.store.id(),
      account: account,
      counted: Numbers.parse(counted),
      reason: reason,
    ),
  );
  bool closeOpening(String reason) =>
      perform(() => d.reconciliation.closeOpening(reason));
}
