import 'package:dukan_app/core/ui/form_widgets.dart';
import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Login field borders match the action height without icons', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: DukanTheme.light(),
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SectionStack.form(
                children: [
                  const DukanField(label: 'اسم المستخدم'),
                  TextFormField(
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  ),
                  DukanButton(label: 'دخول', onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    expect(
      tester.getTopLeft(fields.at(1)).dy - tester.getBottomLeft(fields.first).dy,
      14,
    );
    final buttonHeight = tester.getSize(find.byType(FilledButton)).height;
    for (final input in find.byType(EditableText).evaluate()) {
      expect(InputDecorator.containerOf(input)!.size.height, buttonHeight);
    }
    await tester.enterText(find.byType(TextFormField).first, 'test');
    await tester.pumpAndSettle();
    expect(
      InputDecorator.containerOf(
        tester.element(find.byType(EditableText).first),
      )!.size.height,
      buttonHeight,
    );
  });

  testWidgets(
    'Shared controls align and dropdown values use regular body type',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: DukanTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 280,
                    child: DukanField(label: 'بحث', prefixIcon: Icons.search),
                  ),
                  SizedBox(
                    width: 280,
                    child: ChoiceField<String>(
                      label: 'العميل',
                      value: 'cash',
                      items: const [
                        (value: 'cash', label: 'بدون عميل — نقدي فقط'),
                        (value: 'customer', label: 'أحمد محمد'),
                      ],
                      onChanged: (_) {},
                    ),
                  ),
                  DukanButton(label: 'إضافة', onPressed: () {}),
                  DukanFilterChip(
                    label: const Text('مخزون منخفض'),
                    selected: false,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final inputHeight = tester.getSize(find.byType(TextFormField)).height;
      expect(inputHeight, DukanLayout.controlHeight);
      expect(
        tester.getSize(find.byType(DropdownButtonFormField<String>)).height,
        inputHeight,
      );
      expect(tester.getSize(find.byType(FilledButton)).height, inputHeight);
      expect(tester.getSize(find.byType(FilterChip)).height, inputHeight);
      final dropdown = tester.widget<DropdownButton<String>>(
        find.byType(DropdownButton<String>),
      );
      expect(dropdown.style?.fontSize, 14);
      expect(dropdown.style?.fontWeight, FontWeight.w400);
      final outline =
          Theme.of(tester.element(find.byType(TextFormField)))
                  .inputDecorationTheme
                  .enabledBorder!
              as OutlineInputBorder;
      expect(outline.borderSide, const BorderSide(color: DukanColors.border));
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      final menuText = tester.element(find.text('أحمد محمد').last);
      expect(DefaultTextStyle.of(menuText).style.fontSize, 14);
      expect(DefaultTextStyle.of(menuText).style.fontWeight, FontWeight.w400);
      expect(tester.takeException(), isNull);
    },
  );
}
