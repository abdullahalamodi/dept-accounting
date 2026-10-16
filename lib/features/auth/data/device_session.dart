import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';

class DeviceSession {
  DeviceSession(String databasePath)
    : _file = databasePath == ':memory:' ? null : File('$databasePath.session');

  final File? _file;

  static Future<String> fingerprint(String passwordHash) async =>
      base64Encode((await Sha256().hash(utf8.encode(passwordHash))).bytes);

  Map<String, dynamic>? read() {
    try {
      final file = _file;
      if (file == null || !file.existsSync()) return null;
      return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  void save(String userId, String fingerprint) => _file?.writeAsStringSync(
    jsonEncode({'userId': userId, 'fingerprint': fingerprint}),
    flush: true,
  );

  void clear() {
    final file = _file;
    if (file != null && file.existsSync()) file.deleteSync();
  }
}
