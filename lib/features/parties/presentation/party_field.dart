import '../data/parties_tasks.dart';

import 'package:flutter/material.dart';

import '../../../design_system/dept_accounting_design_system.dart';
import '../../../core/ui/paged_selection_dialog.dart';
import '../data/party.dart';
import '../data/party_repository.dart';

class PartyField extends StatelessWidget {
  const PartyField({
    super.key,
    required this.repository,
    required this.customer,
    required this.label,
    required this.emptyLabel,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final PartyRepository repository;
  final bool customer, enabled;
  final String label, emptyLabel;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final party = value == null ? null : repository.find(value!);
    return DeptAccountingField(
      key: ValueKey((label, party?.id, party?.name)),
      label: label,
      initialValue: party?.name ?? emptyLabel,
      readOnly: true,
      enabled: enabled,
      suffixIcon: const Icon(Icons.expand_more),
      onTap: !enabled
          ? null
          : () async {
              final id = await showDialog<String>(
                context: context,
                builder: (dialogContext) => PagedSelectionDialog<Party>(
                  title: customer ? 'اختيار العميل' : 'اختيار المورد',
                  searchLabel: 'بحث بالاسم أو الهاتف',
                  minWidth: 400,
                  load: (search, page) => repository.store.run(
                    PartyTasks.page(
                      search: search,
                      page: page,
                      pageSize: 5,
                      activeOnly: true,
                      customer: customer,
                    ),
                  ),
                  columns: const [
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('الهاتف')),
                  ],
                  cells: (party) => [
                    DataCell(Text(party.name)),
                    DataCell(Text(party.phone.isEmpty ? '—' : party.phone)),
                  ],
                  onSelected: (party) => Navigator.pop(dialogContext, party.id),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, ''),
                      child: Text(emptyLabel),
                    ),
                  ],
                ),
              );
              if (context.mounted && id != null) {
                onChanged(id.isEmpty ? null : id);
              }
            },
    );
  }
}
