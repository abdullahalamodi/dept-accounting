import 'dart:io';

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/store_tasks.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'remembered login survives reopening; logout and unchecked login clear it',
    () async {
      final directory = await Directory.systemTemp.createTemp('auth-session-');
      final path = '${directory.path}/test.sqlite';
      var d = await AppDependencies.open(path: path);
      try {
        await d.store.setup(
          shop: const Shop(name: 'Test', currency: 'SAR'),
          ownerName: 'Owner',
          username: 'owner',
          password: 'password123',
          recovery: 'recovery',
          backupKey: 'backup',
        );
        d.store.logout();
        await d.store.login('owner', 'password123', rememberMe: true);
        final session = File('$path.session');
        expect(session.existsSync(), true);
        expect(session.readAsStringSync(), isNot(contains('password123')));
        await d.shutdown();
        d = await AppDependencies.open(path: path);
        expect(d.store.user?.username, 'owner');
        d.store.logout();
        expect(session.existsSync(), false);
        await d.shutdown();
        d = await AppDependencies.open(path: path);
        expect(d.store.user, isNull);
        await expectLater(
          d.store.login('owner', 'wrong', rememberMe: true),
          throwsA(isA<BusinessException>()),
        );
        expect(session.existsSync(), false);
        await d.store.login('owner', 'password123');
        await d.shutdown();
        d = await AppDependencies.open(path: path);
        expect(d.store.user, isNull);
      } finally {
        await d.shutdown();
        await directory.delete(recursive: true);
      }
    },
  );

  test('remembered login reloads account state and rejects disabled or changed credentials', () async {
    final directory = await Directory.systemTemp.createTemp(
      'auth-invalid-session-',
    );
    final path = '${directory.path}/test.sqlite';
    var d = await AppDependencies.open(path: path);
    try {
      await d.store.setup(
        shop: const Shop(name: 'Test', currency: 'SAR'),
        ownerName: 'Owner',
        username: 'owner',
        password: 'password123',
        recovery: 'recovery',
        backupKey: 'backup',
      );
      await d.store.run(
        StoreTasks.saveUser(
          const AppUser(
            id: 'seller',
            name: 'Seller',
            username: 'seller',
            role: 'seller',
          ),
          'password123',
        ),
      );
      d.store.logout();
      await d.store.login('seller', 'password123', rememberMe: true);
      await d.shutdown();
      final session = File('$path.session');
      final remembered = session.readAsStringSync();
      d = await AppDependencies.open(path: path);
      expect(d.store.user?.role, 'seller');
      d.store.logout();
      await d.store.login('owner', 'password123');
      await d.store.run(
        StoreTasks.saveUser(
          const AppUser(
            id: 'seller',
            name: 'Seller',
            username: 'seller',
            role: 'seller',
            active: false,
          ),
          '',
        ),
      );
      session.writeAsStringSync(remembered);
      await d.shutdown();
      d = await AppDependencies.open(path: path);
      expect(d.store.user, isNull);
      expect(session.existsSync(), false);
      await d.store.login('owner', 'password123', rememberMe: true);
      await d.store.recoverOwner('recovery', 'replacement-password');
      await d.shutdown();
      d = await AppDependencies.open(path: path);
      expect(d.store.user, isNull);
      expect(session.existsSync(), false);
    } finally {
      await d.shutdown();
      await directory.delete(recursive: true);
    }
  });
}
