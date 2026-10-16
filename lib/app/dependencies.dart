import '../core/data/local_database.dart';
import '../core/data/database_executor.dart';
import '../features/backup/data/backup_service.dart';
import '../features/reports/data/export_service.dart';
import 'app_data.dart';

class AppDependencies extends AppData {
  AppDependencies(super.database) {
    store.executor = DatabaseExecutor.local(this);
    backups = BackupService(store);
  }

  AppDependencies._remote(super.database, DatabaseExecutor executor) {
    store.executor = executor;
    executor.attach(store);
    backups = BackupService(store);
  }

  static Future<AppDependencies> open({String? path}) async {
    final resolved = path ?? await LocalDatabase.resolvePath();
    final executor = await DatabaseExecutor.open(resolved);
    try {
      final dependencies = AppDependencies._remote(
        LocalDatabase.readOnly(resolved),
        executor,
      );
      await dependencies.store.restoreSession();
      return dependencies;
    } catch (_) {
      await executor.close();
      rethrow;
    }
  }

  final exports = ExportService();
  late final BackupService backups;
  Future<void>? _shutdown;
  Future<void> shutdown() => _shutdown ??= _close();
  Future<void> _close() async {
    await backups.shutdown();
    await store.executor?.close();
    store.dispose();
    store.database.close();
  }
}
