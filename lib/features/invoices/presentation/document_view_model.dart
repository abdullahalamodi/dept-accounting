import '../../finance/data/credit_tasks.dart';
import '../data/correction_tasks.dart';
import '../data/invoices_tasks.dart';
import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/document.dart';
import '../../reports/data/export_service.dart';

class DocumentViewModel extends ActionViewModel {
  DocumentViewModel(this.d, this.id);
  final AppDependencies d;
  final String id;
  Document get document => d.invoices.get(id);
  Future<ReportTable> get report => d.store.run(InvoiceTasks.report(id));
  bool get cancelled => d.corrections.isCancelled(id);
  Future<bool> printDocument(bool thermal) => run(
    () async =>
        d.exports.printReport(d.store.shop!, await report, thermal: thermal),
  );
  Future<bool> shareDocument() =>
      run(() async => d.exports.share(d.store.shop!, await report));
  Future<bool> saveDocument() =>
      run(() async => d.exports.savePdf(d.store.shop!, await report));
  Future<String?> correctionDraft() async {
    String? result;
    await run(
      () async => result = await d.store.run(InvoiceTasks.correctionDraft(id)),
    );
    return result;
  }

  Future<bool> clearAllocations(String reason) => run(
    () async => await d.store.run(CreditTasks.clearAllocations(id, reason)),
  );
  Future<Document?> cancel(String reason) async {
    Document? result;
    await run(() async {
      result = await d.store.run(
        CorrectionTasks.cancel(id, d.store.id(), reason),
      );
    });
    return result;
  }
}
