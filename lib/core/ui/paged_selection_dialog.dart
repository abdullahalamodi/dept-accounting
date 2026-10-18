import 'dart:async';

import 'package:flutter/material.dart';

import '../../design_system/dept_accounting_design_system.dart';
import '../data/query_page.dart';
import 'async_query_view_model.dart';
import 'form_widgets.dart';

class PagedSelectionDialog<T> extends StatefulWidget {
  const PagedSelectionDialog({
    super.key,
    required this.title,
    required this.searchLabel,
    required this.load,
    required this.columns,
    required this.cells,
    required this.onSelected,
    this.selectLabel = 'اختيار',
    this.width = 560,
    this.minWidth = 280,
    this.beforeTable,
    this.actions = const [],
  });
  final String title, searchLabel, selectLabel;
  final Future<QueryPage<T>> Function(String search, int page) load;
  final List<DataColumn> columns;
  final List<DataCell> Function(T item) cells;
  final ValueChanged<T> onSelected;
  final double width, minWidth;
  final Widget? beforeTable;
  final List<Widget> actions;
  @override
  State<PagedSelectionDialog<T>> createState() =>
      _PagedSelectionDialogState<T>();
}

class _PagedSelectionDialogState<T> extends State<PagedSelectionDialog<T>> {
  final vm = AsyncQueryViewModel<QueryPage<T>>();
  String search = '';
  int page = 1;
  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => unawaited(vm.load(() => widget.load(search, page)));
  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final content = SizedBox(
        width: widget.width,
        child: SingleChildScrollView(
          child: SectionStack.form(
            children: [
              DeptAccountingField(
                label: widget.searchLabel,
                autofocus: true,
                onChanged: (value) {
                  search = value;
                  page = 1;
                  _load();
                },
              ),
              if (widget.beforeTable != null) widget.beforeTable!,
              if (vm.loading)
                const DeptAccountingStateView(
                  state: DeptAccountingViewState.loading,
                  title: 'جارٍ التحميل',
                  message: '',
                )
              else if (vm.error != null)
                DeptAccountingStateView(
                  state: DeptAccountingViewState.error,
                  title: 'تعذر تحميل النتائج',
                  message: vm.error!,
                  actionLabel: 'إعادة المحاولة',
                  onAction: _load,
                )
              else if (vm.value case final results?)
                DeptAccountingDataTable(
                  minWidth: widget.minWidth,
                  compactRowBuilder: (context, index) {
                    final item = results.items[index];
                    final cells = widget.cells(item);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                      title: cells.first.child,
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            for (final cell in cells.skip(1)) cell.child,
                          ],
                        ),
                      ),
                      trailing: DeptAccountingButton.table(
                        label: widget.selectLabel,
                        onPressed: () => widget.onSelected(item),
                      ),
                      onTap: () => widget.onSelected(item),
                    );
                  },
                  columns: [
                    ...widget.columns,
                    const DataColumn(label: Text('الإجراء')),
                  ],
                  rows: [
                    for (final item in results.items)
                      DataRow(
                        cells: [
                          ...widget.cells(item),
                          DataCell(
                            DeptAccountingButton.table(
                              label: widget.selectLabel,
                              onPressed: () => widget.onSelected(item),
                            ),
                          ),
                        ],
                      ),
                  ],
                  totalRows: results.total,
                  page: results.page,
                  pageSize: 5,
                  onPageChanged: (value) {
                    page = value;
                    _load();
                  },
                ),
            ],
          ),
        ),
      );
      final actions = <Widget>[
        ...widget.actions,
        DeptAccountingButton(
          label: 'إغلاق',
          variant: DeptAccountingButtonVariant.quiet,
          onPressed: () => Navigator.pop(context),
        ),
      ];
      if (MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                widget.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: content,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 8, runSpacing: 8, children: actions),
            ),
          ],
        );
      }
      return AlertDialog(
        title: Text(widget.title),
        content: content,
        actions: actions,
      );
    },
  );
}
