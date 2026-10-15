import 'dart:convert';

import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/backup/data/backup_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
