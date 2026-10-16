import 'document.dart';
import '../../../core/data/database_task.dart';

abstract final class CorrectionTasks {
  static DatabaseTask<Document> cancel(
    String id,
    String requestId,
    String reason,
  ) => DatabaseTask(
    'corrections.cancel',
    (context) => context.corrections.cancel(id, requestId, reason),
  );
}
