import 'dart:io';
import 'dart:typed_data';

import 'package:dept_accounting/features/backup/presentation/backup_file_selection.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StreamedBackup extends PlatformFile {
  @override
  Uri get uri => Uri.parse('content://selected/backup');
  @override
  Stream<Uint8List> readAsByteStream() => Stream.fromIterable([
    Uint8List.fromList([1, 2]),
    Uint8List.fromList([3, 4]),
  ]);
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Use streamed access');
}

void main() {
  test(
    'Selected backups without local paths stream into a stable scoped copy',
    () async {
      for (final fail in [false, true]) {
        late File copy;
        final result = withSelectedBackup(_StreamedBackup(), (file) async {
          copy = file;
          expect(await file.readAsBytes(), [1, 2, 3, 4]);
          if (fail) throw StateError('cancelled');
        });
        if (fail) {
          await expectLater(result, throwsStateError);
        } else {
          await result;
        }
        expect(await copy.exists(), isFalse);
        expect(await copy.parent.exists(), isFalse);
      }
    },
  );
}
