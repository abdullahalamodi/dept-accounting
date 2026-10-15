import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../data/product.dart';
import 'catalog_view_model.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.dependencies,
    this.lowStockOnly = false,
  });
  final AppDependencies dependencies;
  final bool lowStockOnly;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late final vm = CatalogViewModel(widget.dependencies.catalog)
    ..lowOnly = widget.lowStockOnly;
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final manage = widget.dependencies.store.user!.canManage,
          currency = widget.dependencies.store.shop!.currencyLabel;
      return SectionStack(
        children: [
          DukanPageHeader(
            title: 'المنتجات والخدمات',
            description: 'أصناف محلك، وحداتها وأسعارها ومخزونها',
            actions: [
              if (manage)
                DukanButton(
                  label: 'إضافة صنف',
                  onPressed: () => context.go('/catalog/new'),
                ),
            ],
          ),
          ErrorNotice(vm.error),
          DukanPanel(
            child: FieldGrid(
              children: [
                DukanField(
                  label: 'بحث بالاسم أو الباركود',
                  onChanged: vm.filter,
                ),
                ChoiceField<String>(
                  label: 'التصنيف',
                  value: vm.category,
                  items: [
                    (value: '', label: 'كل التصنيفات'),
                    ...vm.products
                        .map((p) => p.category)
                        .where((c) => c.isNotEmpty)
                        .toSet()
                        .map((c) => (value: c, label: c)),
                  ],
                  onChanged: (v) {
                    vm.category = v!;
                    vm.filter(vm.search);
                  },
                ),
                Wrap(
                  children: [
                    DukanFilterChip(
                      label: const Text('مخزون منخفض'),
                      selected: vm.lowOnly,
                      onSelected: (v) {
                        vm.lowOnly = v;
                        vm.filter(vm.search);
                      },
                    ),
                    const SizedBox(width: 8),
                    DukanFilterChip(
                      label: const Text('الخدمات'),
                      selected: vm.servicesOnly,
                      onSelected: (v) {
                        vm.servicesOnly = v;
                        vm.filter(vm.search);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          DukanPanel(
            padding: EdgeInsets.zero,
            child: DukanDataTable(
              columns: [
                const DataColumn(label: Text('الصنف')),
                const DataColumn(label: Text('الباركود')),
                const DataColumn(label: Text('التصنيف')),
                const DataColumn(label: Text('المتوفر')),
                const DataColumn(label: Text('سعر البيع')),
                if (manage) const DataColumn(label: Text('آخر سعر شراء')),
                const DataColumn(label: Text('الحالة')),
                const DataColumn(label: Text('الإجراء')),
              ],
              rows: [
                for (final p in vm.visible)
                  DataRow(
                    cells: [
                      DataCell(Text(p.name)),
                      DataCell(Text(p.barcode.isEmpty ? '—' : p.barcode)),
                      DataCell(Text(p.category.isEmpty ? '—' : p.category)),
                      DataCell(
                        Text(
                          p.service
                              ? 'خدمة'
                              : '${Numbers.format(widget.dependencies.engine.stock(p.id).quantity, decimals: 3)} ${p.unit}',
                        ),
                      ),
                      DataCell(
                        DukanAmount(
                          Numbers.format(p.salePrice),
                          currency: currency,
                        ),
                      ),
                      if (manage)
                        DataCell(
                          DukanAmount(
                            Numbers.format(p.purchasePrice),
                            currency: currency,
                          ),
                        ),
                      DataCell(
                        DukanStatusTag(
                          p.active ? 'نشط' : 'موقوف',
                          tone: p.active
                              ? DukanTone.success
                              : DukanTone.neutral,
                        ),
                      ),
                      DataCell(
                        TextButton(
                          onPressed: () => context.go('/catalog/${p.id}'),
                          child: Text(manage ? 'عرض وتعديل' : 'عرض'),
                        ),
                      ),
                    ],
                  ),
              ],
              totalRows: vm.filtered.length,
              page: vm.page,
              pageSize: vm.pageSize,
              onPageChanged: vm.go,
              onPageSizeChanged: (v) {
                vm.pageSize = v;
                vm.go(1);
              },
              emptyTitle: 'لا توجد أصناف',
              emptyMessage: 'أضف منتجاتك وخدماتك، ثم ابدأ الشراء والبيع.',
            ),
          ),
        ],
      );
    },
  );
}

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, required this.dependencies, required this.id});
  final AppDependencies dependencies;
  final String id;
  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final vm = CatalogViewModel(widget.dependencies.catalog);
  late final Product? product = widget.id == 'new'
      ? null
      : widget.dependencies.catalog
            .all()
            .where((p) => p.id == widget.id)
            .firstOrNull;
  late final id = product?.id ?? widget.dependencies.store.id();
  late bool service = product?.service ?? false,
      fractional = product?.fractional ?? false,
      active = product?.active ?? true;
  late final fields = <String, TextEditingController>{
    'name': TextEditingController(text: product?.name),
    'barcode': TextEditingController(text: product?.barcode),
    'category': TextEditingController(text: product?.category),
    'unit': TextEditingController(text: product?.unit ?? 'حبة'),
    'alternateUnit': TextEditingController(text: product?.alternateUnit),
    'factor': TextEditingController(
      text: Numbers.input(product?.factor ?? 1000, decimals: 3),
    ),
    'salePrice': TextEditingController(
      text: Numbers.input(product?.salePrice ?? 0),
    ),
    'purchasePrice': TextEditingController(
      text: Numbers.input(product?.purchasePrice ?? 0),
    ),
    'minStock': TextEditingController(
      text: Numbers.input(product?.minStock ?? 0, decimals: 3),
    ),
    'openingQuantity': TextEditingController(),
    'openingCost': TextEditingController(),
  };
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final manage = widget.dependencies.store.user!.canManage;
    if (widget.id != 'new' && product == null) {
      return const DukanStateView(
        state: DukanViewState.error,
        title: 'الصنف غير موجود',
        message: 'ارجع إلى قائمة الأصناف.',
      );
    }
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => WorkPage(
        title: product == null ? 'صنف جديد' : product!.name,
        onBack: () => context.go('/catalog'),
        actions: [
          if (manage && product != null && !service)
            DukanButton(
              label: 'حركة المخزون والجرد',
              variant: DukanButtonVariant.secondary,
              onPressed: () => context.go('/inventory/$id'),
            ),
          if (manage)
            DukanButton(
              label: 'حفظ الصنف',
              onPressed: () {
                if (vm.save(
                  id: id,
                  values: fields.map((k, v) => MapEntry(k, v.text)),
                  service: service,
                  fractional: fractional,
                  active: active,
                )) {
                  showMessage(context, 'تم حفظ الصنف');
                  context.go('/catalog');
                }
              },
            ),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            DukanPanel(
              title: 'بيانات الصنف',
              child: SectionStack.form(
                children: [
                  if (manage)
                    ChoiceField(
                      label: 'النوع',
                      value: service,
                      items: const [
                        (value: false, label: 'منتج مخزني'),
                        (value: true, label: 'خدمة'),
                      ],
                      onChanged: (v) => setState(() => service = v!),
                    ),
                  FieldGrid(
                    children: [
                      for (final (key, label, numeric) in [
                        ('name', 'اسم الصنف', false),
                        ('barcode', 'الباركود', false),
                        ('category', 'التصنيف', false),
                        ('unit', 'الوحدة الأساسية', false),
                        ('salePrice', 'سعر البيع', true),
                        if (manage) ('purchasePrice', 'آخر سعر شراء', true),
                        if (!service) ...[
                          ('alternateUnit', 'وحدة إضافية (اختياري)', false),
                          (
                            'factor',
                            'عدد الوحدات الأساسية في الوحدة الإضافية',
                            true,
                          ),
                          ('minStock', 'حد تنبيه المخزون', true),
                        ],
                      ])
                        DukanField(
                          label: label,
                          controller: fields[key],
                          numeric: numeric,
                          enabled: manage,
                        ),
                    ],
                  ),
                  if (manage) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('السماح بكسور الوحدة الأساسية'),
                      value: fractional,
                      onChanged: (v) => setState(() => fractional = v),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('الصنف نشط'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ],
              ),
            ),
            if (product != null && !service && manage)
              DukanPanel(
                title: 'المخزون الافتتاحي',
                description: 'متاح قبل أول حركة فقط؛ الكمية بالوحدة الأساسية والتكلفة لكل وحدة',
                child: SectionStack.form(
                  children: [
                    Text(
                      'المتوفر: ${Numbers.format(widget.dependencies.engine.stock(id).quantity, decimals: 3)} ${product!.unit}',
                    ),
                    FieldGrid(
                      children: [
                        DukanField(
                          label: 'الكمية الافتتاحية',
                          controller: fields['openingQuantity'],
                          numeric: true,
                        ),
                        DukanField(
                          label: 'تكلفة الوحدة (حتى 6 منازل)',
                          controller: fields['openingCost'],
                          numeric: true,
                        ),
                      ],
                    ),
                    DukanButton(
                      label: 'اعتماد المخزون الافتتاحي',
                      variant: DukanButtonVariant.secondary,
                      onPressed: () async {
                        if (await showDukanConfirmation(
                              context,
                              title: 'اعتماد المخزون الافتتاحي؟',
                              message: 'سيسجل قيدًا افتتاحيًا وحركة مخزون؛ لا يمكن تعديل الافتتاح بعد ذلك.',
                              confirmLabel: 'اعتماد',
                            ) &&
                            mounted) {
                          if (vm.opening(
                                id,
                                fields['openingQuantity']!.text,
                                fields['openingCost']!.text,
                              ) &&
                              context.mounted) {
                            showMessage(context, 'تم اعتماد المخزون الافتتاحي');
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
