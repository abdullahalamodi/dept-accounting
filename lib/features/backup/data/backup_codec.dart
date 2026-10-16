import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

import '../../../core/numbers.dart';

abstract final class BackupCodec {
  // Accept backups created before the application rename.
  static const supportedExtensions = ['dept_accounting', 'dukan'];
  // File format 2: ChaCha20-Poly1305 with authenticated magic, nonce, ciphertext, MAC.
  // This library implements incremental ChaCha state; its AES stream buffers the file.
  static const _magic = [68, 69, 80, 84, 66, 65, 75, 50]; // DEPTBAK2
  static bool _hasMagic(List<int> bytes) {
    if (bytes.length < _magic.length) return false;
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }

  static SecretKey _key(String key) =>
      SecretKey(base64Url.decode(base64Url.normalize(key.trim())));

  static Future<void> encryptFile(File source, File target, String key) async {
    final cipher = Chacha20.poly1305Aead();
    final nonce = cipher.newNonce();
    Mac? mac;
    final output = await target.open(mode: FileMode.write);
    try {
      await output.writeFrom(_magic);
      await output.writeFrom(nonce);
      await for (final chunk in cipher.encryptStream(
        source.openRead(),
        secretKey: _key(key),
        nonce: nonce,
        aad: _magic,
        onMac: (value) => mac = value,
        allowUseSameBytes: true,
      )) {
        await output.writeFrom(chunk);
      }
      await output.writeFrom(mac!.bytes);
      await output.flush();
    } finally {
      await output.close();
    }
  }

  static Future<void> decryptFile(File source, File target, String key) async {
    try {
      final handle = await source.open();
      late final List<int> prefix, nonce, mac;
      late final int length;
      try {
        prefix = await handle.read(_magic.length);
        length = await handle.length();
        if (_hasMagic(prefix)) {
          if (length < 36) throw const FormatException();
          nonce = await handle.read(12);
          await handle.setPosition(length - 16);
          mac = await handle.read(16);
        }
      } finally {
        await handle.close();
      }
      if (!_hasMagic(prefix)) {
        // Legacy JSON/base64 envelopes are retained for explicit restores.
        await target.writeAsBytes(
          await decrypt(await source.readAsBytes(), key),
          flush: true,
        );
        return;
      }
      final output = await target.open(mode: FileMode.write);
      try {
        await for (final chunk in Chacha20.poly1305Aead().decryptStream(
          source.openRead(20, length - 16),
          secretKey: _key(key),
          nonce: nonce,
          mac: Mac(mac),
          aad: _magic,
          allowUseSameBytes: true,
        )) {
          await output.writeFrom(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
      }
    } catch (e) {
      if (await target.exists()) await target.delete();
      if (e is FileSystemException) rethrow;
      throw const BusinessException(
        'ملف النسخة غير صالح أو مفتاح الاستعادة غير صحيح.',
      );
    }
  }

  static Future<List<int>> encrypt(List<int> bytes, String key) async {
    final box = await AesGcm.with256bits().encrypt(
      bytes,
      secretKey: SecretKey(base64Url.decode(base64Url.normalize(key))),
    );
    return utf8.encode(
      jsonEncode({
        'format': 'dept_accounting-backup',
        'version': 1,
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      }),
    );
  }

  static Future<List<int>> decrypt(List<int> bytes, String key) async {
    try {
      if (_hasMagic(bytes)) {
        if (bytes.length < 36) throw const FormatException();
        return await Chacha20.poly1305Aead().decrypt(
          SecretBox(
            bytes.sublist(20, bytes.length - 16),
            nonce: bytes.sublist(8, 20),
            mac: Mac(bytes.sublist(bytes.length - 16)),
          ),
          secretKey: _key(key),
          aad: _magic,
        );
      }
      final map = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      if ((map['format'] != 'dept_accounting-backup' &&
              map['format'] != 'dukan-backup') ||
          map['version'] != 1) {
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
