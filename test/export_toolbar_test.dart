import 'dart:async';

import 'package:dept_accounting/core/ui/form_widgets.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/invoices/presentation/document_cancellation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/load_app_fonts.dart';

Widget host(Widget child) => MaterialApp(
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: DeptAccountingTheme.light().copyWith(
    platform: TargetPlatform.macOS,
    visualDensity: VisualDensity.compact,
  ),
  home: Scaffold(
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: child,
    ),
  ),
);

void main() {
  setUpAll(loadAppFonts);
  testWidgets('Toolbar reflows and separates document actions from exporting', (
    tester,
  ) async {
    var thermal = false;
    bool? printedThermal;
    var cancelled = false;
    for (final width in [1120.0, 320.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) => DeptAccountingExportToolbar(
              onPrint: () async => printedThermal = thermal,
              onSavePdf: () async => null,
              onShare: () async => null,
              printOptions: SizedBox(
                width: 180,
                child: ChoiceField<bool>(
                  label: 'مقاس الطباعة',
                  value: thermal,
                  items: const [
                    (value: false, label: 'ورق B5'),
                    (value: true, label: 'حراري 80 مم'),
                  ],
                  onChanged: (v) => setState(() => thermal = v!),
                ),
              ),
              actions: [
                DeptAccountingToolbarAction(
                  label: 'إلغاء المستند',
                  icon: Icons.cancel_outlined,
                  destructive: true,
                  onPressed: () => cancelled = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      if (width == 1120) {
        final border = InputDecorator.containerOf(
          tester.element(find.text('ورق B5').first),
        )!;
        final printRect = tester.getRect(find.byType(FilledButton));
        expect(
          border.localToGlobal(Offset.zero).dy,
          closeTo(printRect.top, .01),
        );
        expect(border.size.height, closeTo(printRect.height, .01));
      }
      expect(find.text('إلغاء المستند'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<bool>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حراري 80 مم').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('طباعة'));
      await tester.pumpAndSettle();
      expect(printedThermal, isTrue);
      await tester.tap(find.text('المزيد من الإجراءات'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إلغاء المستند'));
      await tester.pumpAndSettle();
      expect(cancelled, isTrue);
      expect(tester.takeException(), isNull);
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });

  testWidgets('Only the active export loads and other actions are locked', (
    tester,
  ) async {
    final saving = Completer<void>();
    var printed = false;
    await tester.pumpWidget(
      host(
        DeptAccountingExportToolbar(
          onPrint: () async => printed = true,
          onSavePdf: () => saving.future,
          onExcel: () async => null,
        ),
      ),
    );
    await tester.tap(find.text('حفظ PDF'));
    await tester.pump();
    expect(
      find.descendant(
        of: find.widgetWithText(DeptAccountingButton, 'حفظ PDF'),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<DeptAccountingButton>(
            find.widgetWithText(DeptAccountingButton, 'طباعة'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<DeptAccountingButton>(
            find.widgetWithText(DeptAccountingButton, 'تصدير Excel'),
          )
          .onPressed,
      isNull,
    );
    expect(printed, isFalse);
    saving.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await tester.tap(find.text('طباعة'));
    await tester.pumpAndSettle();
    expect(printed, isTrue);
  });

  testWidgets(
    'Cancellation identifies the operation and validates the reason',
    (tester) async {
      for (final allocationsOnly in [false, true]) {
        String? result;
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) => TextButton(
                onPressed: () async => result = await showDialog<String>(
                  context: context,
                  builder: (_) => DocumentCancellationDialog(
                    documentNumber: 'SAL-000001',
                    allocationsOnly: allocationsOnly,
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('المستند: SAL-000001'), findsOneWidget);
        expect(
          find.text(allocationsOnly ? 'إلغاء تخصيص الفواتير' : 'إلغاء المستند'),
          findsOneWidget,
        );
        final confirm = find.text(
          allocationsOnly ? 'تأكيد إلغاء التخصيص' : 'تأكيد إلغاء المستند',
        );
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(find.text('أدخل سبب الإلغاء للمتابعة'), findsOneWidget);
        expect(result, isNull);
        await tester.enterText(find.byType(TextFormField), '  تصحيح خطأ  ');
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(result, 'تصحيح خطأ');
      }
    },
  );
}
