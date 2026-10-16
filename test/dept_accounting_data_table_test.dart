import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/core/ui/form_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/load_app_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('Pagination selects pages, bounds navigation and changes size', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var page = 10;
    var pageSize = 5;
    await tester.pumpWidget(
      MaterialApp(
        theme: DeptAccountingTheme.light(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setState) => DeptAccountingDataTable(
                columns: const [DataColumn(label: Text('المنتج'))],
                rows: const [
                  DataRow(cells: [DataCell(Text('حليب'))]),
                ],
                totalRows: 100,
                page: page,
                pageSize: pageSize,
                onPageChanged: (value) => setState(() => page = value),
                onPageSizeChanged: (value) => setState(() {
                  pageSize = value;
                  page = 1;
                }),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('عرض 46–50 من 100'), findsOneWidget);
    final selector = find.byType(DropdownButton<int>);
    final previous = find.widgetWithText(TextButton, 'السابق');
    expect(find.text('…'), findsNWidgets(2));
    await tester.tap(find.widgetWithText(TextButton, 'التالي'));
    await tester.pump();
    expect(page, 11);
    await tester.tap(find.widgetWithText(TextButton, 'السابق'));
    await tester.pump();
    expect(page, 10);
    await tester.tap(find.widgetWithText(TextButton, '20'));
    await tester.pump();
    expect(find.text('عرض 96–100 من 100'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'التالي'))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('20').last);
    await tester.pumpAndSettle();
    expect(pageSize, 20);
    final dropdown = tester.widget<DropdownButton<int>>(selector);
    final dropdownTheme = Theme.of(tester.element(selector));
    expect(dropdown.focusColor ?? dropdownTheme.focusColor, Colors.transparent);
    expect(dropdownTheme.highlightColor, Colors.transparent);
    expect(dropdownTheme.splashFactory, NoSplash.splashFactory);
    expect(
      tester
          .getSize(
            find
                .ancestor(of: selector, matching: find.byType(DecoratedBox))
                .first,
          )
          .height,
      tester.getSize(previous).height,
    );
    expect(page, 1);
    expect(find.text('عرض 1–20 من 100'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'السابق'))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Primary table actions work and footer fits narrow enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: DeptAccountingDataTable(
                  columns: const [DataColumn(label: Text('الإجراء'))],
                  rows: [
                    DataRow(
                      cells: [
                        DataCell(
                          DeptAccountingButton.table(
                            onPressed: () => opened = true,
                            label: 'التفاصيل',
                          ),
                        ),
                      ],
                    ),
                  ],
                  totalRows: 500,
                  page: 50,
                  pageSize: 5,
                  onPageChanged: (_) {},
                  onPageSizeChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      final details = find.widgetWithText(FilledButton, 'التفاصيل');
      final button = tester.widget<FilledButton>(details);
      expect(button.style!.textStyle!.resolve({})!.fontSize, 13);
      final theme = FilledButtonTheme.of(tester.element(details)).style!;
      expect(theme.backgroundColor!.resolve({}), DeptAccountingColors.primary);
      expect(
        theme.backgroundColor!.resolve({WidgetState.hovered}),
        DeptAccountingColors.primaryHover,
      );
      await tester.tap(details);
      await tester.pump();
      expect(opened, isTrue);
      expect(find.text('صفوف الصفحة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Compact actions match field and dropdown heights', (
    tester,
  ) async {
    for (final scale in [1.0, 1.5, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light().copyWith(
            platform: TargetPlatform.macOS,
            visualDensity: VisualDensity.compact,
          ),
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const DeptAccountingField(label: '', compact: true),
                      ChoiceField(
                        label: '',
                        compact: true,
                        value: 'unit',
                        items: const [(value: 'unit', label: 'حبة')],
                        onChanged: (_) {},
                      ),
                      DeptAccountingButton.table(
                        label: 'تعديل',
                        icon: Icons.edit_outlined,
                        onPressed: () {},
                      ),
                      const DeptAccountingButton.table(
                        label: 'حفظ',
                        loading: true,
                      ),
                      DeptAccountingIconButton.table(
                        tooltip: 'إزالة',
                        icon: Icons.close,
                        onPressed: () {},
                      ),
                      for (final variant in DeptAccountingButtonVariant.values)
                        DeptAccountingButton(
                          label: 'normal-${variant.name}',
                          variant: variant,
                          onPressed: () {},
                        ),
                      FilledButton(
                        onPressed: () {},
                        child: const Text('filled'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('outlined'),
                      ),
                      TextButton(onPressed: () {}, child: const Text('text')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final fieldHeight = tester.getSize(find.byType(TextFormField)).height;
      expect(
        tester.getSize(find.byType(DropdownButtonFormField<String>)).height,
        closeTo(fieldHeight, .01),
      );
      for (final action in [
        find.widgetWithText(FilledButton, 'تعديل'),
        find.widgetWithText(FilledButton, 'حفظ'),
        find.byType(IconButton),
      ]) {
        expect(
          tester
              .getSize(
                find
                    .descendant(of: action, matching: find.byType(Material))
                    .first,
              )
              .height,
          closeTo(fieldHeight, .01),
          reason: "scale=$scale action=$action",
        );
      }
      if (scale == 1) {
        expect(fieldHeight, 36);
        final icon = tester.widget<IconButton>(find.byType(IconButton));
        expect(find.byTooltip('إزالة'), findsOneWidget);
        expect(
          icon.style?.backgroundColor?.resolve({}) ?? Colors.transparent,
          Colors.transparent,
        );
        expect(
          icon.style!.foregroundColor!.resolve({}),
          DeptAccountingColors.primary,
        );
        for (final label in [
          ...DeptAccountingButtonVariant.values.map((v) => 'normal-${v.name}'),
          'filled',
          'outlined',
          'text',
        ]) {
          final material = find
              .ancestor(of: find.text(label), matching: find.byType(Material))
              .first;
          expect(tester.getSize(material).height, 48, reason: label);
        }
      }
      expect(tester.takeException(), isNull);
    }
  });
}
