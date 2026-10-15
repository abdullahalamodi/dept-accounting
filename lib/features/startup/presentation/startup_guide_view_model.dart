import 'package:flutter/foundation.dart';

import '../data/startup_guide_repository.dart';

class StartupGuideViewModel extends ChangeNotifier {
  StartupGuideViewModel(this.repository, {required this.backupStatus}) {
    repository.store.addListener(refresh);
    backupStatus.addListener(refresh);
    refresh();
  }

  final StartupGuideRepository repository;
  final Listenable backupStatus;
  List<StartupGuideStep> steps = [];
  bool available = false, visible = false;
  StartupGuideStep? get next =>
      steps.where((step) => !step.resolved).firstOrNull;
  int get resolvedCount => steps.where((step) => step.resolved).length;

  void refresh() {
    available = repository.available;
    visible = repository.visible;
    steps = available ? repository.steps() : [];
    notifyListeners();
  }

  void start() => repository.start();
  void revisit(StartupTask task) => repository.revisit(task);
  void review(StartupTask task, {bool skip = false}) =>
      repository.review(task, skip: skip);

  @override
  void dispose() {
    repository.store.removeListener(refresh);
    backupStatus.removeListener(refresh);
    super.dispose();
  }
}
