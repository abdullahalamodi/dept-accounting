import '../../../core/data/database_task.dart';
import 'startup_guide_repository.dart';

typedef StartupSnapshot = ({
  bool available,
  bool visible,
  List<StartupGuideStep> steps,
});

abstract final class StartupTasks {
  static DatabaseTask<void> start() => DatabaseTask(
    'startupGuide.start',
    (context) => context.startupGuide.start(),
  );
  static DatabaseTask<void> review(StartupTask task, {bool skip = false}) =>
      DatabaseTask(
        'startupGuide.review',
        (context) => context.startupGuide.review(task, skip: skip),
      );
  static DatabaseTask<void> revisit(StartupTask task) => DatabaseTask(
    'startupGuide.revisit',
    (context) => context.startupGuide.revisit(task),
  );

  static DatabaseTask<StartupSnapshot> snapshot() => DatabaseTask(
    'startup.snapshot',
    (data) => (
      available: data.startupGuide.available,
      visible: data.startupGuide.visible,
      steps: data.startupGuide.available
          ? data.startupGuide.steps()
          : <StartupGuideStep>[],
    ),
  );
}
