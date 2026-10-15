import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

abstract final class Passwords {
  static String token([int length = 24]) {
    final random = Random.secure();
    return base64UrlEncode(List.generate(length, (_) => random.nextInt(256)))
        .replaceAll('=', '');
  }

  static Future<String> hash(String password, {String? salt}) async {
    final actualSalt = salt ?? token(16);
    final key =
        await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 210000,
          bits: 256,
        ).deriveKey(
          secretKey: SecretKey(utf8.encode(password)),
          nonce: utf8.encode(actualSalt),
        );
    return '$actualSalt:${base64Encode(await key.extractBytes())}';
  }

  static Future<bool> verify(String password, String stored) async {
    final salt = stored.split(':').first;
    final actual = await hash(password, salt: salt);
    if (actual.length != stored.length) return false;
    var mismatch = 0;
    for (var i = 0; i < actual.length; i++) {
      mismatch |= actual.codeUnitAt(i) ^ stored.codeUnitAt(i);
    }
    return mismatch == 0;
  }
}
