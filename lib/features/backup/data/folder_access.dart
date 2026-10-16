import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/data/store_tasks.dart';

class FolderAccess {
  FolderAccess(this.store);
  final AppStore store;
  static const _channel = MethodChannel('dept_accounting/folder_access');
  Future<void> remember(String setting, String path) async {
    store.require(owner: true);
    final bookmark = Platform.isMacOS
        ? await _channel.invokeMethod<String>('bookmark', {'path': path})
        : null;
    await store.run(StoreTasks.rememberFolder(setting, path, bookmark));
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
          await store.setSettings({
            key: result['path'] as String,
            '${key}_bookmark': result['bookmark'] as String,
          });
        }
      } on PlatformException {
        /* Keep the missing folder visible and retry after reconnect. */
      }
    }
  }
}
