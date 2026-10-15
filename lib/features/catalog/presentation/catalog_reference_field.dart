import 'package:flutter/material.dart';

import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/catalog_reference.dart';
import '../data/catalog_references_repository.dart';
import 'catalog_reference_editor.dart';

/// Both unit roles and the category use the same searchable selection flow.
class CatalogReferenceField extends StatelessWidget {
  const CatalogReferenceField({
    super.key,
    required this.repository,
    required this.kind,
    required this.controller,
    required this.label,
    this.helper,
    this.optional = false,
    this.enabled = true,
    this.excludeId = '',
  });
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  final TextEditingController controller;
  final String label, excludeId;
  final String? helper;
  final bool optional, enabled;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, repository.store]),
    builder: (context, _) {
      final entry = repository
          .all(kind)
          .where((r) => r.id == controller.text)
          .firstOrNull;
      return DeptAccountingField(
        key: ValueKey('$label-${entry?.id}-${entry?.name}-${entry?.active}'),
        label: label,
        initialValue: entry?.name ?? '',
        hint: 'اختر ${kind.label}',
        helper: entry != null && !entry.active
            ? 'موقوفة؛ يمكنك الاحتفاظ بالاختيار الحالي أو استبداله.'
            : helper,
        readOnly: true,
        enabled: enabled,
        suffixIcon: const Icon(Icons.expand_more),
        onTap: enabled
            ? () async {
                final id = await showDialog<String>(
                  context: context,
                  builder: (_) => _ReferencePicker(
                    repository: repository,
                    kind: kind,
                    label: label,
                    optional: optional,
                    excludeId: excludeId,
                  ),
                );
                if (context.mounted && id != null) controller.text = id;
              }
            : null,
      );
    },
  );
}

class _ReferencePicker extends StatefulWidget {
  const _ReferencePicker({
    required this.repository,
    required this.kind,
    required this.label,
    required this.optional,
    required this.excludeId,
  });
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  final String label, excludeId;
  final bool optional;
  @override
  State<_ReferencePicker> createState() => _ReferencePickerState();
}

class _ReferencePickerState extends State<_ReferencePicker> {
  String search = '';
  int page = 1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.repository
        .all(widget.kind)
        .where(
          (r) =>
              r.active &&
              r.id != widget.excludeId &&
              r.name.toLowerCase().contains(search.trim().toLowerCase()),
        )
        .toList();
    return AlertDialog(
      title: Text('اختيار ${widget.label}'),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: SectionStack.form(
            children: [
              DeptAccountingField(
                label: 'بحث بالاسم',
                autofocus: true,
                onChanged: (v) => setState(() {
                  search = v;
                  page = 1;
                }),
              ),
              if (widget.repository.store.user!.canManage)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: DeptAccountingButton(
                    label: widget.kind.addLabel,
                    variant: DeptAccountingButtonVariant.secondary,
                    onPressed: () async {
                      final entry = await showCatalogReferenceEditor(
                        context,
                        repository: widget.repository,
                        kind: widget.kind,
                      );
                      if (context.mounted && entry != null) {
                        Navigator.pop(context, entry.id);
                      }
                    },
                  ),
                ),
              DeptAccountingDataTable(
                minWidth: 280,
                columns: [
                  DataColumn(label: Text(widget.kind.label)),
                  const DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (final entry in entries.skip((page - 1) * 5).take(5))
                    DataRow(
                      cells: [
                        DataCell(Text(entry.name)),
                        DataCell(
                          TextButton(
                            onPressed: () => Navigator.pop(context, entry.id),
                            child: const Text('اختيار'),
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: entries.length,
                page: page,
                pageSize: 5,
                onPageChanged: (v) => setState(() => page = v),
                emptyTitle: 'لا توجد نتائج',
                emptyMessage: 'ابحث باسم آخر أو أضف ${widget.kind.label}.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.optional)
          DeptAccountingButton(
            label: 'بدون ${widget.kind.label}',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: () => Navigator.pop(context, ''),
          ),
        DeptAccountingButton(
          label: 'إغلاق',
          variant: DeptAccountingButtonVariant.quiet,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
