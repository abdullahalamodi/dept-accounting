import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../../../core/numbers.dart';

abstract final class BackupCodec {
  static Future<List<int>> encrypt(List<int> bytes, String key) async {
    final box = await AesGcm.with256bits().encrypt(
      bytes,
      secretKey: SecretKey(base64Url.decode(base64Url.normalize(key))),
    );
    return utf8.encode(
      jsonEncode({
        'format': 'dukan-backup',
        'version': 1,
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      }),
    );
  }

  static Future<List<int>> decrypt(List<int> bytes, String key) async {
    try {
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if (map['format'] != 'dukan-backup' || map['version'] != 1) {
        throw const FormatException();
      }
      return await AesGcm.with256bits().decrypt(
        SecretBox(
          base64Decode(map['data'] as String),
          nonce: base64Decode(map['nonce'] as String),
          mac: Mac(base64Decode(map['mac'] as String)),
        ),
        secretKey: SecretKey(base64Url.decode(base64Url.normalize(key.trim()))),
      );
    } catch (_) {
      throw const BusinessException(
        'ملف النسخة غير صالح أو مفتاح الاستعادة غير صحيح.',
      );
    }
  }
}
