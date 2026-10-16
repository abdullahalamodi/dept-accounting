import '../data/returns_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../invoices/data/document.dart';
import '../data/returns_repository.dart';

class ReturnInput {
  bool selected = false, damaged = false;
  String quantity = '1', amount = '0';
}

class ReturnViewModel extends ActionViewModel {
  ReturnViewModel(this.d, this.invoiceId) : requestId = d.store.id() {
    original = d.invoices.get(invoiceId);
    inputs = [
      for (final l in original.lines)
        ReturnInput()..amount = Numbers.input(l.total),
    ];
  }
  final AppDependencies d;
  final String invoiceId, requestId;
  late final Document original;
  late final List<ReturnInput> inputs;
  ReturnHistory? _history;
  int due = 0;
  ReturnHistory get history => _history!;
  void accept(ReturnSnapshot snapshot) {
    _history = snapshot.history;
    due = snapshot.due;
  }

  String reason = '', refund = '0';
  String? account;
  List<ReturnSelection> get selections => [
    for (var i = 0; i < inputs.length; i++)
      if (inputs[i].selected)
        (
          index: i,
          quantity: original.lines[i].service
              ? 0
              : Numbers.parse(inputs[i].quantity, decimals: 3),
          serviceAmount: original.lines[i].service
              ? Numbers.parse(inputs[i].amount)
              : 0,
          damaged: inputs[i].damaged,
        ),
  ];
  int get total {
    try {
      return d.returns
          .calculate(original, selections, previousHistory: history)
          .fold<int>(0, (n, r) => n + r.value);
    } catch (_) {
      return 0;
    }
  }

  int get excess => (total - due).clamp(0, total);
  Future<Document?> post() async {
    Document? result;
    await run(() async {
      result = await d.store.run(
        ReturnTasks.post(
          requestId: requestId,
          invoiceId: invoiceId,
          selected: selections,
          reason: reason,
          cashAccount: account,
          refund: Numbers.parse(refund, emptyAsZero: true),
        ),
      );
    });
    return result;
  }
}
