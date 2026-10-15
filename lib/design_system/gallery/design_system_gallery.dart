import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../dukan_design_system.dart';
import 'gallery_patterns.dart';

@Preview(name: 'Dukan desktop', group: 'Design system', size: Size(1440, 1000))
@Preview(name: 'Dukan phone', group: 'Design system', size: Size(390, 844))
Widget dukanGalleryPreview() => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: DukanTheme.light(),
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: const DesignSystemGallery(),
);

class DesignSystemGallery extends StatefulWidget {
  const DesignSystemGallery({super.key});

  @override
  State<DesignSystemGallery> createState() => _DesignSystemGalleryState();
}

class _DesignSystemGalleryState extends State<DesignSystemGallery> {
  int _selected = 0;
  static const _destinations = <DukanDestination>[
    (label: 'نظرة عامة', icon: Icons.grid_view_outlined),
    (label: 'الهوية والألوان', icon: Icons.palette_outlined),
    (label: 'الخطوط والمسافات', icon: Icons.text_fields),
    (label: 'العناصر والنماذج', icon: Icons.tune),
    (label: 'الجداول والمنتجات', icon: Icons.table_chart_outlined),
    (label: 'نماذج العمل', icon: Icons.receipt_long_outlined),
    (label: 'الحالات والرسائل', icon: Icons.info_outline),
  ];

  @override
  Widget build(BuildContext context) => DukanWorkspace(
    destinations: _destinations,
    selectedIndex: _selected,
    onSelected: (i) => setState(() => _selected = i),
    title: _destinations[_selected].label,
    child: switch (_selected) {
      0 => _Overview(
        onExplore: () => setState(() => _selected = 3),
        onPattern: () => setState(() => _selected = 5),
      ),
      1 => const _Foundations(),
      2 => const _Typography(),
      3 => const GalleryControls(),
      4 => const GalleryProducts(),
      5 => const GalleryWorkflows(),
      _ => const GalleryStates(),
    },
  );
}

class GalleryStack extends StatelessWidget {
  const GalleryStack({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 24),
        children[i],
      ],
    ],
  );
}

class GalleryGrid extends StatelessWidget {
  const GalleryGrid({super.key, required this.children, this.minWidth = 260});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final columns = ((size.maxWidth + 16) / (minWidth + 16)).floor().clamp(
        1,
        4,
      );
      final width = (size.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: children
            .map((child) => SizedBox(width: width, child: child))
            .toList(),
      );
    },
  );
}

class _Overview extends StatelessWidget {
  const _Overview({required this.onExplore, required this.onPattern});
  final VoidCallback onExplore;
  final VoidCallback onPattern;

  @override
  Widget build(BuildContext context) => GalleryStack(
    children: [
      const DukanPageHeader(
        title: 'تفاصيل مألوفة. تجربة متّسقة.',
        description: 'نظام تصميم دكّان · مستمد من واجهة إدارة المحل',
      ),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: DukanColors.primary,
          borderRadius: BorderRadius.circular(DukanLayout.panelRadius),
        ),
        child: LayoutBuilder(
          builder: (context, size) {
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'دكّان / نظام التصميم',
                  style: TextStyle(color: DukanColors.sage, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Text(
                  'كل تفاصيل محلك،\nبلغة تصميم واحدة.',
                  style: Theme.of(context).textTheme.headlineLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                const Text(
                  'عناصر عملية للبيع والمخزون والحسابات.\nعربية من أول عنوان إلى آخر رقم في الفاتورة.',
                  style: TextStyle(color: Colors.white, height: 1.9),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                  ),
                  onPressed: onExplore,
                  child: const Text('استكشف العناصر'),
                ),
              ],
            );
            final receipt = Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(DukanLayout.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'فاتورة بيع',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const DukanStatusTag('معتمدة', tone: DukanTone.success),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'INV-1048  ·  بقالة الحي',
                    style: TextStyle(color: DukanColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const _ReceiptRow('أرز بسمتي · 2 كيس', '8,400'),
                  const _ReceiptRow('حليب طويل الأجل · 6 حبات', '3,600'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: DukanColors.sage,
                      borderRadius: BorderRadius.circular(
                        DukanLayout.smallRadius,
                      ),
                    ),
                    child: const _ReceiptRow('الإجمالي', '12,000', bold: true),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'بيانات توضيحية · ر.ي',
                    style: TextStyle(color: DukanColors.muted, fontSize: 11),
                  ),
                ],
              ),
            );
            if (size.maxWidth < 780) {
              return GalleryStack(children: [intro, receipt]);
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: intro),
                const SizedBox(width: 40),
                SizedBox(width: 340, child: receipt),
              ],
            );
          },
        ),
      ),
      const GalleryGrid(
        minWidth: 220,
        children: [
          DukanMetricCard(
            label: 'هوية هادئة',
            value: 'أخضر دكّان',
            caption: 'ألوان دلالية مرتبطة بوظيفة واضحة',
          ),
          DukanMetricCard(
            label: 'عربية أولًا',
            value: 'يمين ← يسار',
            caption: 'خطوط محلية وأرقام سهلة القراءة',
          ),
          DukanMetricCard(
            label: 'واجهة عملية',
            value: 'من المحل للمحل',
            caption: 'جداول وفواتير تعمل باللمس ولوحة المفاتيح',
          ),
        ],
      ),
      DukanPanel(
        title: 'من العنصر إلى يوم العمل',
        description: 'القواعد نفسها في كل صفحة',
        child: GalleryGrid(
          minWidth: 280,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ابدأ بعناصر موحّدة',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DukanStatusTag('معتمد', tone: DukanTone.success),
                    DukanStatusTag('دفع جزئي', tone: DukanTone.warning),
                    DukanStatusTag('مسودة'),
                  ],
                ),
                const SizedBox(height: 16),
                const DukanField(
                  label: 'اسم المنتج',
                  hint: 'ابحث بالاسم أو الباركود',
                  prefixIcon: Icons.search,
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ثم كوّن مسارًا واضحًا',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                const Text(
                  'اختيار المنتجات، مراجعة الإجمالي، ثم الاعتماد. صفحة عمل مستقلة بتفاصيل يسهل الوصول إليها.',
                ),
                const SizedBox(height: 16),
                DukanButton(
                  label: 'معاينة الفاتورة والسند',
                  variant: DukanButtonVariant.secondary,
                  onPressed: onPattern,
                ),
              ],
            ),
          ],
        ),
      ),
      const Text(
        'هذه مكتبة واجهات ببيانات توضيحية؛ العمليات المالية وحفظ البيانات خارج نطاق هذا العرض.',
        style: TextStyle(color: DukanColors.muted, fontSize: 12),
      ),
    ],
  );
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontWeight: bold ? FontWeight.w600 : null),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(fontWeight: bold ? FontWeight.w600 : null),
        ),
      ],
    ),
  );
}

class _Foundations extends StatelessWidget {
  const _Foundations();
  static const _colors = <(String, String, Color)>[
    ('الأخضر الأساسي', '#17654D', DukanColors.primary),
    ('حبر النص', '#233D35', DukanColors.ink),
    ('النص الثانوي', '#62766B', DukanColors.muted),
    ('خلفية الصفحة', '#F5F7F4', DukanColors.background),
    ('الأخضر الفاتح', '#E7EFCD', DukanColors.sage),
    ('حدود العناصر', '#E5EAE6', DukanColors.controlBorder),
    ('تنبيه', '#895B16', DukanColors.warning),
    ('خطأ أو حذف', '#B23636', DukanColors.danger),
  ];
  @override
  Widget build(BuildContext context) => GalleryStack(
    children: [
      const DukanPageHeader(
        title: 'هوية من واجهة دكّان',
        description: 'ألوان هادئة للمحتوى، وألوان دلالية لاتخاذ القرار.',
      ),
      GalleryGrid(
        minWidth: 210,
        children: [
          for (final (label, hex, color) in _colors)
            DukanPanel(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 100,
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(
                        DukanLayout.smallRadius,
                      ),
                      border: Border.all(color: DukanColors.border),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label),
                        SelectableText(
                          hex,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: DukanColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      const DukanNotice(
        title: 'تحسين القراءة مع الاحتفاظ بالهوية',
        message: 'لون النص الثانوي والتنبيه أغمق من النموذج الأصلي. حدود خفيفة موحّدة للبطاقات والحقول، مع تمييز الحقل عند التركيز.',
      ),
      const DukanPanel(
        title: 'دلالات ثابتة',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DukanStatusTag('معتمد / مسدد', tone: DukanTone.success),
            DukanStatusTag('جزئي / يحتاج مراجعة', tone: DukanTone.warning),
            DukanStatusTag('فشل / إجراء حساس', tone: DukanTone.danger),
            DukanStatusTag('معلومة', tone: DukanTone.info),
            DukanStatusTag('مسودة / مؤرشف'),
          ],
        ),
      ),
    ],
  );
}

class _Typography extends StatelessWidget {
  const _Typography();
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GalleryStack(
      children: [
        const DukanPageHeader(
          title: 'عربية واضحة، وأرقام مستقرة',
          description:
              'IBM Plex Sans Arabic للمحتوى · Noto Kufi Arabic للشعار فقط',
        ),
        DukanPanel(
          title: 'مقياس الخطوط',
          child: GalleryStack(
            children: [
              Text('كل تفاصيل محلك، في مكان واحد', style: text.headlineLarge),
              Text('عنوان الصفحة · 26', style: text.headlineMedium),
              Text('عنوان القسم · 20', style: text.titleLarge),
              Text('عنوان البطاقة · 16', style: text.titleMedium),
              Text(
                'نص أساسي · 14 — راجع المنتجات والكميات قبل اعتماد الفاتورة.',
                style: text.bodyMedium,
              ),
              Text(
                'نص مساعد · 12 — آخر نسخة احتياطية: اليوم، 8:30 ص',
                style: text.bodySmall,
              ),
              const Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  DukanAmount('12,000.00'),
                  DukanAmount('4,250.50', currency: 'ر.س'),
                  SelectableText('INV-1048', textDirection: TextDirection.ltr),
                ],
              ),
            ],
          ),
        ),
        DukanPanel(
          title: 'مسافات من مضاعفات 4',
          child: Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              for (final value in [4, 8, 12, 16, 24, 32, 48])
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: value.toDouble(),
                      height: 32,
                      color: DukanColors.primarySoft,
                    ),
                    const SizedBox(height: 8),
                    Text('$value px'),
                  ],
                ),
            ],
          ),
        ),
        const DukanNotice(
          title: 'يتّسع المحتوى عند تكبير النص',
          message: 'لا يُصغّر النص تلقائيًا. تلتف الإجراءات وتتمدد الحقول، وتبقى الجداول قابلة للتمرير أفقيًا.',
        ),
      ],
    );
  }
}
