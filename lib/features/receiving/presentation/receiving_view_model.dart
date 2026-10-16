import '../../../core/ui/form_widgets.dart';
import '../data/receiving_repository.dart';

class ReceivingViewModel extends ActionViewModel {
  ReceivingViewModel(this.repository);
  final ReceivingRepository repository;
  int page = 1;

  void go(int value) {
    page = value;
    changed();
  }
}
