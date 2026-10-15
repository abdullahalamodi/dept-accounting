import 'package:flutter/material.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
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
    builder: (context, _) => SectionStack(
      children: [
        DukanPageHeader(
          title: widget.kind.title,
          description: widget.kind == CatalogReferenceKind.unit
              ? 'قائمة مشتركة للوحدات الأساسية والإضافية؛ يُحدد دور الوحدة ومعامل التحويل داخل كل منتج.'
              : 'نظم منتجات المحل بتصنيفات واضحة قابلة للتعديل.',
          actions: [
            DukanButton(
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
        DukanPanel(
          child: FieldGrid(
            children: [
              DukanField(label: 'بحث بالاسم', onChanged: vm.filter),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: DukanFilterChip(
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
        DukanPanel(
          padding: EdgeInsets.zero,
          child: DukanDataTable(
            minWidth: 620,
            columns: [
              DataColumn(label: Text(widget.kind.label)),
              const DataColumn(label: Text('المنتجات المرتبطة')),
              const DataColumn(label: Text('الحالة')),
              const DataColumn(label: Text('الإجراء')),
            ],
            rows: [
              for (final entry in vm.visible)
                DataRow(
                  cells: [
                    DataCell(Text(entry.name)),
                    DataCell(Text('${entry.productCount}')),
                    DataCell(
                      DukanStatusTag(
                        entry.active ? 'نشطة' : 'موقوفة',
                        tone: entry.active
                            ? DukanTone.success
                            : DukanTone.neutral,
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
            totalRows: vm.filtered.length,
            page: vm.page,
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
    ),
  );
}
