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
    builder: (context, _) => AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
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
                            TextButton(
                              onPressed: () => widget.onSelected(item),
                              child: Text(widget.selectLabel),
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
      ),
      actions: [
        ...widget.actions,
        DeptAccountingButton(
          label: 'إغلاق',
          variant: DeptAccountingButtonVariant.quiet,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    ),
  );
}
