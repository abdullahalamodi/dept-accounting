import '../data/catalog_tasks.dart';
import '../../inventory/data/inventory_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
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
  bool filtersOpen = false;
  late final vm = CatalogViewModel(widget.dependencies.catalog)
    ..lowOnly = widget.lowStockOnly;
  final category = TextEditingController();
  @override
  void dispose() {
    category.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.dependencies.store]),
    builder: (context, _) {
      final manage = widget.dependencies.store.user!.canManage,
          currency = widget.dependencies.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: widget.dependencies.store,
        task: CatalogTasks.page(
          search: vm.search,
          category: vm.category,
          lowOnly: vm.lowOnly,
          servicesOnly: vm.servicesOnly,
          page: vm.page,
          pageSize: vm.pageSize,
        ),
        queryKey: (
          vm.search,
          vm.category,
          vm.lowOnly,
          vm.servicesOnly,
          vm.page,
          vm.pageSize,
        ),
        builder: (context, results) {
          final compact =
              MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact;
          return SectionStack(
            children: [
              DeptAccountingPageHeader(
                title: 'المنتجات والخدمات',
                description: 'منتجات محلك، وحداتها وأسعارها ومخزونها',
                actions: [
                  if (manage)
                    DeptAccountingButton(
                      label: 'إضافة منتج',
                      onPressed: () => context.go('/catalog/new'),
                    ),
                ],
              ),
              CatalogNavigation(selected: '/catalog', canManage: manage),
              if (vm.error != null) ErrorNotice(vm.error),
              DeptAccountingPanel(
                child: FieldGrid(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DeptAccountingField(
                            label: 'بحث بالاسم أو الباركود',
                            onChanged: vm.filter,
                          ),
                        ),
                        if (compact)
                          IconButton(
                            tooltip: 'تصفية المنتجات',
                            icon: Icon(
                              filtersOpen ? Icons.filter_list_off : Icons.tune,
                            ),
                            onPressed: () =>
                                setState(() => filtersOpen = !filtersOpen),
                          ),
                      ],
                    ),
                    if (!compact || filtersOpen)
                      CatalogReferenceField(
                        repository: widget.dependencies.catalogReferences,
                        kind: CatalogReferenceKind.category,
                        controller: category,
                        label: 'التصنيف',
                        optional: true,
                        emptyLabel: 'كل التصنيفات',
                        onChanged: (value) {
                          vm.category = value;
                          vm.filter(vm.search);
                        },
                      ),
                    if (!compact || filtersOpen)
                      Wrap(
                        children: [
                          DeptAccountingFilterChip(
                            label: const Text('مخزون منخفض'),
                            selected: vm.lowOnly,
                            onSelected: (v) {
                              vm.lowOnly = v;
                              vm.filter(vm.search);
                            },
                          ),
                          const SizedBox(width: 8),
                          DeptAccountingFilterChip(
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
              DeptAccountingPanel(
                padding: EdgeInsets.zero,
                child: DeptAccountingDataTable(
                  compactRowBuilder: (context, index) {
                    final row = results.items[index], product = row.product;
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: DeptAccountingRecordTile(
                        title: product.name,
                        subtitle: [
                          if (product.category.isNotEmpty) product.category,
                          if (product.barcode.isNotEmpty) product.barcode,
                        ].join(' · '),
                        leading: Icons.inventory_2_outlined,
                        onTap: () => context.go('/catalog/${product.id}'),
                        details: Wrap(
                          spacing: 16,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            DeptAccountingAmount(
                              Numbers.format(product.salePrice),
                              currency: currency,
                            ),
                            Text(
                              product.service
                                  ? 'خدمة'
                                  : '${Numbers.format(row.quantity, decimals: 3)} ${product.unit}',
                            ),
                            if (!product.active)
                              const DeptAccountingStatusTag(
                                'موقوف',
                                tone: DeptAccountingTone.warning,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  columns: [
                    const DataColumn(label: Text('المنتج')),
                    const DataColumn(label: Text('الباركود')),
                    const DataColumn(label: Text('التصنيف')),
                    const DataColumn(label: Text('المتوفر')),
                    if (manage) const DataColumn(label: Text('تكلفة الوحدة')),
                    const DataColumn(label: Text('سعر البيع')),
                    const DataColumn(label: Text('الحالة')),
                    const DataColumn(label: Text('الإجراء')),
                  ],
                  rows: [
                    for (final row in results.items)
                      DataRow(
                        cells: [
                          DataCell(Text(row.product.name)),
                          DataCell(
                            Text(
                              row.product.barcode.isEmpty
                                  ? '—'
                                  : row.product.barcode,
                            ),
                          ),
                          DataCell(
                            Text(
                              row.product.category.isEmpty
                                  ? '—'
                                  : row.product.category,
                            ),
                          ),
                          DataCell(
                            Text(
                              row.product.service
                                  ? 'خدمة'
                                  : '${Numbers.format(row.quantity, decimals: 3)} ${row.product.unit}',
                            ),
                          ),
                          if (manage)
                            DataCell(
                              DeptAccountingAmount(
                                Numbers.format(row.product.purchasePrice),
                                currency: currency,
                              ),
                            ),
                          DataCell(
                            DeptAccountingAmount(
                              Numbers.format(row.product.salePrice),
                              currency: currency,
                            ),
                          ),
                          DataCell(
                            DeptAccountingStatusTag(
                              row.product.active ? 'نشط' : 'موقوف',
                              tone: row.product.active
                                  ? DeptAccountingTone.success
                                  : DeptAccountingTone.neutral,
                            ),
                          ),
                          DataCell(
                            DeptAccountingIconButton.table(
                              onPressed: () =>
                                  context.go('/catalog/${row.product.id}'),
                              tooltip: manage ? 'عرض وتعديل' : 'عرض',
                              icon: manage
                                  ? Icons.edit_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ],
                      ),
                  ],
                  totalRows: results.total,
                  page: results.page,
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
  bool editing = false;
  late final vm = CatalogViewModel(widget.dependencies.catalog);
  late final Product? product = widget.id == 'new'
      ? null
      : widget.dependencies.catalog.find(widget.id);
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
          widget.dependencies.catalogReferences.defaultUnit()?.id ??
          '',
    ),
    'alternateUnit': TextEditingController(text: product?.alternateUnitId),
    'factor': TextEditingController(
      text: Numbers.input(product?.factor ?? 1000, decimals: 3),
    ),
    'salePrice': TextEditingController(
      text: Numbers.input(product?.salePrice ?? 0, blankZero: true),
    ),
    'purchasePrice': TextEditingController(
      text: Numbers.input(product?.purchasePrice ?? 0, blankZero: true),
    ),
    'minStock': TextEditingController(
      text: Numbers.input(product?.minStock ?? 0, decimals: 3, blankZero: true),
    ),
  };

  Future<void> save({bool addOpening = false}) async {
    if (await vm.save(
          id: id,
          values: fields.map((k, v) => MapEntry(k, v.text)),
          service: service,
          fractional: fractional,
          active: active,
        ) &&
        mounted) {
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
      return const DeptAccountingStateView(
        state: DeptAccountingViewState.error,
        title: 'المنتج غير موجود',
        message: 'ارجع إلى قائمة المنتجات.',
      );
    }
    if (MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact &&
        product != null &&
        !editing) {
      final d = widget.dependencies;
      final p = d.catalog.get(id);
      final currency = d.store.shop!.currencyLabel;
      return DatabaseQuery(
        store: d.store,
        task: InventoryTasks.snapshot(id, 1),
        queryKey: id,
        builder: (context, data) => WorkPage(
          title: p.name,
          onBack: () => context.go('/catalog'),
          actions: [
            if (manage)
              DeptAccountingButton(
                label: 'تعديل المنتج',
                icon: Icons.edit_outlined,
                onPressed: () => setState(() => editing = true),
              ),
          ],
          child: SectionStack(
            children: [
              DeptAccountingRecordTile(
                title: p.name,
                subtitle: [
                  p.category,
                  if (p.barcode.isNotEmpty) p.barcode,
                ].where((v) => v.isNotEmpty).join(' · '),
                leading: Icons.inventory_2_outlined,
                details: DeptAccountingStatusTag(
                  p.active ? 'نشط' : 'موقوف',
                  tone: p.active
                      ? DeptAccountingTone.success
                      : DeptAccountingTone.warning,
                ),
              ),
              DeptAccountingPanel(
                title: 'الأسعار والوحدات',
                child: Column(
                  children: [
                    DeptAccountingSummaryLine(
                      label: 'سعر البيع لكل ${p.unit}',
                      value: Numbers.format(p.salePrice),
                      currency: currency,
                    ),
                    if (manage)
                      DeptAccountingSummaryLine(
                        label: 'تكلفة الوحدة',
                        value: Numbers.format(p.purchasePrice),
                        currency: currency,
                      ),
                    if (p.alternateUnit.isNotEmpty)
                      Text(
                        '1 ${p.alternateUnit} = ${Numbers.format(p.factor, decimals: 3)} ${p.unit}',
                      ),
                  ],
                ),
              ),
              if (!p.service)
                DeptAccountingMetricCard(
                  label: 'الكمية المتاحة',
                  value: Numbers.format(data.stock.quantity, decimals: 3),
                  caption: p.unit,
                ),
              if (manage && !p.service)
                DeptAccountingButton(
                  label: 'حركة المخزون والجرد',
                  variant: DeptAccountingButtonVariant.secondary,
                  onPressed: () => context.go('/inventory/$id'),
                ),
              if (manage && d.catalog.openingUnavailableReason(id) == null)
                DeptAccountingButton(
                  label: 'إضافة مخزون افتتاحي',
                  variant: DeptAccountingButtonVariant.secondary,
                  onPressed: () => context.go('/catalog/$id/opening'),
                ),
            ],
          ),
        ),
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
        busy: vm.busy,
        title: product == null ? 'منتج جديد' : product!.name,
        onBack: () {
          if (editing &&
              MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact) {
            setState(() => editing = false);
          } else {
            context.go('/catalog');
          }
        },
        actions: [
          if (manage && product != null && !service)
            DeptAccountingButton(
              label: 'حركة المخزون والجرد',
              variant: DeptAccountingButtonVariant.secondary,
              onPressed: () => context.go('/inventory/$id'),
            ),
          if (canAddOpening)
            DeptAccountingButton(
              label: 'حفظ وإضافة مخزون افتتاحي',
              variant: DeptAccountingButtonVariant.secondary,
              onPressed: () => save(addOpening: true),
            ),
          if (manage)
            DeptAccountingButton(label: 'حفظ المنتج', onPressed: () => save()),
        ],
        child: SectionStack(
          children: [
            ErrorNotice(vm.error),
            if (canAddOpening)
              const DeptAccountingNotice(
                title: 'لديك كمية موجودة من هذا المنتج؟',
                message: 'اختر «حفظ وإضافة مخزون افتتاحي» لتسجيلها بتكلفة الوحدة. يمكنك حفظ المنتج فقط وإضافة الكمية لاحقًا، قبل أول حركة عليه.',
              ),
            DeptAccountingPanel(
              title: 'بيانات المنتج',
              child: SectionStack.form(
                children: [
                  FieldGrid(
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
                  FieldGrid(
                    children: [
                      for (final (key, label, numeric) in [
                        ('name', 'اسم المنتج', false),
                        ('barcode', 'الباركود', false),

                        if (manage) ('purchasePrice', 'تكلفة الوحدة', true),
                        ('salePrice', 'سعر البيع', true),
                        if (!service) ('minStock', 'حد تنبيه المخزون', true),
                      ])
                        DeptAccountingField(
                          label: label,
                          helper: key == 'salePrice' || key == 'purchasePrice'
                              ? 'لكل وحدة أساسية'
                              : null,
                          controller: fields[key],
                          numeric: numeric,
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
