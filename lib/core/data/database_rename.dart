import 'dart:io';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';

import '../numbers.dart';

Future<void> copyLegacyDatabase(File destination, Iterable<File> sources) {
  final destinationPath = destination.path,
      sourcePaths = sources.map((f) => f.path).toList();
  return Isolate.run(() => _copyLegacyDatabase(destinationPath, sourcePaths));
}

Future<void> _copyLegacyDatabase(
  String destinationPath,
  List<String> sourcePaths,
) async {
  final destination = File(destinationPath);
  if (await destination.exists()) return;
  for (final sourcePath in sourcePaths) {
    final source = File(sourcePath);
    if (!await source.exists()) continue;
    // SQLite backup includes committed WAL data. Keep the original untouched.
    final temporary = File('${destination.path}.migration');
    if (await temporary.exists()) await temporary.delete();
    final original = sqlite3.open(source.path, mode: OpenMode.readOnly);
    try {
      final target = sqlite3.open(temporary.path);
      try {
        await original.backup(target, nPage: -1).drain<void>();
        if (target.select('PRAGMA integrity_check').first.values.first !=
            'ok') {
          throw const BusinessException(
            'تعذر نقل قاعدة بيانات التطبيق السابقة.',
          );
        }
      } finally {
        target.close();
      }
      await temporary.rename(destination.path);
    } finally {
      original.close();
      if (await temporary.exists()) await temporary.delete();
    }
    return;
  }
}
