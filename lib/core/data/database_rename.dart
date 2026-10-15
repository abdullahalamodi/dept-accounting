import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../numbers.dart';

Future<void> copyLegacyDatabase(
  File destination,
  Iterable<File> sources,
) async {
  if (await destination.exists()) return;
  for (final source in sources) {
    if (!await source.exists()) continue;
    // SQLite backup includes committed WAL data. Keep the original untouched.
    final temporary = File('${destination.path}.migration');
    if (await temporary.exists()) await temporary.delete();
    final original = sqlite3.open(source.path, mode: OpenMode.readOnly);
    try {
      final target = sqlite3.open(temporary.path);
      try {
        await original.backup(target).drain<void>();
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
