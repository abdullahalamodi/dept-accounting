import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';
import 'dept_accounting_controls.dart';
import 'dept_accounting_mobile.dart';

class DeptAccountingDataTable extends StatefulWidget {
  const DeptAccountingDataTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.totalRows,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
    this.onPageSizeChanged,
    this.emptyTitle = 'لا توجد نتائج',
    this.emptyMessage = 'جرّب البحث باسم آخر أو غيّر عوامل التصفية.',
    this.minWidth = 700,
    this.showPagination = true,
    this.compactRowBuilder,
    this.columnSpacing,
    this.horizontalMargin,
  }) : assert(pageSize > 0),
       assert(totalRows >= 0),
       assert(page >= 1);
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final int totalRows;
  final int page;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int>? onPageSizeChanged;
  final String emptyTitle;
  final String emptyMessage;
  final double minWidth;
  final bool showPagination;
  final Widget Function(BuildContext context, int index)? compactRowBuilder;
  final double? columnSpacing;
  final double? horizontalMargin;

  @override
  State<DeptAccountingDataTable> createState() =>
      _DeptAccountingDataTableState();
}

class _DeptAccountingDataTableState extends State<DeptAccountingDataTable> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = (widget.totalRows / widget.pageSize).ceil().clamp(1, 1 << 30);
    final page = widget.page.clamp(1, count);
    final start = widget.totalRows == 0 ? 0 : (page - 1) * widget.pageSize + 1;
    final end = (page * widget.pageSize).clamp(0, widget.totalRows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.rows.isEmpty)
          DeptAccountingStateView(
            state: DeptAccountingViewState.empty,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) =>
                MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact
                ? ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.rows.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) =>
                        widget.compactRowBuilder?.call(context, index) ??
                        DeptAccountingCompactDataRow(
                          columns: widget.columns,
                          row: widget.rows[index],
                        ),
                  )
                : Scrollbar(
                    controller: _horizontal,
                    thumbVisibility: true,
                    notificationPredicate: (notification) =>
                        notification.metrics.axis == Axis.horizontal,
                    child: SingleChildScrollView(
                      controller: _horizontal,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(bottom: 10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: constraints.maxWidth > widget.minWidth
                              ? constraints.maxWidth
                              : widget.minWidth,
                        ),
                        child: DataTable(
                          columnSpacing: widget.columnSpacing ?? 24,
                          horizontalMargin: widget.horizontalMargin ?? 16,
                          dataRowMinHeight: 52,
                          headingRowHeight: 44,
                          columns: widget.columns,
                          rows: [
                            for (final row in widget.rows)
                              DataRow(
                                key: row.key,
                                selected: row.selected,
                                onSelectChanged: row.onSelectChanged,
                                onLongPress: row.onLongPress,
                                color: row.color,
                                mouseCursor: row.mouseCursor,
                                cells: [
                                  for (final cell in row.cells)
                                    DataCell(
                                      _DesktopCell(child: cell.child),
                                      placeholder: cell.placeholder,
                                      showEditIcon: cell.showEditIcon,
                                      onTap: cell.onTap,
                                      onDoubleTap: cell.onDoubleTap,
                                      onLongPress: cell.onLongPress,
                                      onTapDown: cell.onTapDown,
                                      onTapCancel: cell.onTapCancel,
                                    ),
                                ],
                              ),
                          ],
                          showCheckboxColumn: false,
                        ),
                      ),
                    ),
                  ),
          ),
        if (widget.showPagination &&
            (MediaQuery.sizeOf(context).width >= DeptAccountingLayout.compact ||
                widget.totalRows > widget.pageSize)) ...[
          const Divider(),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal:
                  MediaQuery.sizeOf(context).width <
                      DeptAccountingLayout.compact
                  ? 24
                  : 16,
              vertical:
                  MediaQuery.sizeOf(context).width <
                      DeptAccountingLayout.compact
                  ? 16
                  : 12,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final range = Text(
                  'عرض $start–$end من ${widget.totalRows}',
                  style: DeptAccountingTypography.tableBody.copyWith(
                    color: DeptAccountingColors.muted,
                  ),
                );
                final pageSize = widget.onPageSizeChanged == null
                    ? null
                    : _PageSizeSelector(
                        value: widget.pageSize,
                        onChanged: widget.onPageSizeChanged!,
                      );
                final navigation = _PageNavigation(
                  page: page,
                  count: count,
                  onChanged: widget.onPageChanged,
                );
                if (constraints.maxWidth < 900) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 16,
                        runSpacing: 12,
                        children: [range, ?pageSize],
                      ),
                      const SizedBox(height: 12),
                      navigation,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: range),
                    ?pageSize,
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: navigation,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PageSizeSelector extends StatefulWidget {
  const _PageSizeSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_PageSizeSelector> createState() => _PageSizeSelectorState();
}

class _PageSizeSelectorState extends State<_PageSizeSelector> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textHeight =
        MediaQuery.textScalerOf(context)
            .scale(DeptAccountingTypography.tableBody.fontSize!) *
        DeptAccountingTypography.tableBody.height!;
    final height = (textHeight + 12).clamp(
      DeptAccountingLayout.paginationControlHeight,
      double.infinity,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'صفوف الصفحة',
          style: DeptAccountingTypography.caption.copyWith(
            color: DeptAccountingColors.muted,
          ),
        ),
        const SizedBox(width: 10),
        Theme(
          data: Theme.of(context).copyWith(
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
          ),
          child: ListenableBuilder(
            listenable: _focusNode,
            builder: (context, _) => Container(
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _focusNode.hasFocus
                      ? DeptAccountingColors.primary
                      : DeptAccountingColors.border,
                ),
                borderRadius: BorderRadius.circular(
                  DeptAccountingLayout.radius,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: widget.value,
                  focusNode: _focusNode,
                  focusColor: Colors.transparent,
                  isDense: true,
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(
                    DeptAccountingLayout.radius,
                  ),
                  style: DeptAccountingTypography.tableBody,
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: DeptAccountingColors.muted,
                  ),
                  items: ({5, 10, 20, widget.value}.toList()..sort())
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) widget.onChanged(value);
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PageNavigation extends StatelessWidget {
  const _PageNavigation({
    required this.page,
    required this.count,
    required this.onChanged,
  });

  final int page;
  final int count;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final first = (page - 1).clamp(1, (count - 2).clamp(1, count));
    final last = (first + 2).clamp(1, count);
    final pages = {1, for (var i = first; i <= last; i++) i, count}.toList()
      ..sort();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _PageButton(
          label: 'السابق',
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
        ),
        for (var i = 0; i < pages.length; i++) ...[
          if (i > 0 && pages[i] - pages[i - 1] > 1)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 2, vertical: 8),
              child: Text('…', style: DeptAccountingTypography.tableBody),
            ),
          _PageButton(
            label: '${pages[i]}',
            selected: pages[i] == page,
            onPressed: () => onChanged(pages[i]),
          ),
        ],
        _PageButton(
          label: 'التالي',
          onPressed: page < count ? () => onChanged(page + 1) : null,
        ),
      ],
    );
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({
    required this.label,
    required this.onPressed,
    this.selected = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: TextButton(
      onPressed: onPressed,
      style:
          TextButton.styleFrom(
            textStyle: DeptAccountingTypography.tableBody,
            foregroundColor: selected
                ? DeptAccountingColors.primary
                : DeptAccountingColors.ink,
            disabledForegroundColor: DeptAccountingColors.muted.withValues(
              alpha: 0.45,
            ),
            backgroundColor: selected
                ? DeptAccountingColors.primarySoft
                : DeptAccountingColors.surface,
            minimumSize: const Size(
              DeptAccountingLayout.paginationControlHeight,
              DeptAccountingLayout.paginationControlHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            splashFactory: NoSplash.splashFactory,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DeptAccountingLayout.radius),
            ),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? DeptAccountingColors.primary
                    : selected
                    ? DeptAccountingColors.chartSecondary
                    : DeptAccountingColors.border,
                width: states.contains(WidgetState.focused) ? 2 : 1,
              ),
            ),
          ),
      child: Text(label),
    ),
  );
}

class _DesktopCell extends StatelessWidget {
  const _DesktopCell({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: DefaultTextStyle.merge(
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        child: child,
      ),
    );
    return child is Text
        ? Tooltip(
            message:
                (child as Text).data ??
                (child as Text).textSpan?.toPlainText() ??
                '',
            child: content,
          )
        : content;
  }
}
