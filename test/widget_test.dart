import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: DukanTheme.light(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('Disabled and loading buttons never dispatch actions', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      host(
        Column(
          children: [
            const DukanButton(label: 'معطل'),
            DukanButton(label: 'حفظ', loading: true, onPressed: () => calls++),
          ],
        ),
      ),
    );
    await tester.tap(find.text('معطل'));
    await tester.tap(find.text('حفظ'));
    expect(calls, 0);
  });

  testWidgets('Destructive confirmation requires explicit action', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => DukanButton(
            label: 'افتح',
            onPressed: () async {
              result = await showDukanConfirmation(
                context,
                title: 'حذف؟',
                message: 'مسودة توضيحية',
                confirmLabel: 'حذف',
                destructive: true,
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العودة'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('افتح'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حذف'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  test('Semantic text/background pairs meet 4.5 contrast', () {
    double contrast(Color a, Color b) {
      final first = a.computeLuminance();
      final second = b.computeLuminance();
      return first > second
          ? (first + .05) / (second + .05)
          : (second + .05) / (first + .05);
    }

    for (final tone in DukanTone.values) {
      expect(
        contrast(tone.foreground, tone.background),
        greaterThanOrEqualTo(4.5),
        reason: tone.name,
      );
    }
    expect(
      contrast(DukanColors.primary, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DukanColors.muted, DukanColors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(DukanColors.controlBorder, DukanColors.border);
  });
}
