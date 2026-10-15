import 'package:flutter/foundation.dart';

import '../data/overview_repository.dart';

class OverviewViewModel extends ChangeNotifier {
  OverviewViewModel(this.repository) {
    repository.store.addListener(refresh);
    refresh();
  }
  final OverviewRepository repository;
  int days = 7;
  List<OverviewDay> activity = [];
  List<OverviewInvoice> invoices = [];
  List<OverviewStock> lowStock = [];

  void refresh() {
    if (repository.store.user == null) return;
    activity = repository.activity(days);
    invoices = repository.recentInvoices();
    lowStock = repository.lowStock();
    notifyListeners();
  }

  void changePeriod(int value) {
    if (days == value) return;
    days = value;
    refresh();
  }

  @override
  void dispose() {
    repository.store.removeListener(refresh);
    super.dispose();
  }
}
