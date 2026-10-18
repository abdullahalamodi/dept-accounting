import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';

/// A readable, touch-sized record shared by compact feature lists.
class DeptAccountingRecordTile extends StatelessWidget {
  const DeptAccountingRecordTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading = Icons.description_outlined,
    this.trailing,
    this.details,
    this.onTap,
  });
  final String title;
  final String? subtitle;
  final IconData leading;
  final Widget? trailing, details;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: DeptAccountingColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: DeptAccountingColors.border),
      borderRadius: BorderRadius.circular(DeptAccountingLayout.panelRadius),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(DeptAccountingSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: DeptAccountingColors.primarySoft,
                    borderRadius: BorderRadius.circular(
                      DeptAccountingLayout.radius,
                    ),
                  ),
                  child: Icon(
                    leading,
                    size: 21,
                    color: DeptAccountingColors.primary,
                  ),
                ),
                const SizedBox(width: DeptAccountingSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: DeptAccountingColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onTap != null)
                  const Padding(
                    padding: EdgeInsetsDirectional.only(start: 8, top: 10),
                    child: Icon(
                      Icons.chevron_left,
                      size: 18,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
            if (details != null || trailing != null) ...[
              const SizedBox(height: DeptAccountingSpace.md),
              const Divider(height: 1),
              const SizedBox(height: DeptAccountingSpace.md),
              ?details,
              if (trailing != null)
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: trailing!,
                ),
            ],
          ],
        ),
      ),
    ),
  );
}

/// Makes paged table records readable without horizontal scrolling.
class DeptAccountingCompactDataRow extends StatelessWidget {
  const DeptAccountingCompactDataRow({
    super.key,
    required this.columns,
    required this.row,
  });
  final List<DataColumn> columns;
  final DataRow row;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(DeptAccountingSpace.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < row.cells.length; i++) ...[
          if (i > 0) const SizedBox(height: DeptAccountingSpace.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(
                    fontSize: 12,
                    color: DeptAccountingColors.muted,
                  ),
                  child: columns[i].label,
                ),
              ),
              const SizedBox(width: DeptAccountingSpace.md),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: row.cells[i].onTap == null
                      ? row.cells[i].child
                      : InkWell(
                          onTap: row.cells[i].onTap,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: row.cells[i].child,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

Future<T?> showDeptAccountingAdaptiveDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  if (MediaQuery.sizeOf(context).width >= DeptAccountingLayout.compact) {
    return showDialog<T>(context: context, builder: builder);
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .9,
        ),
        child: builder(context),
      ),
    ),
  );
}
