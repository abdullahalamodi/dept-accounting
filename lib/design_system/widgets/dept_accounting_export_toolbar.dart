import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';
import 'dept_accounting_controls.dart';

class DeptAccountingToolbarAction {
  const DeptAccountingToolbarAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.destructive = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool destructive;
}

enum _ExportAction { print, pdf, share, excel }

class DeptAccountingExportToolbar extends StatefulWidget {
  const DeptAccountingExportToolbar({
    super.key,
    this.onPrint,
    required this.onSavePdf,
    this.onShare,
    this.onExcel,
    this.printOptions,
    this.actions = const [],
    this.busy = false,
  });

  final Future<Object?> Function()? onPrint;
  final Future<Object?> Function() onSavePdf;
  final Future<Object?> Function()? onShare;
  final Future<Object?> Function()? onExcel;
  final Widget? printOptions;
  final List<DeptAccountingToolbarAction> actions;
  final bool busy;

  @override
  State<DeptAccountingExportToolbar> createState() =>
      _DeptAccountingExportToolbarState();
}

class _DeptAccountingExportToolbarState
    extends State<DeptAccountingExportToolbar> {
  _ExportAction? active;
  bool get locked => widget.busy || active != null;

  Future<void> run(
    _ExportAction action,
    Future<Object?> Function() callback,
  ) async {
    if (locked) return;
    setState(() => active = action);
    try {
      await callback();
    } finally {
      if (mounted) setState(() => active = null);
    }
  }

  Widget button(
    _ExportAction action,
    String label,
    IconData icon,
    Future<Object?> Function() callback,
  ) => DeptAccountingButton(
    label: label,
    icon: icon,
    variant:
        action == _ExportAction.print ||
            (widget.onPrint == null && action == _ExportAction.pdf)
        ? DeptAccountingButtonVariant.primary
        : DeptAccountingButtonVariant.secondary,
    loading: active == action,
    onPressed: locked ? null : () => run(action, callback),
  );

  @override
  Widget build(BuildContext context) => Theme(
    // Keep form controls and action buttons at the same visible height on
    // desktop, where adaptive density otherwise shrinks them differently.
    data: Theme.of(context).copyWith(visualDensity: VisualDensity.standard),
    child: LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: DeptAccountingSpace.lg,
        runSpacing: DeptAccountingSpace.md,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (widget.onPrint != null)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Wrap(
                spacing: DeptAccountingSpace.sm,
                runSpacing: DeptAccountingSpace.md,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  button(
                    _ExportAction.print,
                    'طباعة',
                    Icons.print_outlined,
                    widget.onPrint!,
                  ),
                  if (widget.printOptions != null)
                    ExcludeFocus(
                      excluding: locked,
                      child: AbsorbPointer(
                        absorbing: locked,
                        child: widget.printOptions!,
                      ),
                    ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: Wrap(
              spacing: DeptAccountingSpace.sm,
              runSpacing: DeptAccountingSpace.sm,
              children: [
                button(
                  _ExportAction.pdf,
                  'حفظ PDF',
                  Icons.file_download_outlined,
                  widget.onSavePdf,
                ),
                if (widget.onShare != null)
                  button(
                    _ExportAction.share,
                    'مشاركة',
                    Icons.share_outlined,
                    widget.onShare!,
                  ),
                if (widget.onExcel != null)
                  button(
                    _ExportAction.excel,
                    'تصدير Excel',
                    Icons.table_view_outlined,
                    widget.onExcel!,
                  ),
                if (widget.actions.isNotEmpty)
                  MenuAnchor(
                    style: MenuStyle(
                      backgroundColor: const WidgetStatePropertyAll(
                        DeptAccountingColors.surface,
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            DeptAccountingLayout.radius,
                          ),
                          side: const BorderSide(
                            color: DeptAccountingColors.border,
                          ),
                        ),
                      ),
                    ),
                    menuChildren: [
                      for (var i = 0; i < widget.actions.length; i++) ...[
                        if (i > 0 &&
                            widget.actions[i].destructive &&
                            !widget.actions[i - 1].destructive)
                          const Divider(),
                        MenuItemButton(
                          onPressed: locked
                              ? null
                              : widget.actions[i].onPressed,
                          style: widget.actions[i].destructive
                              ? const ButtonStyle(
                                  foregroundColor: WidgetStatePropertyAll(
                                    DeptAccountingColors.danger,
                                  ),
                                  iconColor: WidgetStatePropertyAll(
                                    DeptAccountingColors.danger,
                                  ),
                                )
                              : null,
                          leadingIcon: Icon(widget.actions[i].icon, size: 18),
                          child: Text(widget.actions[i].label),
                        ),
                      ],
                    ],
                    builder: (context, controller, child) =>
                        DeptAccountingButton(
                          label: 'المزيد من الإجراءات',
                          icon: Icons.more_horiz,
                          variant: DeptAccountingButtonVariant.quiet,
                          onPressed: locked
                              ? null
                              : () => controller.isOpen
                                    ? controller.close()
                                    : controller.open(),
                        ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
