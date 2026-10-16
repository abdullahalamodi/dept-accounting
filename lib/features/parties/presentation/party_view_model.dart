import '../data/parties_tasks.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../core/numbers.dart';
import '../data/party.dart';
import '../data/party_repository.dart';
import '../../reports/data/export_service.dart';

class PartyViewModel extends ActionViewModel {
  PartyViewModel(this.repository, {this.exports});
  final ExportService? exports;
  final PartyRepository repository;
  String search = '';
  int page = 1, pageSize = 10;

  Future<bool> save(Party party) =>
      run(() async => await repository.store.run(PartyTasks.save(party)));
  Future<bool> opening(String id, bool customer, String amount) => run(
    () async => await repository.store.run(
      PartyTasks.opening(id, customer, Numbers.parse(amount, negative: true)),
    ),
  );
  Future<bool> exportStatement(String id, bool customer, {bool pdf = true}) =>
      run(() async {
        final report = await repository.store.run(
              PartyTasks.statementReport(id, customer),
            ),
            shop = repository.store.shop!;
        if (pdf) {
          await exports!.savePdf(shop, report);
        } else {
          await exports!.saveExcel(shop, report);
        }
      });
  Future<bool> adjust(String id, bool customer, String amount, String reason) =>
      run(
        () async => await repository.store.run(
          PartyTasks.adjust(
            id,
            customer,
            Numbers.parse(amount, negative: true),
            reason,
          ),
        ),
      );
  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }
}
