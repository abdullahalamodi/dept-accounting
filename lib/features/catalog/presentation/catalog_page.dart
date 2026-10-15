import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../data/product.dart';
import '../data/catalog_reference.dart';
import 'catalog_navigation.dart';
import 'catalog_reference_field.dart';
import 'catalog_view_model.dart';
import 'product_units_section.dart';

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
    listenable: Listenable.merge([vm, widget.dependencies.store]),
    builder: (context, _) {
      final manage = widget.dependencies.store.user!.canManage,
          currency = widget.dependencies.store.shop!.currencyLabel;
      return SectionStack(
        children: [
          DukanPageHeader(
            title: 'المنتجات والخدمات',
            description: 'منتجات محلك، وحداتها وأسعارها ومخزونها',
            actions: [
              if (manage)
                DukanButton(
                  label: 'إضافة منتج',
                  onPressed: () => context.go('/catalog/new'),
                ),
            ],
          ),
          CatalogNavigation(selected: '/catalog', canManage: manage),
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
                    ...widget.dependencies.catalogReferences
                        .all(CatalogReferenceKind.category)
                        .map((c) => (value: c.id, label: c.name)),
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
                const DataColumn(label: Text('المنتج')),
                const DataColumn(label: Text('الباركود')),
                const DataColumn(label: Text('التصنيف')),
                const DataColumn(label: Text('المتوفر')),
                const DataColumn(label: Text('سعر البيع')),
                if (manage) const DataColumn(label: Text('سعر الشراء')),
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
              emptyTitle: 'لا توجد منتجات',
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
    'category': TextEditingController(text: product?.categoryId),
    'unit': TextEditingController(
      text:
          product?.unitId ??
          widget.dependencies.catalogReferences
              .all(CatalogReferenceKind.unit)
              .where((r) => r.active && r.id == 'unit_piece')
              .firstOrNull
              ?.id ??
          widget.dependencies.catalogReferences
              .all(CatalogReferenceKind.unit)
              .where((r) => r.active)
              .firstOrNull
              ?.id ??
          '',
    ),
    'alternateUnit': TextEditingController(text: product?.alternateUnitId),
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
  };

  void save({bool addOpening = false}) {
    if (vm.save(
      id: id,
      values: fields.map((k, v) => MapEntry(k, v.text)),
      service: service,
      fractional: fractional,
      active: active,
    )) {
      showMessage(context, 'تم حفظ المنتج');
      context.go(addOpening ? '/catalog/$id/opening' : '/catalog');
    }
  }

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
        title: 'المنتج غير موجود',
        message: 'ارجع إلى قائمة المنتجات.',
      );
    }
    final canAddOpening =
        manage &&
        !service &&
        widget.dependencies.catalog.openingUnavailableReason(product?.id) ==
            null;
    return ListenableBuilder(
      listenable: Listenable.merge([vm, widget.dependencies.store]),
      builder: (context, _) => WorkPage(
        title: product == null ? 'منتج جديد' : product!.name,
        onBack: () => context.go('/catalog'),
        actions: [
          if (manage && product != null && !service)
            DukanButton(
              label: 'حركة المخزون والجرد',
              variant: DukanButtonVariant.secondary,
              onPressed: () => context.go('/inventory/$id'),
            ),
          if (canAddOpening)
            DukanButton(
              label: 'حفظ وإضافة مخزون افتتاحي',
              variant: DukanButtonVariant.secondary,
              onPressed: () => save(addOpening: true),
            ),
          if (manage) DukanButton(label: 'حفظ المنتج', onPressed: () => save()),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            if (canAddOpening)
              const DukanNotice(
                title: 'لديك كمية موجودة من هذا المنتج؟',
                message: 'اختر «حفظ وإضافة مخزون افتتاحي» لتسجيلها بسعر الشراء. يمكنك حفظ المنتج فقط وإضافة الكمية لاحقًا، قبل أول حركة عليه.',
              ),
            DukanPanel(
              title: 'بيانات المنتج',
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
                        ('name', 'اسم المنتج', false),
                        ('barcode', 'الباركود', false),

                        ('salePrice', 'سعر البيع', true),
                        if (manage) ('purchasePrice', 'سعر الشراء', true),
                        if (!service) ('minStock', 'حد تنبيه المخزون', true),
                      ])
                        DukanField(
                          label: label,
                          helper: key == 'salePrice' || key == 'purchasePrice'
                              ? 'لكل وحدة أساسية'
                              : null,
                          controller: fields[key],
                          numeric: numeric,
                          enabled: manage,
                        ),
                      CatalogReferenceField(
                        repository: widget.dependencies.catalogReferences,
                        kind: CatalogReferenceKind.category,
                        label: 'التصنيف',
                        controller: fields['category']!,
                        optional: true,
                        enabled: manage,
                      ),
                    ],
                  ),
                  if (manage) ...[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('المنتج نشط'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ],
              ),
            ),
            ProductUnitsSection(
              repository: widget.dependencies.catalogReferences,
              unit: fields['unit']!,
              alternateUnit: fields['alternateUnit']!,
              factor: fields['factor']!,
              fractional: fractional,
              service: service,
              enabled: manage,
              onFractionalChanged: (v) => setState(() => fractional = v),
            ),
          ],
        ),
      ),
    );
  }
}
