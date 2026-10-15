import 'dart:io';
import 'dart:ui' as ui;

import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/presentation/auth_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/load_app_fonts.dart';

void main() {
  testWidgets(
    'Capture registration with the production font families and weights',
    (tester) async {
      const output = String.fromEnvironment('DEPT_ACCOUNTING_CAPTURE_DIR');
      expect(
        output,
        isNotEmpty,
        reason: 'Pass --dart-define=DEPT_ACCOUNTING_CAPTURE_DIR=/absolute/path',
      );
      await loadAppFonts();
      tester.view.physicalSize = const Size(960, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final dependencies = AppDependencies(LocalDatabase.memory());
      addTearDown(() {
        dependencies.backups.dispose();
        dependencies.store.dispose();
        dependencies.store.database.close();
      });
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: DeptAccountingTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: AuthPage(dependencies: dependencies, setup: true),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(output).create(recursive: true);
        await File('$output/registration.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      await tester.pumpWidget(const SizedBox.shrink());
      dependencies.backups.dispose();
    },
  );
}
