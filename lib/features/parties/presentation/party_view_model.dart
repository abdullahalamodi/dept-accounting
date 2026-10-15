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
  List<Party> get filtered => repository
      .all()
      .where(
        (p) =>
            '${p.name} ${p.phone}'.toLowerCase().contains(search.toLowerCase()),
      )
      .toList();
  List<Party> get visible =>
      filtered.skip((page - 1) * pageSize).take(pageSize).toList();
  bool save(Party party) => perform(() => repository.save(party));
  bool opening(String id, bool customer, String amount) => perform(
    () =>
        repository.opening(id, customer, Numbers.parse(amount, negative: true)),
  );
  Future<bool> exportStatement(String id, bool customer, {bool pdf = true}) =>
      run(() async {
        final report = repository.statementReport(id, customer),
            shop = repository.store.shop!;
        if (pdf) {
          await exports!.savePdf(shop, report);
        } else {
          await exports!.saveExcel(shop, report);
        }
      });
  bool adjust(String id, bool customer, String amount, String reason) =>
      perform(
        () => repository.adjust(
          id,
          customer,
          Numbers.parse(amount, negative: true),
          reason,
        ),
      );
  void filter(String value) {
    search = value;
    page = 1;
    changed();
  }
}
