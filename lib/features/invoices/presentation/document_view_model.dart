import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/document.dart';
import '../../reports/data/export_service.dart';

class DocumentViewModel extends ActionViewModel {
  DocumentViewModel(this.d, this.id);
  final AppDependencies d;
  final String id;
  Document get document => d.invoices.get(id);
  ReportTable get report => d.exports.document(
    d.store.shop!,
    document,
    party: document.partyId == null
        ? null
        : d.parties.get(document.partyId!).name,
    due: ['sale', 'purchase'].contains(document.kind)
        ? d.invoices.due(id)
        : null,
  );
  bool get cancelled => d.corrections.isCancelled(id);
  Future<bool> printDocument(bool thermal) =>
      run(() => d.exports.printReport(d.store.shop!, report, thermal: thermal));
  Future<bool> shareDocument() =>
      run(() => d.exports.share(d.store.shop!, report));
  Future<bool> saveDocument() =>
      run(() => d.exports.savePdf(d.store.shop!, report));
  String? correctionDraft() {
    String? result;
    perform(() => result = d.invoices.correctionDraft(id));
    return result;
  }

  bool clearAllocations(String reason) =>
      perform(() => d.credits.clearAllocations(id, reason));
  Future<Document?> cancel(String reason) async {
    Document? result;
    await run(() async {
      result = d.corrections.cancel(id, d.store.id(), reason);
    });
    return result;
  }
}
