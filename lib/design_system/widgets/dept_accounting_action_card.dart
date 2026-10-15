import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';

class DeptAccountingActionCard extends StatelessWidget {
  const DeptAccountingActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });
  final String title, description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: DeptAccountingColors.background,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: DeptAccountingColors.border),
      borderRadius: BorderRadius.circular(DeptAccountingLayout.radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      hoverColor: DeptAccountingColors.primarySoft,
      focusColor: DeptAccountingColors.sage,
      child: Padding(
        padding: const EdgeInsets.all(DeptAccountingSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: DeptAccountingColors.primarySoft,
                borderRadius: BorderRadius.circular(
                  DeptAccountingLayout.radius,
                ),
              ),
              child: Icon(icon, color: DeptAccountingColors.primary, size: 22),
            ),
            const SizedBox(height: DeptAccountingSpace.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DeptAccountingSpace.xs),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: DeptAccountingColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
