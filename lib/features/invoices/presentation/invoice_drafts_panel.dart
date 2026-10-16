import '../data/invoices_tasks.dart';
import '../../../core/ui/database_query.dart';

import 'package:flutter/material.dart';

import '../../../design_system/dept_accounting_design_system.dart';
import '../data/invoice_repository.dart';
import 'invoice_drafts_view_model.dart';

class InvoiceDraftsPanel extends StatefulWidget {
  const InvoiceDraftsPanel({
    super.key,
    required this.repository,
    required this.kind,
    required this.title,
    required this.onOpen,
  });
  final InvoiceRepository repository;
  final String kind, title;
  final ValueChanged<InvoiceDraft> onOpen;
  @override
  State<InvoiceDraftsPanel> createState() => _InvoiceDraftsPanelState();
}

class _InvoiceDraftsPanelState extends State<InvoiceDraftsPanel> {
  late var vm = InvoiceDraftsViewModel(widget.repository, widget.kind);
  @override
  void didUpdateWidget(covariant InvoiceDraftsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.kind != widget.kind) {
      vm.dispose();
      vm = InvoiceDraftsViewModel(widget.repository, widget.kind);
    }
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, widget.repository.store]),
    builder: (context, _) {
      return DatabaseQuery(
        store: widget.repository.store,
        task: InvoiceTasks.drafts(widget.kind, page: vm.page),
        queryKey: (widget.kind, vm.page),
        builder: (context, results) {
          if (results.total == 0) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: DeptAccountingSpace.xl),
            child: DeptAccountingPanel(
              title: widget.title,
              child: DeptAccountingDataTable(
                minWidth: 280,
                columns: const [
                  DataColumn(label: Text('آخر حفظ')),
                  DataColumn(label: Text('الإجراء')),
                ],
                rows: [
                  for (final draft in results.items)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            draft.updatedAt
                                .substring(0, 16)
                                .replaceAll('T', ' '),
                          ),
                        ),
                        DataCell(
                          DeptAccountingButton.table(
                            onPressed: () => widget.onOpen(draft),
                            label: 'استكمال',
                          ),
                        ),
                      ],
                    ),
                ],
                totalRows: results.total,
                page: results.page,
                pageSize: 5,
                onPageChanged: vm.go,
              ),
            ),
          );
        },
      );
    },
  );
}
