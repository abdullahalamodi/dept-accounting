import 'package:dept_accounting/app/dependencies.dart';
import 'package:dept_accounting/core/data/local_database.dart';
import 'package:dept_accounting/core/numbers.dart';
import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:dept_accounting/features/auth/data/auth_models.dart';
import 'package:dept_accounting/features/finance/presentation/finance_page.dart';
import 'package:dept_accounting/features/invoices/data/document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    d.store.setSetting(
      'shop',
      const Shop(name: 'اختبار', currency: 'YER').toJson(),
    );
  });
  tearDown(() {
    d.backups.dispose();
    d.store.dispose();
    d.store.database.close();
  });

  test(
    'Opening edits and removal preserve linked history and balanced totals',
    () {
      d.finance.openAccount('1100', 10000);
      final original = d.finance.documents().single;
      d.finance.setOpening('1100', 25000);
      expect(d.finance.openingBalances().single.amount, 25000);
      expect(d.engine.balance('1100'), 25000);
      expect(d.engine.balance('3900'), -25000);
      expect(d.corrections.isCancelled(original.id), isTrue);
      expect(d.engine.find(original.id)!.total, 10000);
      final count = d.finance.documents().length;
      d.finance.setOpening('1100', 25000);
      expect(d.finance.documents(), hasLength(count));
      d.finance.removeOpening('1100');
      expect(d.finance.openingBalances(), isEmpty);
      expect(d.engine.balance('1100'), 0);
      expect(d.engine.balance('3900'), 0);
      expect(d.finance.accounts(), hasLength(1));
      d.finance.openAccount('1100', 7000);
      d.reconciliation.closeOpening('مراجعة');
      expect(d.engine.balance('3900'), 0);
      expect(d.engine.balance('3100'), -7000);
      expect(
        () => d.finance.setOpening('1100', 8000),
        throwsA(isA<BusinessException>()),
      );
      expect(
        () => d.finance.removeOpening('1100'),
        throwsA(isA<BusinessException>()),
      );
      expect(d.engine.balance('1100'), 7000);
    },
  );

  test('Account activity locks opening changes including a zero-difference reconciliation', () {
    d.finance.openAccount('1100', 10000);
    d.finance.post(
      requestId: 'spend',
      kind: 'expense',
      category: 'مصاريف',
      payments: const [Payment(account: '1100', amount: 1000)],
    );
    expect(d.finance.canEditOpening('1100'), isFalse);
    expect(
      () => d.finance.setOpening('1100', 20000),
      throwsA(isA<BusinessException>()),
    );
    expect(
      () => d.finance.removeOpening('1100'),
      throwsA(isA<BusinessException>()),
    );
    expect(d.engine.balance('1100'), 9000);
    expect(d.finance.openingBalances().single.amount, 10000);
    d.finance.addAccount('بنك');
    final bank = d.finance.accounts().last.code;
    d.reconciliation.reconcile(
      requestId: 'count',
      account: bank,
      counted: 0,
      reason: 'مراجعة',
    );
    expect(d.finance.canEditOpening(bank), isFalse);
    expect(
      () => d.finance.openAccount(bank, 5000),
      throwsA(isA<BusinessException>()),
    );
  });

  testWidgets(
    'One opening form adds edits removes and closes; accounts use a header dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: DeptAccountingTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: Scaffold(
            body: SingleChildScrollView(child: FinancePage(dependencies: d)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final addAccount = find.text('إضافة حساب');
      expect(
        tester.getCenter(addAccount).dx,
        lessThan(
          tester.getCenter(find.text('إعداد الحسابات وأرصدة البداية')).dx,
        ),
      );
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('الرصيد الفعلي'), findsNothing);
      await tester.tap(addAccount);
      await tester.pumpAndSettle();
      await tester.tap(find.text('إضافة الحساب'));
      await tester.pumpAndSettle();
      expect(find.text('اسم الحساب مطلوب.'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'اسم الحساب'),
        'البنك',
      );
      await tester.tap(find.text('إضافة الحساب'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(d.finance.accounts(), hasLength(2));
      final amount = find.widgetWithText(
        TextFormField,
        'الرصيد الافتتاحي (ر.ي)',
      );
      await tester.enterText(amount, '100');
      await tester.tap(find.text('إضافة رصيد البداية'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('opening-1100')), findsOneWidget);
      await tester.enterText(amount, '250');
      await tester.tap(find.text('حفظ تعديل رصيد البداية'));
      await tester.pumpAndSettle();
      expect(d.finance.openingBalances().single.amount, 25000);
      await tester.tap(find.text('إزالة'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إزالة الرصيد'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('opening-1100')), findsNothing);
      expect(d.finance.accounts(), hasLength(2));
      await tester.enterText(amount, '150');
      await tester.tap(find.text('إضافة رصيد البداية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('اعتماد مراجعة الأرصدة وإقفال الافتتاح'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('إقفال الافتتاح'));
      await tester.pumpAndSettle();
      expect(d.store.setting('opening_closed'), 'true');
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('إزالة'), findsNothing);
      expect(find.text('مطابقة الصندوق'), findsOneWidget);
      expect(d.engine.balance('1100'), 15000);
      expect(d.engine.balance('3900'), 0);
      await tester.tap(find.text('مطابقة الصندوق'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextFormField, 'الرصيد الفعلي'),
        findsOneWidget,
      );
      await tester.tap(find.text('إغلاق'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
