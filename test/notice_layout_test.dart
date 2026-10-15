import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Mobile workspace notices scroll away with the page', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 800);
      for (final scrollBody in [true, false]) {
        final content = Column(
          children: [
            const Text('محتوى الصفحة'),
            const SizedBox(height: 1000),
            DeptAccountingButton(label: 'متابعة العمل', onPressed: () {}),
          ],
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: DeptAccountingTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: DeptAccountingWorkspace(
              key: ValueKey('$width-$scrollBody'),
              destinations: const [(label: 'الرئيسية', icon: Icons.home)],
              selectedIndex: 0,
              onSelected: (_) {},
              scrollBody: scrollBody,
              notice: const Padding(
                padding: EdgeInsets.all(12),
                child: DeptAccountingNotice(title: 'احفظ نسخة خارج الجهاز'),
              ),
              child: scrollBody
                  ? content
                  : Navigator(
                      onGenerateRoute: (_) => MaterialPageRoute<void>(
                        builder: (_) => DeptAccountingPageBody(child: content),
                      ),
                    ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final notice = find.byType(DeptAccountingNotice);
        expect(notice.hitTestable(), findsOneWidget);
        final initialTop = tester.getTopLeft(notice).dy;
        await tester.drag(find.text('محتوى الصفحة'), const Offset(0, -1400));
        await tester.pumpAndSettle();

        if (width < DeptAccountingLayout.compact) {
          expect(notice.hitTestable(), findsNothing);
        } else {
          expect(tester.getTopLeft(notice).dy, initialTop);
        }
        expect(find.text('متابعة العمل').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Mobile notices stay compact and their full text can scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 640), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      for (final tone in [
        DeptAccountingTone.warning,
        DeptAccountingTone.info,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: DeptAccountingTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: DeptAccountingWorkspace(
              destinations: const [(label: 'الرئيسية', icon: Icons.home)],
              selectedIndex: 0,
              onSelected: (_) {},
              notice: Padding(
                padding: const EdgeInsets.all(12),
                child: DeptAccountingNotice(
                  key: ValueKey('$size-$tone'),
                  title: 'احفظ نسخة من بياناتك خارج الجهاز',
                  message: List.filled(
                    20,
                    'يمكنك حفظ نسخة آمنة من بيانات المحل.',
                  ).join('\n'),
                  tone: tone,
                ),
              ),
              child: DeptAccountingButton(
                label: 'متابعة العمل',
                onPressed: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(DeptAccountingNotice)).height,
          lessThanOrEqualTo(size.height * .25),
        );
        final scrollable = find.descendant(
          of: find.byType(DeptAccountingNotice),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(position.maxScrollExtent, greaterThan(0));
        await tester.drag(scrollable, const Offset(0, -2000));
        await tester.pumpAndSettle();
        expect(position.pixels, position.maxScrollExtent);
        expect(find.text('متابعة العمل').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('Short notices shrink and desktop notices show all content', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final width in [390.0, 1200.0]) {
      tester.view.physicalSize = Size(width, 800);
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          home: Scaffold(
            body: DeptAccountingPageBody(
              child: Column(
                children: [
                  const DeptAccountingNotice(title: 'معلومة قصيرة'),
                  DeptAccountingNotice(
                    title: 'تنبيه',
                    message: List.filled(
                      20,
                      'احفظ نسخة خارج الجهاز',
                    ).join('\n'),
                    tone: DeptAccountingTone.warning,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DeptAccountingNotice).first).height,
        lessThan(100),
      );
      expect(
        tester.getSize(find.byType(DeptAccountingNotice).last).height,
        width < DeptAccountingLayout.compact
            ? lessThanOrEqualTo(DeptAccountingLayout.compactNoticeMaxHeight)
            : greaterThan(DeptAccountingLayout.compactNoticeMaxHeight),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
