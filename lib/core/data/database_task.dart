import 'dart:async';

import '../../app/app_data.dart';

class DatabaseTask<T> {
  const DatabaseTask(
    this.name,
    this.run, {
    this.notify = true,
    this.updatesSession = false,
  });
  final String name;
  // Construct tasks in static factories with only sendable values in scope.
  final FutureOr<T> Function(AppData data) run;
  final bool notify, updatesSession;
}
