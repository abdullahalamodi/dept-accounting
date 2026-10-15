import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';

class FolderAccess {
  FolderAccess(this.store);
  final AppStore store;
  static const _channel = MethodChannel('dept_accounting/folder_access');
  Future<void> remember(String setting, String path) async {
    store.require(owner: true);
    final bookmark = Platform.isMacOS
        ? await _channel.invokeMethod<String>('bookmark', {'path': path})
        : null;
    store.write(() {
      store.setSetting(setting, path);
      if (bookmark != null) store.setSetting('${setting}_bookmark', bookmark);
    });
  }

  Future<void> restore() async {
    if (!Platform.isMacOS) return;
    for (final key in ['backup_directory', 'external_backup_directory']) {
      final bookmark = store.setting('${key}_bookmark');
      if (bookmark == null) continue;
      try {
        final result = await _channel.invokeMapMethod<String, dynamic>(
          'resolve',
          {'bookmark': bookmark},
        );
        if (result != null) {
          store.setSetting(key, result['path'] as String);
          store.setSetting('${key}_bookmark', result['bookmark'] as String);
        }
      } on PlatformException {
        /* Keep the missing folder visible and retry after reconnect. */
      }
    }
  }
}
