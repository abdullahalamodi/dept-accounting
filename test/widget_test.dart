import 'package:dukan_app/design_system/dukan_design_system.dart';
import 'package:dukan_app/design_system/gallery/gallery_patterns.dart';
import 'package:dukan_app/design_system/gallery/design_system_gallery.dart';
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

void viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final width in [360.0, 800.0, 1440.0]) {
    testWidgets('Gallery renders RTL at width $width', (tester) async {
      viewport(tester, Size(width, 1100));
      await tester.pumpWidget(
        MaterialApp(
          theme: DukanTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const DesignSystemGallery(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('تفاصيل مألوفة. تجربة متّسقة.'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.text('تفاصيل مألوفة. تجربة متّسقة.')),
        ),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
      if (width < DukanLayout.expanded) {
        await tester.tap(find.byTooltip('فتح القائمة'));
        await tester.pumpAndSettle();
        expect(find.text('الهوية والألوان'), findsOneWidget);
      }
    });
  }

  testWidgets('Every gallery page fits phone with enlarged text', (
    tester,
  ) async {
    viewport(tester, const Size(390, 1000));
    for (final page in [
      'الهوية والألوان',
      'الخطوط والمسافات',
      'العناصر والنماذج',
      'الجداول والمنتجات',
      'نماذج العمل',
      'الحالات والرسائل',
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: DukanTheme.light(),
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const DesignSystemGallery(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.byTooltip('فتح القائمة'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.scrollUntilVisible(
        find.text(page),
        200,
        scrollable: find
            .descendant(
              of: find.byType(Drawer),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(page));
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: page);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('Product search resets pagination and supports no results', (
    tester,
  ) async {
    viewport(tester, const Size(1200, 1200));
    await tester.pumpWidget(host(const GalleryProducts()));
    await tester.pumpAndSettle();
    expect(find.text('1–5 من 8'), findsOneWidget);
    await tester.tap(find.byTooltip('الصفحة التالية'));
    await tester.pumpAndSettle();
    expect(find.text('6–8 من 8'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '6281000000012');
    await tester.pumpAndSettle();
    expect(find.text('أرز بسمتي 5 كجم'), findsOneWidget);
    expect(find.text('1–1 من 1'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'غير موجود');
    await tester.pumpAndSettle();
    expect(find.text('لا توجد نتائج'), findsOneWidget);
    expect(find.text('0–0 من 0'), findsOneWidget);
  });

  testWidgets('Form validates and clears errors after valid save', (
    tester,
  ) async {
    viewport(tester, const Size(1400, 1600));
    await tester.pumpWidget(host(const GalleryControls()));
    await tester.pump();
    await tester.tap(find.text('معاينة الحفظ'));
    await tester.pump();
    expect(find.text('أدخل اسم المنتج للمتابعة.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'أرز');
    await tester.tap(find.text('معاينة الحفظ'));
    await tester.pump();
    expect(find.text('أدخل اسم المنتج للمتابعة.'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(
      find.text('اكتملت معاينة الحفظ. لم تُحفظ بيانات فعلية.'),
      findsOneWidget,
    );
  });

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

  testWidgets('Invoice picker adds a different product and updates total', (
    tester,
  ) async {
    viewport(tester, const Size(1500, 1400));
    await tester.pumpWidget(host(const GalleryWorkflows()));
    await tester.pumpAndSettle();
    expect(find.text('12,000'), findsOneWidget);
    await tester.tap(find.text('إضافة منتجات'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'سكر');
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();
    expect(find.text('سكر أبيض 1 كجم'), findsOneWidget);
    expect(find.text('12,950'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
