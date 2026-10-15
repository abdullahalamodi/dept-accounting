import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('Mobile notices stay compact and their full text can scroll', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in [const Size(320, 640), const Size(568, 320)]) {
      tester.view.physicalSize = size;
      for (final tone in [DukanTone.warning, DukanTone.info]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: DukanTheme.light(),
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: DukanWorkspace(
              destinations: const [(label: 'الرئيسية', icon: Icons.home)],
              selectedIndex: 0,
              onSelected: (_) {},
              notice: Padding(
                padding: const EdgeInsets.all(12),
                child: DukanNotice(
                  key: ValueKey('$size-$tone'),
                  title: 'احفظ نسخة من بياناتك خارج الجهاز',
                  message: List.filled(
                    20,
                    'يمكنك حفظ نسخة آمنة من بيانات المحل.',
                  ).join('\n'),
                  tone: tone,
                ),
              ),
              child: DukanButton(label: 'متابعة العمل', onPressed: () {}),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byType(DukanNotice)).height,
          lessThanOrEqualTo(size.height * .25),
        );
        final scrollable = find.descendant(
          of: find.byType(DukanNotice),
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
          theme: DukanTheme.light(),
          home: Scaffold(
            body: DukanPageBody(
              child: Column(
                children: [
                  const DukanNotice(title: 'معلومة قصيرة'),
                  DukanNotice(
                    title: 'تنبيه',
                    message: List.filled(
                      20,
                      'احفظ نسخة خارج الجهاز',
                    ).join('\n'),
                    tone: DukanTone.warning,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(DukanNotice).first).height,
        lessThan(100),
      );
      expect(
        tester.getSize(find.byType(DukanNotice).last).height,
        width < DukanLayout.compact
            ? lessThanOrEqualTo(DukanLayout.compactNoticeMaxHeight)
            : greaterThan(DukanLayout.compactNoticeMaxHeight),
      );
      expect(tester.takeException(), isNull);
    }
  });
}
