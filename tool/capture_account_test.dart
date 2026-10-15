import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../test/support/load_app_fonts.dart';

void main() {
  testWidgets('Capture profile and settings with illustrative in-memory data', (
    tester,
  ) async {
    const output = String.fromEnvironment('DEPT_ACCOUNTING_CAPTURE_DIR');
    expect(output, isNotEmpty);
    await loadAppFonts();
    final d = AppDependencies(LocalDatabase.memory());
    d.store.setSetting(
      'shop',
      const Shop(
        name: 'بقالة البركة',
        currency: 'SAR',
        phone: '0500000000',
        address: 'الرياض',
      ).toJson(),
    );
    const user = AppUser(
      id: 'owner',
      name: 'أحمد محمد',
      username: 'ahmad',
      role: 'owner',
    );
    d.store.database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
      user.id,
      user.username,
      user.toJson(),
      'unused',
    ]);
    d.store.user = user;
    final key = GlobalKey();
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: DeptAccountingApp(dependencies: d),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(
      tester.element(find.byType(DeptAccountingWorkspace)),
    );

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    router.go('/profile');
    await tester.pumpAndSettle();
    await capture('profile');
    router.go('/settings');
    await tester.pumpAndSettle();
    await capture('settings-shop');
    await tester.tap(
      find.widgetWithText(DeptAccountingFilterChip, 'النسخ الاحتياطية'),
    );
    await tester.pumpAndSettle();
    await capture('settings-backups');
    tester.view.physicalSize = const Size(390, 1200);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    await capture('settings-phone');
    router.go('/profile');
    await tester.pumpAndSettle();
    await capture('profile-phone');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
