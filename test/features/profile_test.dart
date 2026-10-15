import 'package:dukan_app/app/dependencies.dart';
import 'package:dukan_app/core/data/app_store.dart';
import 'package:dukan_app/core/data/local_database.dart';
import 'package:dukan_app/core/numbers.dart';
import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:dukan_app/features/auth/data/auth_models.dart';
import 'package:dukan_app/features/auth/data/passwords.dart';
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
      store.updateShop(store.shop!, ownerName: '  مالك محدث  ');
      expect(store.user!.name, 'مالك محدث');
      store.logout();
      await store.login('owner', 'owner-password');
      expect(store.user!.name, 'مالك محدث');
      store.updateShop(store.shop!, ownerName: '');
      expect(store.user!.name, isEmpty);
      expect(store.user!.displayName, 'owner');
      expect(store.user!.username, 'owner');
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
      expect(
        () => store.updateShop(store.shop!, ownerName: 'تغيير ممنوع'),
        throwsA(isA<BusinessException>()),
      );
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
        tester.view.physicalSize = Size(role == 'owner' ? 1440 : 1000, 1200);
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
        if (role == 'seller') {
          expect(find.byTooltip('الملف الشخصي'), findsNothing);
          await tester.tap(find.byTooltip('فتح القائمة'));
          await tester.pumpAndSettle();
        }
        expect(find.text(user.roleLabel), findsOneWidget);
        expect(find.textContaining('واجهة عربية'), findsNothing);
        expect(
          tester.getTopLeft(find.text('مستخدم')).dy,
          greaterThan(tester.view.physicalSize.height / 2),
        );
        await tester.tap(find.byTooltip('الملف الشخصي'));
        await tester.pumpAndSettle();
        if (role == 'seller') {
          expect(
            tester
                .state<ScaffoldState>(find.byType(Scaffold).first)
                .isDrawerOpen,
            isFalse,
          );
        }
        final router = GoRouter.of(tester.element(find.byType(DukanWorkspace)));
        expect(router.routeInformationProvider.value.uri.path, '/profile');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'اسم المستخدم'),
          'new-user',
        );
        await tester.tap(find.text('حفظ اسم المستخدم'));
        await tester.pumpAndSettle();
        expect(d.store.user!.username, 'new-user');
        expect(d.store.user!.name, 'مستخدم');
        expect(find.text('بيانات الحساب'), findsNothing);
        expect(
          find.widgetWithText(TextFormField, 'الاسم الكامل (اختياري)'),
          findsNothing,
        );
        expect(
          find.widgetWithText(TextFormField, 'كلمة المرور الحالية'),
          findsNothing,
        );
        if (role == 'owner') {
          router.go('/settings');
          await tester.pumpAndSettle();
          final fullName = find.widgetWithText(
            TextFormField,
            'الاسم الكامل (اختياري)',
          );
          await tester.enterText(fullName, 'اسم كامل جديد');
          await tester.tap(find.text('حفظ إعدادات المحل'));
          await tester.pumpAndSettle();
          expect(d.store.user!.name, 'اسم كامل جديد');
          expect(
            find.descendant(
              of: find.byTooltip('الملف الشخصي'),
              matching: find.text('اسم كامل جديد'),
            ),
            findsOneWidget,
          );
          await tester.enterText(fullName, '');
          await tester.tap(find.text('حفظ إعدادات المحل'));
          await tester.pumpAndSettle();
          expect(d.store.user!.name, isEmpty);
          expect(d.store.user!.displayName, 'new-user');
          expect(
            find.descendant(
              of: find.byTooltip('الملف الشخصي'),
              matching: find.text('new-user'),
            ),
            findsOneWidget,
          );
          expect(d.store.shop!.name, 'محل تجريبي');
          router.go('/profile');
          await tester.pumpAndSettle();
        }
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

  testWidgets(
    'Password changes validate in a dialog and preserve unsaved username edits',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = AppDependencies(LocalDatabase.memory());
      final hash = await tester.runAsync(() => Passwords.hash('old-password'));
      const user = AppUser(
        id: 'owner',
        name: 'المالك',
        username: 'owner',
        role: 'owner',
      );
      d.store.setSetting(
        'shop',
        const Shop(name: 'محل', currency: 'YER').toJson(),
      );
      d.store.database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
        user.id,
        user.username,
        user.toJson(),
        hash,
      ]);
      d.store.user = user;
      await tester.pumpWidget(DukanApp(dependencies: d));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('الملف الشخصي'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم المستخدم'),
        'unsaved',
      );
      final open = find.widgetWithText(DukanButton, 'تغيير كلمة المرور');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      Future<void> submitPassword() async {
        final button = tester.widget<DukanButton>(
          find.widgetWithText(DukanButton, 'تحديث كلمة المرور'),
        );
        await tester.runAsync(button.onPressed! as Future<void> Function());
        await tester.pumpAndSettle();
      }

      expect(find.byType(AlertDialog), findsOneWidget);
      await submitPassword();
      expect(find.text('أدخل كلمة المرور الحالية.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور الحالية'),
        'wrong-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور الجديدة'),
        'replacement-password',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تأكيد كلمة المرور الجديدة'),
        'mismatch',
      );
      await submitPassword();
      expect(find.text('كلمتا المرور غير متطابقتين.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'تأكيد كلمة المرور الجديدة'),
        'replacement-password',
      );
      await submitPassword();
      expect(find.text('كلمة المرور الحالية غير صحيحة.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'كلمة المرور الحالية'),
        'old-password',
      );
      await submitPassword();
      expect(find.byType(AlertDialog), findsNothing);
      expect(d.store.user!.username, 'owner');
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'اسم المستخدم'),
            )
            .controller!
            .text,
        'unsaved',
      );
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'كلمة المرور الحالية'),
            )
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.text('إلغاء'));
      await tester.pumpAndSettle();
      d.store.logout();
      await tester.runAsync(
        () => d.store.login('owner', 'replacement-password'),
      );
      expect(d.store.user!.id, user.id);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}
