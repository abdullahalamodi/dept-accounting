import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: DeptAccountingTheme.light(),
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
            const DeptAccountingButton(label: 'معطل'),
            DeptAccountingButton(
              label: 'حفظ',
              loading: true,
              onPressed: () => calls++,
            ),
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
          builder: (context) => DeptAccountingButton(
            label: 'افتح',
            onPressed: () async {
              result = await showDeptAccountingConfirmation(
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

    for (final tone in DeptAccountingTone.values) {
      expect(
        contrast(tone.foreground, tone.background),
        greaterThanOrEqualTo(4.5),
        reason: tone.name,
      );
    }
    expect(
      contrast(DeptAccountingColors.primary, Colors.white),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(DeptAccountingColors.muted, DeptAccountingColors.background),
      greaterThanOrEqualTo(4.5),
    );
    expect(DeptAccountingColors.controlBorder, DeptAccountingColors.border);
  });
}
