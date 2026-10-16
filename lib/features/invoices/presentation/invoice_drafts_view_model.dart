import '../../../core/ui/form_widgets.dart';
import '../data/invoice_repository.dart';

class InvoiceDraftsViewModel extends ActionViewModel {
  InvoiceDraftsViewModel(this.repository, this.kind);
  final InvoiceRepository repository;
  final String kind;
  int page = 1;

  void go(int value) {
    page = value;
    changed();
  }
}
