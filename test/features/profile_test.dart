import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/app_store.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/core/numbers.dart';
import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('Self-service changes preserve permissions and require the current password', () async {
    final store = AppStore(LocalDatabase.memory());
    try {
      await store.setup(
        shop: const Shop(name: 'محل', currency: 'YER'),
        ownerName: 'المالك',
        username: 'owner',
        password: 'owner-password',
        recovery: 'recovery',
        backupKey: 'backup',
      );
      await store.saveUser(store.user!.copyWith(name: 'مالك محدث'), '');
      expect(store.user!.name, 'مالك محدث');
      await store.saveUser(
        const AppUser(
          id: 'seller',
          name: 'البائع',
          username: 'seller',
          role: 'seller',
          discountLimit: 5,
        ),
        'seller-password',
      );
      await store.login('seller', 'seller-password');
      expect(
        () => store.updateProfile(name: 'اسم', username: 'OWNER'),
        throwsA(isA<BusinessException>()),
      );
      store.updateProfile(name: 'أحمد', username: 'ahmad');
      expect(store.user!.name, 'أحمد');
      expect(store.user!.role, 'seller');
      expect(store.user!.discountLimit, 5);
      expect(() => store.users(), throwsA(isA<BusinessException>()));
      await expectLater(
        store.changePassword('wrong-password', 'replacement-password'),
        throwsA(isA<BusinessException>()),
      );
      await store.changePassword('seller-password', 'replacement-password');
      store.logout();
      await expectLater(
        store.login('seller', 'seller-password'),
        throwsA(isA<BusinessException>()),
      );
      await store.login('ahmad', 'replacement-password');
      expect(store.user!.id, 'seller');
      expect(store.user!.canChangePrice, isFalse);
    } finally {
      store.dispose();
      store.database.close();
    }
  });

  testWidgets(
    'Every role opens its profile, saves details, and logs out from the profile',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final role in ['owner', 'seller']) {
        final d = AppDependencies(LocalDatabase.memory());
        d.store.setSetting(
          'shop',
          const Shop(name: 'محل تجريبي', currency: 'YER').toJson(),
        );
        final user = AppUser(
          id: 'user',
          name: 'مستخدم',
          username: 'user',
          role: role,
        );
        d.store.database.handle.execute(
          'INSERT INTO users VALUES (?, ?, ?, ?)',
          [user.id, user.username, user.toJson(), 'unused'],
        );
        d.store.user = user;
        await tester.pumpWidget(DukanApp(dependencies: d));
        await tester.pumpAndSettle();
        expect(find.text('قفل الجلسة'), findsNothing);
        await tester.tap(find.byTooltip('الملف الشخصي'));
        await tester.pumpAndSettle();
        final router = GoRouter.of(tester.element(find.byType(DukanWorkspace)));
        expect(router.routeInformationProvider.value.uri.path, '/profile');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'الاسم'),
          'اسم جديد',
        );
        await tester.tap(find.text('حفظ بيانات الحساب'));
        await tester.pumpAndSettle();
        expect(d.store.user!.name, 'اسم جديد');
        if (role == 'seller') {
          router.go('/settings');
          await tester.pumpAndSettle();
          expect(router.routeInformationProvider.value.uri.path, '/');
          router.go('/profile');
          await tester.pumpAndSettle();
        }
        final logout = find.widgetWithText(DukanButton, 'تسجيل الخروج');
        await tester.ensureVisible(logout);
        await tester.tap(logout);
        await tester.pumpAndSettle();
        expect(d.store.user, isNull);
        expect(router.routeInformationProvider.value.uri.path, '/login');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      }
    },
  );
}
