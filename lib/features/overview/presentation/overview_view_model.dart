import '../../../core/ui/async_query_view_model.dart';
import '../data/overview_tasks.dart';

import 'package:flutter/foundation.dart';

import '../data/overview_repository.dart';

class OverviewViewModel extends ChangeNotifier {
  OverviewViewModel(this.repository) {
    repository.store.addListener(refresh);
    refresh();
  }
  final OverviewRepository repository;
  bool _disposed = false;
  final query = AsyncQueryViewModel<OverviewSnapshot>();
  int days = 7;
  List<OverviewDay> activity = [];
  List<OverviewInvoice> invoices = [];
  List<OverviewStock> lowStock = [];
  int lowStockCount = 0;

  Future<void> refresh() async {
    if (repository.store.user == null) return;
    await query.load(() => repository.store.run(OverviewTasks.snapshot(days)));
    await query.settled;
    final snapshot = query.value;
    if (snapshot != null) {
      activity = snapshot.activity;
      invoices = snapshot.invoices;
      lowStock = snapshot.stock.items;
      lowStockCount = snapshot.stock.total;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> changePeriod(int value) async {
    if (days == value) return;
    days = value;
    await refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.store.removeListener(refresh);
    query.dispose();
    super.dispose();
  }
}
