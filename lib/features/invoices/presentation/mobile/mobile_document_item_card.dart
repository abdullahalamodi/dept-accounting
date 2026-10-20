import 'package:flutter/material.dart';

import '../../../../core/numbers.dart';
import '../../../../design_system/dept_accounting_design_system.dart';
import '../../data/document.dart';

class MobileDocumentItemCard extends StatelessWidget {
  const MobileDocumentItemCard({
    super.key,
    required this.line,
    required this.currency,
    required this.total,
  });

  final InvoiceLine line;
  final String currency;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DeptAccountingSpace.md),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(line.name, style: DeptAccountingTypography.control),
              const SizedBox(height: DeptAccountingSpace.xs),
              Text(
                '${Numbers.format(line.quantity, decimals: 3)} ${line.unit}',
                style: DeptAccountingTypography.label,
              ),
            ],
          ),
        ),
        const SizedBox(width: DeptAccountingSpace.md),
        Expanded(
          flex: 2,
          child: Align(
            alignment: AlignmentDirectional.topEnd,
            child: Semantics(
              label: 'إجمالي البند',
              child: DeptAccountingAmount(
                Numbers.format(total),
                currency: currency,
                emphasized: true,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
