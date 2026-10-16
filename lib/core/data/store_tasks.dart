import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import '../../features/auth/data/auth_models.dart';
import '../numbers.dart';
import 'database_task.dart';
import 'local_database.dart';

abstract final class StoreTasks {
  static DatabaseTask<void> login(String username, String password) =>
      DatabaseTask(
        'auth.login',
        (data) => data.store.login(username, password),
        updatesSession: true,
      );
  static DatabaseTask<void> setup({
    required Shop shop,
    required String ownerName,
    required String username,
    required String password,
    required String recovery,
    required String backupKey,
  }) => DatabaseTask(
    'auth.setup',
    (data) => data.store.setup(
      shop: shop,
      ownerName: ownerName,
      username: username,
      password: password,
      recovery: recovery,
      backupKey: backupKey,
    ),
    updatesSession: true,
  );
  static DatabaseTask<void> recover(String code, String password) =>
      DatabaseTask(
        'auth.recover',
        (data) => data.store.recoverOwner(code, password),
      );
  static DatabaseTask<void> password(String current, String next) =>
      DatabaseTask(
        'auth.password',
        (data) => data.store.changePassword(current, next),
      );
  static DatabaseTask<void> saveUser(AppUser user, String password) =>
      DatabaseTask('users.save', (data) => data.store.saveUser(user, password));
  static DatabaseTask<void> profile(String name, String username) =>
      DatabaseTask(
        'profile.save',
        (data) => data.store.updateProfile(name: name, username: username),
      );
  static DatabaseTask<void> shop(Shop shop, String? ownerName) => DatabaseTask(
    'shop.save',
    (data) => data.store.updateShop(shop, ownerName: ownerName),
  );
  static DatabaseTask<void> preference(String key, String value) =>
      DatabaseTask('settings.preference', (data) {
        data.store.require(owner: true);
        if (key != 'pos_enabled') throw ArgumentError.value(key);
        data.store.write(() => data.store.setSetting(key, value));
      });
  static DatabaseTask<void> settings(Map<String, String> values) =>
      DatabaseTask(
        'settings.metadata',
        (data) => data.store.database.transaction(() {
          for (final entry in values.entries) {
            data.store.setSetting(entry.key, entry.value);
          }
        }),
        notify: false,
      );
  static DatabaseTask<void> rememberFolder(
    String setting,
    String path,
    String? bookmark,
  ) => DatabaseTask('backup.folder', (data) {
    data.store.require(owner: true);
    data.store.write(() {
      data.store.setSetting(setting, path);
      if (bookmark != null) {
        data.store.setSetting('${setting}_bookmark', bookmark);
      }
    });
  });
  static DatabaseTask<String> snapshot(String directory) => DatabaseTask(
    'backup.snapshot',
    (data) async =>
        (await data.store.database.snapshot(Directory(directory))).path,
    notify: false,
  );
  static DatabaseTask<void> restore(
    String path,
    String key, {
    required bool existing,
  }) => DatabaseTask('backup.restore', (data) async {
    if (existing) {
      data.store.require(owner: true);
    } else if (data.store.shop != null) {
      throw const BusinessException(
        'يوجد محل على الجهاز. استخدم الاستعادة من حساب المالك.',
      );
    }
    final source = sqlite3.open(path);
    try {
      LocalDatabase.fromHandle(source, path);
      await source.backup(data.store.database.handle, nPage: -1).drain<void>();
    } finally {
      source.close();
    }
    data.store.setSetting('backup_key', key.trim());
    data.store.database.handle.execute(
      "DELETE FROM settings WHERE key IN ('backup_directory','external_backup_directory','backup_directory_bookmark','external_backup_directory_bookmark','backup_at','backup_change','backup_file','external_backup_at','external_backup_change')",
    );
    data.store.revision++;
    data.store.logout();
  }, updatesSession: true);
}
