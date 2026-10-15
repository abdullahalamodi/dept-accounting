import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        theme: DukanTheme.light(),
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: StatefulBuilder(
              builder: (context, setState) => DukanDataTable(
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
    'Table links stay compact without ink and footer fits narrow text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: DukanTheme.light(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: DukanDataTable(
                  columns: const [DataColumn(label: Text('الإجراء'))],
                  rows: [
                    DataRow(
                      cells: [
                        DataCell(
                          TextButton(
                            onPressed: () => opened = true,
                            child: const Text('التفاصيل'),
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
      final details = find.widgetWithText(TextButton, 'التفاصيل');
      final style = TextButtonTheme.of(tester.element(details)).style!;
      expect(style.splashFactory, NoSplash.splashFactory);
      expect(
        style.overlayColor!.resolve({WidgetState.pressed}),
        Colors.transparent,
      );
      expect(style.textStyle!.resolve({})!.fontSize, 13);
      await tester.tap(details);
      await tester.pump();
      expect(opened, isTrue);
      expect(find.text('صفوف الصفحة'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
