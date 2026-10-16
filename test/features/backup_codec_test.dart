import 'dart:convert';
import 'dart:io';

import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/backup/data/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Streaming file archives authenticate across chunks and reject corruption',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dept-archive-codec-',
      );
      try {
        final key = base64UrlEncode(List<int>.generate(32, (i) => i));
        final data = List<int>.generate(1024 * 1024 + 17, (i) => i % 251);
        final source = await File('${directory.path}/source')
            .writeAsBytes(data);
        final archive = File('${directory.path}/archive');
        final decoded = File('${directory.path}/decoded');
        await BackupCodec.encryptFile(source, archive, key);
        expect(await archive.length(), data.length + 36);
        await BackupCodec.decryptFile(archive, decoded, key);
        expect(await decoded.readAsBytes(), data);
        final encrypted = await archive.readAsBytes();
        expect(await BackupCodec.decrypt(encrypted, key), data);
        await expectLater(
          BackupCodec.decryptFile(
            archive,
            decoded,
            base64UrlEncode(List<int>.filled(32, 99)),
          ),
          throwsA(isA<BusinessException>()),
        );
        expect(await decoded.exists(), isFalse);
        for (final offset in [0, 12, 100000, encrypted.length - 1]) {
          final corrupt = List<int>.from(encrypted)..[offset] ^= 1;
          await archive.writeAsBytes(corrupt);
          await expectLater(
            BackupCodec.decryptFile(archive, decoded, key),
            throwsA(isA<BusinessException>()),
          );
          expect(await decoded.exists(), isFalse);
        }
        await archive.writeAsBytes(
          encrypted.take(encrypted.length - 1).toList(),
        );
        await expectLater(
          BackupCodec.decryptFile(archive, decoded, key),
          throwsA(isA<BusinessException>()),
        );
        expect(await decoded.exists(), isFalse);
        await archive.writeAsBytes(
          await BackupCodec.encrypt(data.take(100).toList(), key),
        );
        await BackupCodec.decryptFile(archive, decoded, key);
        expect(await decoded.readAsBytes(), data.take(100).toList());
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test(
    'New backup identity round-trips and older backups still decrypt',
    () async {
      final key = base64UrlEncode(List<int>.generate(32, (index) => index));
      final data = utf8.encode('shop database');
      final bytes = await BackupCodec.encrypt(data, key);
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(envelope['format'], 'dept_accounting-backup');
      expect(await BackupCodec.decrypt(bytes, key), data);
      envelope['format'] = 'dukan-backup';
      expect(
        await BackupCodec.decrypt(utf8.encode(jsonEncode(envelope)), key),
        data,
      );
      envelope['format'] = 'unrelated-backup';
      await expectLater(
        BackupCodec.decrypt(utf8.encode(jsonEncode(envelope)), key),
        throwsA(isA<BusinessException>()),
      );
    },
  );
}
