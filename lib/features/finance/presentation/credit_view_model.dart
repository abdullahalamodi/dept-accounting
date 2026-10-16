import '../data/credit_tasks.dart';
import '../../../core/data/query_page.dart';
import '../data/credit_repository.dart';
import 'account_actions_view_model.dart';

class CreditViewModel extends AccountActionsViewModel {
  CreditViewModel(super.d, {required this.partyId, required this.customer});
  final String partyId;
  final bool customer;
  String? sourceId;
  bool automatic = true;
  int invoicePage = 1;
  final manual = <String, String>{};
  Future<QueryPage<CreditSummary>> searchSources(String search, int page) =>
      d.store.run(
        CreditTasks.sourcePage(partyId, customer, search: search, page: page),
      );
  void chooseSource(String? id) {
    sourceId = id;
    manual.clear();
    invoicePage = 1;
    changed();
  }

  void goInvoices(int value) {
    invoicePage = value;
    changed();
  }

  void changeAutomatic(bool value) {
    automatic = value;
    changed();
  }

  void changeManual(String id, String value) {
    manual[id] = value;
    changed();
  }
}
