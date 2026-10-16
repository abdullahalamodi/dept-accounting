import 'dart:convert';
import 'dart:io';

import '../../app/app_data.dart';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/data/device_session.dart';
import '../../features/auth/data/passwords.dart';
import '../../features/auth/data/username.dart';
import '../numbers.dart';
import 'local_database.dart';
import 'database_executor.dart';
import 'database_task.dart';
import 'store_tasks.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.database);
  final LocalDatabase database;
  AppUser? user;
  int revision = 0;
  int sessionEpoch = 0;
  DatabaseExecutor? executor;
  Future<T> run<T>(DatabaseTask<T> task) => executor == null
      ? Future.sync(() => task.run(AppData.fromStore(this)))
      : executor!.run(task);

  void acceptWorkerState(
    AppUser? nextUser, {
    required bool changed,
    required bool notify,
    required bool updatesSession,
    required int requestEpoch,
    required String? requestedUserId,
  }) {
    final previous = user?.toJson();
    if (requestEpoch == sessionEpoch &&
        (updatesSession || user?.id == requestedUserId)) {
      user = nextUser?.active == true ? nextUser : null;
    }
    if (changed) revision++;
    if ((changed && notify) || previous != user?.toJson()) notifyListeners();
  }

  Future<void> setSettings(Map<String, String> values) =>
      run(StoreTasks.settings(values));
  Future<File> snapshot(Directory directory) async =>
      File(await run(StoreTasks.snapshot(directory.path)));
  Shop? get shop {
    final value = setting('shop');
    return value == null ? null : ShopMapper.fromJson(value);
  }

  String? setting(String key) {
    final rows = database.handle.select(
      'SELECT value FROM settings WHERE key = ?',
      [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String value) => database.handle.execute(
    'INSERT INTO settings VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value',
    [key, value],
  );
  void require({bool manage = false, bool owner = false}) {
    if (user == null ||
        !user!.active ||
        (manage && !user!.canManage) ||
        (owner && !user!.isOwner)) {
      throw const BusinessException('لا تملك صلاحية تنفيذ هذه العملية.');
    }
  }

  T write<T>(T Function() body, {bool notify = true}) {
    final result = database.transaction(() {
      final result = body();
      setSetting('changed_at', DateTime.now().toUtc().toIso8601String());
      return result;
    });
    revision++;
    if (notify) notifyListeners();
    return result;
  }

  void audit(String action, String entity, [String details = '']) =>
      database.handle.execute(
        'INSERT INTO audit(user_id, at, action, entity, details) VALUES (?, ?, ?, ?, ?)',
        [
          user?.id,
          DateTime.now().toUtc().toIso8601String(),
          action,
          entity,
          details,
        ],
      );
  String id() => Passwords.token(18);
  DeviceSession get _deviceSession => DeviceSession(database.path);

  Future<void> restoreSession() async {
    final epoch = sessionEpoch;
    final saved = _deviceSession.read();
    if (saved == null) return;
    final rows = database.handle.select(
      'SELECT data, password FROM users WHERE id = ?',
      [saved['userId'] is String ? saved['userId'] : ''],
    );
    if (rows.isNotEmpty) {
      final candidate = AppUserMapper.fromJson(rows.first['data'] as String);
      final fingerprint = await DeviceSession.fingerprint(
        rows.first['password'] as String,
      );
      if (epoch != sessionEpoch) return;
      if (candidate.active && saved['fingerprint'] == fingerprint) {
        user = candidate;
        notifyListeners();
        return;
      }
    }
    _deviceSession.clear();
  }

  void logout() {
    _deviceSession.clear();
    sessionEpoch++;
    user = null;
    notifyListeners();
  }

  Future<void> login(
    String username,
    String password, {
    bool rememberMe = false,
  }) async {
    final epoch = sessionEpoch;
    if (executor?.isRemote == true) {
      await run(StoreTasks.login(username, password));
      if (epoch == sessionEpoch) await _rememberSession(rememberMe, epoch);
      return;
    }
    final rows = database.handle.select(
      'SELECT * FROM users WHERE username = ? COLLATE NOCASE',
      [username.trim()],
    );
    if (rows.isEmpty ||
        !await Passwords.verify(password, rows.first['password'] as String)) {
      throw const BusinessException('اسم المستخدم أو كلمة المرور غير صحيحة.');
    }
    final result = AppUserMapper.fromJson(rows.first['data'] as String);
    if (!result.active) {
      throw const BusinessException('الحساب موقوف؛ راجع المالك.');
    }
    user = result;
    write(() => audit('تسجيل الدخول', result.id));
    if (epoch == sessionEpoch) await _rememberSession(rememberMe, epoch);
  }

  Future<void> _rememberSession(bool rememberMe, int epoch) async {
    if (!rememberMe) {
      _deviceSession.clear();
      return;
    }
    final actor = user;
    if (actor == null) return;
    final rows = database.handle.select(
      'SELECT password FROM users WHERE id = ?',
      [actor.id],
    );
    if (rows.isEmpty) return;
    final fingerprint = await DeviceSession.fingerprint(
      rows.first['password'] as String,
    );
    if (epoch == sessionEpoch && user?.id == actor.id) {
      _deviceSession.save(actor.id, fingerprint);
    }
  }

  Future<void> setup({
    required Shop shop,
    required String ownerName,
    required String username,
    required String password,
    required String recovery,
    required String backupKey,
  }) async {
    if (executor?.isRemote == true) {
      return run(
        StoreTasks.setup(
          shop: shop,
          ownerName: ownerName,
          username: username,
          password: password,
          recovery: recovery,
          backupKey: backupKey,
        ),
      );
    }
    if (this.shop != null) {
      throw const BusinessException('تم إعداد المحل مسبقًا.');
    }
    if (shop.name.trim().isEmpty ||
        ownerName.trim().isEmpty ||
        username.trim().isEmpty ||
        password.length < 8) {
      throw const BusinessException(
        'أكمل بيانات المحل والمالك وكلمة مرور من 8 أحرف على الأقل.',
      );
    }
    if (!['YER', 'SAR'].contains(shop.currency)) {
      throw const BusinessException('اختر عملة المحل.');
    }
    final usernameError = Username.validate(username);
    if (usernameError != null) throw BusinessException(usernameError);
    final passwordHash = await Passwords.hash(password);
    final recoveryHash = await Passwords.hash(recovery);
    final owner = AppUser(
      id: id(),
      name: ownerName.trim(),
      username: username.trim(),
      role: 'owner',
    );
    write(() {
      setSetting('shop', shop.toJson());
      setSetting('recovery', recoveryHash);
      setSetting('backup_key', backupKey);
      setSetting('startup_guide_visible', 'true');
      database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
        owner.id,
        owner.username,
        owner.toJson(),
        passwordHash,
      ]);
      audit('إعداد المحل', owner.id);
    });
    user = owner;
    notifyListeners();
  }

  Future<void> recoverOwner(String code, String password) async {
    if (executor?.isRemote == true) {
      return run(StoreTasks.recover(code, password));
    }
    if (password.length < 8) {
      throw const BusinessException('كلمة المرور 8 أحرف على الأقل.');
    }
    final hash = setting('recovery');
    if (hash == null || !await Passwords.verify(code.trim(), hash)) {
      throw const BusinessException('رمز الاسترداد غير صحيح.');
    }
    final next = await Passwords.hash(password);
    write(() {
      final owner = database.handle
          .select(
            "SELECT * FROM users WHERE json_extract(data, '\$.role') = 'owner'",
          )
          .first;
      database.handle.execute('UPDATE users SET password = ? WHERE id = ?', [
        next,
        owner['id'],
      ]);
      audit('استرداد دخول المالك', owner['id'] as String);
    });
  }

  List<AppUser> users() {
    require(owner: true);
    return database.handle
        .select('SELECT data FROM users')
        .map((r) => AppUserMapper.fromJson(r['data'] as String))
        .toList();
  }

  void updateProfile({required String name, required String username}) {
    require();
    final actor = user!;
    final usernameError = Username.validate(username);
    if (usernameError != null) throw BusinessException(usernameError);
    final duplicate = database.handle.select(
      'SELECT id FROM users WHERE username = ? COLLATE NOCASE AND id != ?',
      [username.trim(), actor.id],
    );
    if (duplicate.isNotEmpty) {
      throw const BusinessException(
        'اسم المستخدم مستخدم بالفعل. اختر اسمًا آخر.',
      );
    }
    final row = database.handle.select('SELECT data FROM users WHERE id = ?', [
      actor.id,
    ]);
    if (row.isEmpty) {
      throw const BusinessException(
        'تعذر العثور على الحساب. سجل الدخول مجددًا.',
      );
    }
    final next = AppUserMapper.fromJson(row.first['data'] as String)
        .copyWith(name: name.trim(), username: username.trim());
    write(() {
      database.handle.execute(
        'UPDATE users SET username = ?, data = ? WHERE id = ?',
        [next.username, next.toJson(), next.id],
      );
      audit('تحديث الملف الشخصي', next.id);
    }, notify: false);
    user = next;
    notifyListeners();
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (executor?.isRemote == true) {
      return run(StoreTasks.password(currentPassword, newPassword));
    }
    require();
    final actorId = user!.id;
    if (newPassword.length < 8) {
      throw const BusinessException('كلمة المرور 8 أحرف على الأقل.');
    }
    final row = database.handle.select(
      'SELECT password FROM users WHERE id = ?',
      [actorId],
    );
    if (row.isEmpty ||
        !await Passwords.verify(
          currentPassword,
          row.first['password'] as String,
        )) {
      throw const BusinessException('كلمة المرور الحالية غير صحيحة.');
    }
    final hash = await Passwords.hash(newPassword);
    require();
    if (user!.id != actorId) {
      throw const BusinessException('تغيرت الجلسة. سجل الدخول مجددًا.');
    }
    write(() {
      database.handle.execute('UPDATE users SET password = ? WHERE id = ?', [
        hash,
        actorId,
      ]);
      audit('تغيير كلمة المرور', actorId);
    });
  }

  Future<void> saveUser(AppUser next, String password) async {
    if (executor?.isRemote == true) {
      return run(StoreTasks.saveUser(next, password));
    }
    require(owner: true);
    final usernameError = Username.validate(next.username);
    if (usernameError != null) throw BusinessException(usernameError);
    if (next.username.trim().isEmpty ||
        !['owner', 'seller', 'accountant'].contains(next.role) ||
        next.discountLimit < 0 ||
        next.discountLimit > 100) {
      throw const BusinessException('بيانات المستخدم غير صحيحة.');
    }
    final existing = database.handle.select(
      'SELECT data FROM users WHERE id = ?',
      [next.id],
    );
    if (next.role == 'owner' && next.id != user!.id) {
      throw const BusinessException('لا يمكن إنشاء مالك ثانٍ.');
    }
    if (existing.isNotEmpty &&
        AppUserMapper.fromJson(existing.first['data'] as String).isOwner &&
        (next.role != 'owner' || !next.active)) {
      throw const BusinessException('لا يمكن إيقاف المالك أو تغيير دوره.');
    }
    if ((existing.isEmpty || password.isNotEmpty) && password.length < 8) {
      throw const BusinessException('كلمة المرور 8 أحرف على الأقل.');
    }
    final hash = password.isEmpty ? null : await Passwords.hash(password);
    write(() {
      if (existing.isEmpty) {
        database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
          next.id,
          next.username,
          next.toJson(),
          hash,
        ]);
      } else {
        database.handle.execute(
          'UPDATE users SET username = ?, data = ? WHERE id = ?',
          [next.username, next.toJson(), next.id],
        );
        if (hash != null) {
          database.handle.execute(
            'UPDATE users SET password = ? WHERE id = ?',
            [hash, next.id],
          );
        }
      }
      audit('حفظ مستخدم', next.id);
    }, notify: false);
    if (user?.id == next.id) user = next;
    notifyListeners();
  }

  void updateShop(Shop next, {String? ownerName}) {
    require(owner: true);
    if (next.name.trim().isEmpty) {
      throw const BusinessException('اسم المحل مطلوب.');
    }
    if (!['YER', 'SAR'].contains(next.currency)) {
      throw const BusinessException('العملة غير مدعومة.');
    }
    if (next.currency != shop!.currency &&
        database.handle.select('SELECT id FROM journal LIMIT 1').isNotEmpty) {
      throw const BusinessException(
        'لا يمكن تغيير العملة بعد أول عملية مالية.',
      );
    }
    final owner = ownerName == null
        ? null
        : user!.copyWith(name: ownerName.trim());
    write(() {
      setSetting('shop', next.toJson());
      if (owner != null) {
        database.handle.execute('UPDATE users SET data = ? WHERE id = ?', [
          owner.toJson(),
          owner.id,
        ]);
        audit('تحديث الملف الشخصي', owner.id);
      }
      audit('تحديث المحل', 'shop');
    }, notify: false);
    if (owner != null) user = owner;
    notifyListeners();
  }

  Map<String, dynamic> decode(String data) =>
      jsonDecode(data) as Map<String, dynamic>;
}
