import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

Future<T> withSelectedBackup<T>(
  PlatformFile selected,
  Future<T> Function(File) action,
) async {
  final directory = await Directory.systemTemp.createTemp(
    'dept-backup-selected-',
  );
  try {
    final file = File(p.join(directory.path, 'selected.backup'));
    // A stable streamed copy also supports picker URIs that are not file paths.
    await selected.readAsByteStream().cast<List<int>>().pipe(file.openWrite());
    return await action(file);
  } finally {
    await directory.delete(recursive: true);
  }
}
