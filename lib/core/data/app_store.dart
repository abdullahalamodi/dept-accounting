import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../features/auth/data/auth_models.dart';
import '../../features/auth/data/passwords.dart';
import '../numbers.dart';
import 'local_database.dart';

class AppStore extends ChangeNotifier {
  AppStore(this.database);
  final LocalDatabase database;
  AppUser? user;
  int revision = 0;
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
  void logout() {
    user = null;
    notifyListeners();
  }

  Future<void> login(String username, String password) async {
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
  }

  Future<void> setup({
    required Shop shop,
    required String ownerName,
    required String username,
    required String password,
    required String recovery,
    required String backupKey,
  }) async {
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

  Future<void> saveUser(AppUser next, String password) async {
    require(owner: true);
    if (next.name.trim().isEmpty ||
        next.username.trim().isEmpty ||
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
    });
  }

  void updateShop(Shop next) {
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
    write(() {
      setSetting('shop', next.toJson());
      audit('تحديث المحل', 'shop');
    });
  }

  Map<String, dynamic> decode(String data) =>
      jsonDecode(data) as Map<String, dynamic>;
}
