import '../data/catalog_references_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/catalog_reference.dart';
import 'catalog_navigation.dart';
import 'catalog_reference_editor.dart';
import 'catalog_references_view_model.dart';

class CatalogReferencesPage extends StatefulWidget {
  const CatalogReferencesPage({
    super.key,
    required this.dependencies,
    required this.kind,
  });
  final AppDependencies dependencies;
  final CatalogReferenceKind kind;
  @override
  State<CatalogReferencesPage> createState() => _CatalogReferencesPageState();
}

class _CatalogReferencesPageState extends State<CatalogReferencesPage> {
  late final vm = CatalogReferencesViewModel(
    widget.dependencies.catalogReferences,
    widget.kind,
  );
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.dependencies.store]),
    builder: (context, _) {
      return DatabaseQuery(
        store: widget.dependencies.store,
        task: CatalogReferenceTasks.page(
          widget.kind,
          search: vm.search,
          showInactive: vm.showInactive,
          page: vm.page,
          pageSize: vm.pageSize,
        ),
        queryKey: (vm.search, vm.showInactive, vm.page, vm.pageSize),
        builder: (context, results) {
          return SectionStack(
            children: [
              DeptAccountingPageHeader(
                title: widget.kind.title,
                description: widget.kind == CatalogReferenceKind.unit
                    ? 'قائمة مشتركة للوحدات الأساسية والإضافية؛ يُحدد دور الوحدة ومعامل التحويل داخل كل منتج.'
                    : 'نظم منتجات المحل بتصنيفات واضحة قابلة للتعديل.',
                actions: [
                  DeptAccountingButton(
                    label: widget.kind.addLabel,
                    onPressed: () => showCatalogReferenceEditor(
                      context,
                      repository: vm.repository,
                      kind: widget.kind,
                    ),
                  ),
                ],
              ),
              CatalogNavigation(
                selected: '/catalog/${widget.kind.table}',
                canManage: true,
              ),
              ErrorNotice(vm.error),
              DeptAccountingPanel(
                child: FieldGrid(
                  children: [
                    DeptAccountingField(
                      label: 'بحث بالاسم',
                      onChanged: vm.filter,
                    ),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: DeptAccountingFilterChip(
                        label: const Text('إظهار الموقوفة'),
                        selected: vm.showInactive,
                        onSelected: (v) {
                          vm.showInactive = v;
                          vm.filter(vm.search);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              DeptAccountingPanel(
                padding: EdgeInsets.zero,
                child: DeptAccountingDataTable(
                  minWidth: 620,
                  columns: [
                    DataColumn(label: Text(widget.kind.label)),
                    const DataColumn(label: Text('المنتجات المرتبطة')),
                    const DataColumn(label: Text('الحالة')),
                    const DataColumn(label: Text('الإجراء')),
                  ],
                  rows: [
                    for (final entry in results.items)
                      DataRow(
                        cells: [
                          DataCell(Text(entry.name)),
                          DataCell(Text('${entry.productCount}')),
                          DataCell(
                            DeptAccountingStatusTag(
                              entry.active ? 'نشطة' : 'موقوفة',
                              tone: entry.active
                                  ? DeptAccountingTone.success
                                  : DeptAccountingTone.neutral,
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: () => showCatalogReferenceEditor(
                                    context,
                                    repository: vm.repository,
                                    kind: widget.kind,
                                    entry: entry,
                                  ),
                                  child: const Text('تعديل'),
                                ),
                                TextButton(
                                  onPressed: () => vm.setActive(entry),
                                  child: Text(entry.active ? 'إيقاف' : 'تفعيل'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                  totalRows: results.total,
                  page: results.page,
                  pageSize: vm.pageSize,
                  onPageChanged: (v) {
                    vm.page = v;
                    vm.changed();
                  },
                  onPageSizeChanged: (v) {
                    vm.pageSize = v;
                    vm.filter(vm.search);
                  },
                  emptyTitle: 'لا توجد نتائج',
                  emptyMessage: 'غيّر البحث أو أظهر العناصر الموقوفة.',
                ),
              ),
              const Text(
                'إيقاف العنصر يمنع اختياره لمنتجات أخرى، ويحافظ على المنتجات والمستندات المرتبطة به.',
              ),
            ],
          );
        },
      );
    },
  );
}
