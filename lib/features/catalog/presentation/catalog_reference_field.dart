import '../data/catalog_references_tasks.dart';

import 'package:flutter/material.dart';

import '../../../core/ui/paged_selection_dialog.dart';
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
    this.emptyLabel,
    this.onChanged,
  });
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  final TextEditingController controller;
  final String label, excludeId;
  final String? helper;
  final bool optional, enabled;
  final String? emptyLabel;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, repository.store]),
    builder: (context, _) {
      final entry = repository.find(kind, controller.text);
      return DeptAccountingField(
        key: ValueKey('$label-${entry?.id}-${entry?.name}-${entry?.active}'),
        label: label,
        initialValue: entry?.name ?? emptyLabel ?? '',
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
                    emptyLabel: emptyLabel,
                  ),
                );
                if (context.mounted && id != null) {
                  controller.text = id;
                  onChanged?.call(id);
                }
              }
            : null,
      );
    },
  );
}

class _ReferencePicker extends StatelessWidget {
  const _ReferencePicker({
    required this.repository,
    required this.kind,
    required this.label,
    required this.optional,
    required this.excludeId,
    this.emptyLabel,
  });
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  final String label, excludeId;
  final bool optional;
  final String? emptyLabel;

  @override
  Widget build(BuildContext context) => PagedSelectionDialog<CatalogReference>(
    title: 'اختيار $label',
    searchLabel: 'بحث بالاسم',
    load: (search, page) => repository.store.run(
      CatalogReferenceTasks.page(
        kind,
        search: search,
        excludeId: excludeId,
        counts: false,
        page: page,
        pageSize: 5,
      ),
    ),
    columns: [DataColumn(label: Text(kind.label))],
    cells: (entry) => [DataCell(Text(entry.name))],
    onSelected: (entry) => Navigator.pop(context, entry.id),
    beforeTable: !repository.store.user!.canManage
        ? null
        : Align(
            alignment: AlignmentDirectional.centerStart,
            child: DeptAccountingButton(
              label: kind.addLabel,
              onPressed: () async {
                final entry = await showCatalogReferenceEditor(
                  context,
                  repository: repository,
                  kind: kind,
                );
                if (context.mounted && entry != null) {
                  Navigator.pop(context, entry.id);
                }
              },
            ),
          ),
    actions: [
      if (optional)
        DeptAccountingButton(
          label: emptyLabel ?? 'بدون ${kind.label}',
          variant: DeptAccountingButtonVariant.secondary,
          onPressed: () => Navigator.pop(context, ''),
        ),
    ],
  );
}
