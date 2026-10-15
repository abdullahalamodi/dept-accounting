import 'package:flutter/material.dart';

import '../theme/dukan_tokens.dart';

class DukanActionCard extends StatelessWidget {
  const DukanActionCard({
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
    color: DukanColors.background,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: DukanColors.border),
      borderRadius: BorderRadius.circular(DukanLayout.radius),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      hoverColor: DukanColors.primarySoft,
      focusColor: DukanColors.sage,
      child: Padding(
        padding: const EdgeInsets.all(DukanSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: DukanColors.primarySoft,
                borderRadius: BorderRadius.circular(DukanLayout.radius),
              ),
              child: Icon(icon, color: DukanColors.primary, size: 22),
            ),
            const SizedBox(height: DukanSpace.md),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: DukanSpace.xs),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: DukanColors.muted),
            ),
          ],
        ),
      ),
    ),
  );
}
