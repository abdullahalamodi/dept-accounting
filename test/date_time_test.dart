import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/accounting/data/posting_engine.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDependencies d;
  setUp(() {
    d = AppDependencies(LocalDatabase.memory());
    d.store.user = const AppUser(
      id: 'owner',
      name: 'مالك',
      username: 'owner',
      role: 'owner',
    );
    d.store.database.handle.execute('INSERT INTO users VALUES (?, ?, ?, ?)', [
      'owner',
      'owner',
      d.store.user!.toJson(),
      'test-only',
    ]);
    d.store.setSetting(
      'shop',
      const Shop(name: 'اختبار', currency: 'SAR').toJson(),
    );
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  test('Document dates retain time and reject future timestamps', () {
    final engine = PostingEngine(d.store);
    final selected = DateTime.now().subtract(const Duration(minutes: 1));
    final doc = engine.create(
      id: 'dated',
      kind: 'sale',
      date: selected.toIso8601String(),
    );
    expect(DateTime.parse(doc.date), selected);
    engine.insert(doc, []);
    expect(d.invoices.get(doc.id).date, doc.date);
    final current = engine.create(id: 'default-date', kind: 'receipt');
    expect(current.date, contains('T'));
    expect(
      engine.create(id: 'legacy-date', kind: 'sale', date: '2020-01-15').date,
      '2020-01-15',
    );
    expect(
      () => engine.create(
        id: 'future-date',
        kind: 'sale',
        date: DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      ),
      throwsA(isA<BusinessException>()),
    );
  });

  testWidgets('Date field selects date and time; cancel keeps the value', (
    tester,
  ) async {
    var selected = DateTime(2020, 1, 15, 9, 30);
    await tester.pumpWidget(
      MaterialApp(
        theme: DeptAccountingTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => DeptAccountingDateTimeField(
                value: selected,
                onChanged: (value) => setState(() => selected = value),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('التاريخ'), findsOneWidget);
    expect(find.text('2020-01-15 09:30'), findsOneWidget);
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2020, 1, 15, 9, 30));

    Future<void> openTime({bool changeDate = false}) async {
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      if (changeDate) await tester.tap(find.text('16'));
      await tester.tap(find.text('التالي'));
      await tester.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
    }

    await openTime();
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2020, 1, 15, 9, 30));

    await openTime(changeDate: true);
    final localizations = MaterialLocalizations.of(
      tester.element(find.byType(TimePickerDialog)),
    );
    await tester.tap(find.byTooltip(localizations.inputTimeModeButtonLabel));
    await tester.pumpAndSettle();
    final inputs = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(inputs.first, '10');
    await tester.enterText(inputs.last, '45');
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(selected, DateTime(2020, 1, 16, 10, 45));
    expect(find.text('2020-01-16 10:45'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
