import '../../../core/ui/async_query_view_model.dart';
import '../../../core/ui/form_widgets.dart';
import '../data/startup_tasks.dart';

import 'package:flutter/foundation.dart' show Listenable;

import '../data/startup_guide_repository.dart';

class StartupGuideViewModel extends ActionViewModel {
  StartupGuideViewModel(this.repository, {required this.backupStatus}) {
    repository.store.addListener(refresh);
    backupStatus.addListener(refresh);
    refresh();
  }

  final StartupGuideRepository repository;
  final Listenable backupStatus;
  final query = AsyncQueryViewModel<StartupSnapshot>();
  bool _disposed = false;
  List<StartupGuideStep> steps = [];
  bool available = false, visible = false;
  StartupGuideStep? get next =>
      steps.where((step) => !step.resolved).firstOrNull;
  int get resolvedCount => steps.where((step) => step.resolved).length;

  Future<void> refresh() async {
    await query.load(() => repository.store.run(StartupTasks.snapshot()));
    await query.settled;
    final snapshot = query.value;
    if (_disposed) return;
    if (snapshot != null) {
      available = snapshot.available;
      visible = snapshot.visible;
      steps = snapshot.steps;
    }
    notifyListeners();
  }

  Future<bool> start() => run(() async {
    await repository.store.run(StartupTasks.start());
    await refresh();
  });
  Future<bool> revisit(StartupTask task) => run(() async {
    await repository.store.run(StartupTasks.revisit(task));
    await refresh();
  });
  Future<bool> review(StartupTask task, {bool skip = false}) => run(() async {
    await repository.store.run(StartupTasks.review(task, skip: skip));
    await refresh();
  });

  @override
  void dispose() {
    _disposed = true;
    query.dispose();
    repository.store.removeListener(refresh);
    backupStatus.removeListener(refresh);
    super.dispose();
  }
}
