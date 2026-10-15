import 'package:flutter/material.dart';

import '../theme/dukan_tokens.dart';
import 'dukan_controls.dart';

class DukanDataTable extends StatefulWidget {
  const DukanDataTable({
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
  final double? columnSpacing;
  final double? horizontalMargin;

  @override
  State<DukanDataTable> createState() => _DukanDataTableState();
}

class _DukanDataTableState extends State<DukanDataTable> {
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
          DukanStateView(
            state: DukanViewState.empty,
            title: widget.emptyTitle,
            message: widget.emptyMessage,
          )
        else
          LayoutBuilder(
            builder: (context, constraints) => Scrollbar(
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
                    columnSpacing: widget.columnSpacing,
                    horizontalMargin: widget.horizontalMargin,
                    columns: widget.columns,
                    rows: widget.rows,
                    showCheckboxColumn: false,
                  ),
                ),
              ),
            ),
          ),
        if (widget.showPagination) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Text(
                  '$start–$end من ${widget.totalRows}',
                  style: const TextStyle(color: DukanColors.muted),
                ),
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (widget.onPageSizeChanged != null)
                      DropdownButton<int>(
                        style: DukanTypography.control,
                        value: widget.pageSize,
                        underline: const SizedBox.shrink(),
                        items: [5, 10, 20]
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text('$n / صفحة'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) widget.onPageSizeChanged!(value);
                        },
                      ),
                    IconButton(
                      tooltip: 'الصفحة السابقة',
                      onPressed: page > 1
                          ? () => widget.onPageChanged(page - 1)
                          : null,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_right
                            : Icons.chevron_left,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                    Text('$page / $count'),
                    IconButton(
                      tooltip: 'الصفحة التالية',
                      onPressed: page < count
                          ? () => widget.onPageChanged(page + 1)
                          : null,
                      icon: Icon(
                        Directionality.of(context) == TextDirection.rtl
                            ? Icons.chevron_left
                            : Icons.chevron_right,
                        textDirection: TextDirection.ltr,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
