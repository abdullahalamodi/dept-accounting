import 'package:flutter/material.dart';

import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/catalog_reference.dart';
import '../data/catalog_references_repository.dart';
import 'catalog_references_view_model.dart';

Future<CatalogReference?> showCatalogReferenceEditor(
  BuildContext context, {
  required CatalogReferencesRepository repository,
  required CatalogReferenceKind kind,
  CatalogReference? entry,
}) => showDialog<CatalogReference>(
  context: context,
  builder: (_) =>
      _ReferenceEditor(repository: repository, kind: kind, entry: entry),
);

class _ReferenceEditor extends StatefulWidget {
  const _ReferenceEditor({
    required this.repository,
    required this.kind,
    this.entry,
  });
  final CatalogReferencesRepository repository;
  final CatalogReferenceKind kind;
  final CatalogReference? entry;
  @override
  State<_ReferenceEditor> createState() => _ReferenceEditorState();
}

class _ReferenceEditorState extends State<_ReferenceEditor> {
  late final vm = CatalogReferencesViewModel(widget.repository, widget.kind);
  late final name = TextEditingController(text: widget.entry?.name);

  Future<void> save() async {
    final saved = await vm.save(id: widget.entry?.id, name: name.text);
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  void dispose() {
    name.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) => AlertDialog(
      title: Text(
        widget.entry == null
            ? widget.kind.addLabel
            : 'تعديل ${widget.kind.label}',
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: SectionStack.form(
            children: [
              ErrorNotice(vm.error),
              DeptAccountingField(
                label: 'اسم ${widget.kind.label}',
                controller: name,
                autofocus: true,
                onSubmitted: (_) => save(),
              ),
              if (widget.entry != null && widget.entry!.productCount > 0)
                const Text(
                  'يتحدث الاسم في المنتجات المرتبطة. تحتفظ الفواتير المعتمدة بالاسم المسجل وقت اعتمادها.',
                ),
            ],
          ),
        ),
      ),
      actions: [
        DeptAccountingButton(
          label: 'إلغاء',
          variant: DeptAccountingButtonVariant.quiet,
          onPressed: () => Navigator.pop(context),
        ),
        DeptAccountingButton(label: 'حفظ', onPressed: save),
      ],
    ),
  );
}
