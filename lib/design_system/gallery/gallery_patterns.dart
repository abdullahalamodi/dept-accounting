import 'package:flutter/material.dart';

import '../dukan_design_system.dart';
import 'design_system_gallery.dart';

void _feedback(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

class GalleryControls extends StatefulWidget {
  const GalleryControls({super.key});
  @override
  State<GalleryControls> createState() => _GalleryControlsState();
}

class _GalleryControlsState extends State<GalleryControls> {
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  bool _notifications = true;
  String _payment = 'نقدي';

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _loading = false);
    _feedback(context, 'اكتملت معاينة الحفظ. لم تُحفظ بيانات فعلية.');
  }

  @override
  Widget build(BuildContext context) => GalleryStack(
    children: [
      const DukanPageHeader(
        title: 'عناصر تتكرر، وسلوك واحد',
        description:
            'جرّب الأزرار والحقول والتحقق من البيانات باستخدام لوحة المفاتيح.',
      ),
      DukanPanel(
        title: 'الإجراءات',
        description: 'إجراء أساسي واحد لكل مجموعة عمل',
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            DukanButton(
              label: 'فاتورة جديدة',
              icon: Icons.add,
              onPressed: () =>
                  _feedback(context, 'هذا مثال لزر الإجراء الأساسي.'),
            ),
            DukanButton(
              label: 'حفظ مسودة',
              variant: DukanButtonVariant.secondary,
              onPressed: () => _feedback(context, 'هذا مثال للإجراء الثانوي.'),
            ),
            DukanButton(
              label: 'العودة للسجل',
              variant: DukanButtonVariant.quiet,
              onPressed: () => _feedback(context, 'هذا مثال لإجراء التنقل.'),
            ),
            const DukanButton(label: 'غير متاح'),
            const DukanButton(label: 'جارٍ الحفظ', loading: true),
            DukanButton(
              label: 'حذف المسودة',
              variant: DukanButtonVariant.danger,
              onPressed: () async {
                final confirmed = await showDukanConfirmation(
                  context,
                  title: 'حذف المسودة؟',
                  message: 'ستُحذف مسودة الفاتورة من هذه المعاينة فقط.',
                  confirmLabel: 'حذف المسودة',
                  destructive: true,
                );
                if (context.mounted && confirmed) {
                  _feedback(context, 'تم تأكيد الإجراء في المعاينة.');
                }
              },
            ),
          ],
        ),
      ),
      DukanPanel(
        title: 'بطاقات الإجراءات السريعة',
        showHeaderDivider: false,
        child: GalleryGrid(
          minWidth: 220,
          children: [
            DukanActionCard(
              title: 'فاتورة بيع',
              description: 'نقدي أو آجل',
              icon: Icons.receipt_long_outlined,
              onTap: () => _feedback(context, 'معاينة بطاقة فاتورة البيع.'),
            ),
            DukanActionCard(
              title: 'سند قبض',
              description: 'تحصيل دفعة عميل',
              icon: Icons.south_west,
              onTap: () => _feedback(context, 'معاينة بطاقة سند القبض.'),
            ),
          ],
        ),
      ),
      DukanPanel(
        title: 'نموذج إدخال',
        description: 'اترك الاسم فارغًا ثم اضغط معاينة الحفظ',
        child: Form(
          key: _form,
          child: GalleryStack(
            children: [
              GalleryGrid(
                minWidth: 280,
                children: [
                  DukanField(
                    label: 'اسم المنتج',
                    hint: 'مثال: أرز بسمتي 5 كجم',
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'أدخل اسم المنتج للمتابعة.'
                        : null,
                  ),
                  const DukanField(
                    label: 'الباركود',
                    hint: '6281000000012',
                    numeric: true,
                    helper: 'يمكن إدخاله يدويًا أو باستخدام القارئ.',
                  ),
                  DukanField(
                    label: 'سعر البيع · ر.ي',
                    numeric: true,
                    initialValue: '4200',
                    validator: (value) => (num.tryParse(value ?? '') ?? -1) <= 0
                        ? 'أدخل سعرًا أكبر من صفر.'
                        : null,
                  ),
                  const DukanField(
                    label: 'رقم المستند',
                    initialValue: 'INV-1048',
                    enabled: false,
                    helper: 'يُنشأ بعد اعتماد المستند.',
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in ['نقدي', 'جزئي', 'آجل'])
                    ChoiceChip(
                      label: Text(label),
                      selected: _payment == label,
                      onSelected: (_) => setState(() => _payment = label),
                    ),
                ],
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('تنبيهات المخزون المنخفض'),
                subtitle: const Text('إعداد توضيحي داخل المعاينة'),
                value: _notifications,
                onChanged: (value) => setState(() => _notifications = value),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DukanButton(
                  label: _loading ? 'جارٍ الحفظ' : 'معاينة الحفظ',
                  loading: _loading,
                  onPressed: _save,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

typedef _Product = ({
  String name,
  String barcode,
  String category,
  int price,
  int stock,
});
const _products = <_Product>[
  (
    name: 'أرز بسمتي 5 كجم',
    barcode: '6281000000012',
    category: 'مواد غذائية',
    price: 4200,
    stock: 24,
  ),
  (
    name: 'حليب طويل الأجل',
    barcode: '6281000000029',
    category: 'ألبان',
    price: 600,
    stock: 8,
  ),
  (
    name: 'سكر أبيض 1 كجم',
    barcode: '6281000000036',
    category: 'مواد غذائية',
    price: 950,
    stock: 45,
  ),
  (
    name: 'زيت دوار الشمس',
    barcode: '6281000000043',
    category: 'مواد غذائية',
    price: 2200,
    stock: 18,
  ),
  (
    name: 'شاي أسود',
    barcode: '6281000000050',
    category: 'مشروبات',
    price: 1600,
    stock: 32,
  ),
  (
    name: 'مياه معدنية',
    barcode: '6281000000067',
    category: 'مشروبات',
    price: 250,
    stock: 60,
  ),
  (
    name: 'دقيق أبيض 2 كجم',
    barcode: '6281000000074',
    category: 'مواد غذائية',
    price: 1400,
    stock: 6,
  ),
  (
    name: 'لبن طازج',
    barcode: '6281000000081',
    category: 'ألبان',
    price: 500,
    stock: 16,
  ),
];

String _format(int value) => value.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]},',
);

class GalleryProducts extends StatefulWidget {
  const GalleryProducts({super.key, this.onAdd});
  final ValueChanged<int>? onAdd;
  @override
  State<GalleryProducts> createState() => _GalleryProductsState();
}

class _GalleryProductsState extends State<GalleryProducts> {
  String _search = '';
  bool _low = false;
  int _page = 1;
  int _size = 5;

  @override
  Widget build(BuildContext context) {
    final filtered = _products
        .where(
          (p) =>
              (p.name.contains(_search) || p.barcode.contains(_search)) &&
              (!_low || p.stock < 10),
        )
        .toList();
    final visible = filtered.skip((_page - 1) * _size).take(_size);
    return GalleryStack(
      children: [
        if (widget.onAdd == null)
          const DukanPageHeader(
            title: 'المنتجات، بوضوح',
            description: 'قائمة نصية قابلة للبحث والتصفية والترقيم، دون صور أو أيقونات للمنتجات.',
          ),
        DukanPanel(
          title: 'قائمة المنتجات',
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: GalleryGrid(
                  minWidth: 280,
                  children: [
                    DukanField(
                      label: 'بحث بالاسم أو الباركود',
                      prefixIcon: Icons.search,
                      onChanged: (value) => setState(() {
                        _search = value.trim();
                        _page = 1;
                      }),
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DukanFilterChip(
                        label: const Text('مخزون منخفض'),
                        selected: _low,
                        onSelected: (value) => setState(() {
                          _low = value;
                          _page = 1;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              DukanDataTable(
                columns: const [
                  DataColumn(label: Text('المنتج / الباركود')),
                  DataColumn(label: Text('التصنيف')),
                  DataColumn(label: Text('المتوفر')),
                  DataColumn(label: Text('سعر البيع')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: visible
                    .map(
                      (p) => DataRow(
                        cells: [
                          DataCell(
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name),
                                  Text(
                                    p.barcode,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      color: DukanColors.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(Text(p.category)),
                          DataCell(Text('${p.stock} حبة')),
                          DataCell(DukanAmount(_format(p.price))),
                          DataCell(
                            TextButton(
                              onPressed: () {
                                if (widget.onAdd != null) {
                                  widget.onAdd!(_products.indexOf(p));
                                } else {
                                  _feedback(
                                    context,
                                    '${p.name} · ${p.stock} حبة متوفرة · بيانات توضيحية',
                                  );
                                }
                              },
                              child: Text(
                                widget.onAdd == null ? 'عرض التفاصيل' : 'إضافة',
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(),
                totalRows: filtered.length,
                page: _page,
                pageSize: _size,
                onPageChanged: (value) => setState(() => _page = value),
                onPageSizeChanged: (value) => setState(() {
                  _size = value;
                  _page = 1;
                }),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GalleryWorkflows extends StatefulWidget {
  const GalleryWorkflows({super.key});
  @override
  State<GalleryWorkflows> createState() => _GalleryWorkflowsState();
}

class _GalleryWorkflowsState extends State<GalleryWorkflows> {
  bool _voucher = false;
  @override
  Widget build(BuildContext context) => GalleryStack(
    children: [
      const DukanPageHeader(
        title: 'مساحة عمل، من البداية للاعتماد',
        description: 'أمثلة تفاعلية لعناصر التصميم. القيم توضيحية ولا تُسجّل عمليات فعلية.',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ChoiceChip(
            label: const Text('فاتورة بيع'),
            selected: !_voucher,
            onSelected: (_) => setState(() => _voucher = false),
          ),
          ChoiceChip(
            label: const Text('سند قبض'),
            selected: _voucher,
            onSelected: (_) => setState(() => _voucher = true),
          ),
        ],
      ),
      if (_voucher) const _VoucherPattern() else const _InvoicePattern(),
    ],
  );
}

class _InvoicePattern extends StatefulWidget {
  const _InvoicePattern();
  @override
  State<_InvoicePattern> createState() => _InvoicePatternState();
}

class _InvoicePatternState extends State<_InvoicePattern> {
  final _quantities = <int, int>{0: 2, 1: 6};
  int get _total => _quantities.entries.fold(
    0,
    (sum, entry) => sum + _products[entry.key].price * entry.value,
  );

  Future<void> _pick() async {
    final product = await showDialog<int>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950, maxHeight: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: GalleryStack(
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('إضافة منتجات إلى الفاتورة')),
                    IconButton(
                      tooltip: 'إغلاق',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                GalleryProducts(
                  onAdd: (index) => Navigator.pop(context, index),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (product != null) {
      setState(
        () => _quantities.update(
          product,
          (value) => value + 1,
          ifAbsent: () => 1,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => DukanEditorLayout(
    form: GalleryStack(
      children: [
        const DukanPanel(
          title: 'بيانات الفاتورة',
          child: GalleryGrid(
            minWidth: 220,
            children: [
              DukanField(label: 'العميل', initialValue: 'أحمد محمد'),
              DukanField(label: 'التاريخ', initialValue: '2026/10/15'),
            ],
          ),
        ),
        DukanPanel(
          title: 'منتجات الفاتورة',
          action: DukanButton(
            label: 'إضافة منتجات',
            onPressed: _pick,
            variant: DukanButtonVariant.secondary,
          ),
          padding: EdgeInsets.zero,
          child: DukanDataTable(
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('الكمية')),
              DataColumn(label: Text('الإجمالي')),
              DataColumn(label: Text('الإجراء')),
            ],
            rows: _quantities.entries
                .map(
                  (entry) => DataRow(
                    cells: [
                      DataCell(Text(_products[entry.key].name)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip:
                                  'تقليل كمية ${_products[entry.key].name}',
                              onPressed: entry.value > 1
                                  ? () => setState(
                                      () => _quantities[entry.key] =
                                          entry.value - 1,
                                    )
                                  : null,
                              icon: const Icon(Icons.remove, size: 16),
                            ),
                            Text('${entry.value}'),
                            IconButton(
                              tooltip:
                                  'زيادة كمية ${_products[entry.key].name}',
                              onPressed: () => setState(
                                () => _quantities[entry.key] = entry.value + 1,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        DukanAmount(
                          _format(_products[entry.key].price * entry.value),
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () =>
                              setState(() => _quantities.remove(entry.key)),
                          child: const Text('إزالة'),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
            totalRows: _quantities.length,
            page: 1,
            pageSize: 10,
            onPageChanged: (_) {},
            minWidth: 580,
            emptyTitle: 'أضف أول منتج',
            emptyMessage: 'اختر «إضافة منتجات» لبدء الفاتورة.',
          ),
        ),
      ],
    ),
    summary: DukanPanel(
      title: 'ملخص الفاتورة',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DukanStatusTag('مسودة توضيحية'),
          const SizedBox(height: 16),
          DukanSummaryLine(
            label: 'عدد المنتجات',
            value: '${_quantities.length}',
            currency: '',
          ),
          const Divider(),
          DukanSummaryLine(
            label: 'الإجمالي',
            value: _format(_total),
            total: true,
          ),
          const SizedBox(height: 16),
          DukanButton(
            label: 'معاينة الاعتماد',
            onPressed: _quantities.isEmpty
                ? null
                : () => _feedback(
                    context,
                    'تمت مراجعة الفاتورة في المعاينة. لا يوجد ترحيل أو حفظ مالي.',
                  ),
          ),
          const SizedBox(height: 8),
          DukanButton(
            label: 'حفظ مسودة',
            variant: DukanButtonVariant.secondary,
            onPressed: () => _feedback(
              context,
              'هذه مسودة للعرض فقط؛ تبقى أثناء فتح هذا المثال.',
            ),
          ),
        ],
      ),
    ),
  );
}

class _VoucherPattern extends StatefulWidget {
  const _VoucherPattern();
  @override
  State<_VoucherPattern> createState() => _VoucherPatternState();
}

class _VoucherPatternState extends State<_VoucherPattern> {
  final _form = GlobalKey<FormState>();
  String _allocation = 'الأقدم أولًا';
  String _cash = '2000';
  String _bank = '500';
  int get _total => (int.tryParse(_cash) ?? 0) + (int.tryParse(_bank) ?? 0);
  String? _validate(String? value) => (int.tryParse(value ?? '') ?? -1) < 0
      ? 'أدخل مبلغًا صحيحًا صفرًا أو أكبر.'
      : null;

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: DukanEditorLayout(
      form: GalleryStack(
        children: [
          const DukanPanel(
            title: 'سند قبض من عميل',
            child: DukanField(label: 'العميل', initialValue: 'أحمد محمد'),
          ),
          DukanPanel(
            title: 'توزيع مبلغ القبض',
            description: 'أكثر من حساب في السند نفسه',
            child: GalleryGrid(
              minWidth: 220,
              children: [
                DukanField(
                  label: 'الصندوق · ر.ي',
                  numeric: true,
                  initialValue: _cash,
                  validator: _validate,
                  onChanged: (value) => setState(() => _cash = value),
                ),
                DukanField(
                  label: 'البنك · ر.ي',
                  numeric: true,
                  initialValue: _bank,
                  validator: _validate,
                  onChanged: (value) => setState(() => _bank = value),
                ),
              ],
            ),
          ),
          DukanPanel(
            title: 'تخصيص الدفعة',
            child: GalleryStack(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final label in ['الأقدم أولًا', 'يدوي', 'على الحساب'])
                      ChoiceChip(
                        label: Text(label),
                        selected: _allocation == label,
                        onSelected: (_) => setState(() => _allocation = label),
                      ),
                  ],
                ),
                DukanNotice(
                  title: _allocation == 'على الحساب'
                      ? 'رصيد غير مخصص'
                      : _allocation == 'يدوي'
                      ? 'تحديد الفواتير يدويًا'
                      : 'تخصيص تلقائي',
                  message: _allocation == 'على الحساب'
                      ? 'تظهر الدفعة على رصيد العميل دون ربطها بفاتورة.'
                      : _allocation == 'يدوي'
                      ? 'في صفحة العمل الفعلية يحدد المستخدم الفواتير والمبلغ لكل فاتورة. هذا المثال يوضح حالة الواجهة.'
                      : 'تُعرض الفواتير الأقدم استحقاقًا أولًا. هذا المثال يوضح اختيار الوضع فقط.',
                ),
              ],
            ),
          ),
        ],
      ),
      summary: DukanPanel(
        title: 'ملخص السند',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DukanSummaryLine(label: 'الصندوق', value: _cash),
            DukanSummaryLine(label: 'البنك', value: _bank),
            const Divider(),
            DukanSummaryLine(
              label: 'إجمالي القبض',
              value: _format(_total),
              total: true,
            ),
            const SizedBox(height: 16),
            DukanButton(
              label: 'معاينة السند',
              onPressed: () {
                if (_form.currentState!.validate() && _total > 0) {
                  _feedback(
                    context,
                    'إجمالي السند ${_format(_total)} ر.ي · وضع التخصيص: $_allocation · معاينة فقط',
                  );
                } else if (_total <= 0) {
                  _feedback(context, 'أدخل مبلغ قبض أكبر من صفر.');
                }
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class GalleryStates extends StatelessWidget {
  const GalleryStates({super.key});
  @override
  Widget build(BuildContext context) => GalleryStack(
    children: [
      const DukanPageHeader(
        title: 'رسالة واضحة، وخطوة تالية',
        description: 'لكل حالة عنوان يشرح ما حدث، وإجراء يساعد على المتابعة.',
      ),
      const DukanNotice(
        title: 'اكتمل حفظ الفاتورة',
        message: 'يمكنك عرضها من سجل المبيعات.',
        tone: DukanTone.success,
      ),
      const DukanNotice(
        title: 'الكمية المتوفرة أقل من المطلوبة',
        message: 'متوفر 8 حبات. قلّل الكمية أو سجّل استلام البضاعة.',
        tone: DukanTone.warning,
      ),
      const DukanNotice(
        title: 'تعذّر حفظ الفاتورة',
        message: 'لم تُحفظ التغييرات. احتفظ بالمسودة ثم أعد المحاولة.',
        tone: DukanTone.danger,
      ),
      GalleryGrid(
        minWidth: 300,
        children: [
          DukanPanel(
            child: DukanStateView(
              state: DukanViewState.empty,
              title: 'لا توجد فواتير بعد',
              message: 'أنشئ أول فاتورة لبدء سجل المبيعات.',
              actionLabel: 'إنشاء فاتورة',
              onAction: () =>
                  _feedback(context, 'يمكنك تجربة الفاتورة من «نماذج العمل».'),
            ),
          ),
          DukanPanel(
            child: DukanStateView(
              state: DukanViewState.error,
              title: 'تعذّر تحميل السجل',
              message: 'بياناتك الحالية محفوظة. أعد محاولة تحميل السجل.',
              actionLabel: 'إعادة المحاولة',
              onAction: () =>
                  _feedback(context, 'هذه معاينة لحالة الخطأ وإجراء المحاولة.'),
            ),
          ),
          const DukanPanel(
            child: DukanStateView(
              state: DukanViewState.loading,
              title: 'جارٍ تحميل السجل',
              message: 'ستظهر الفواتير هنا عند اكتمال التحميل.',
            ),
          ),
        ],
      ),
    ],
  );
}
