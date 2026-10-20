import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/dept_accounting_design_system.dart';

class CatalogNavigation extends StatelessWidget {
  const CatalogNavigation({
    super.key,
    required this.selected,
    required this.canManage,
  });
  final String selected;
  final bool canManage;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= DeptAccountingLayout.compact
      ? DeptAccountingSectionTabs<String>(
          value: selected,
          items: [
            (value: '/catalog', label: 'المنتجات'),
            if (canManage) ...[
              (value: '/catalog/categories', label: 'التصنيفات'),
              (value: '/catalog/units', label: 'الوحدات'),
            ],
          ],
          onChanged: context.go,
        )
      : Wrap(
          spacing: DeptAccountingSpace.sm,
          runSpacing: DeptAccountingSpace.sm,
          children: [
            for (final item in [
              (path: '/catalog', label: 'المنتجات'),
              if (canManage) ...[
                (path: '/catalog/categories', label: 'التصنيفات'),
                (path: '/catalog/units', label: 'الوحدات'),
              ],
            ])
              DeptAccountingFilterChip(
                label: Text(item.label),
                selected: selected == item.path,
                onSelected: (_) => context.go(item.path),
              ),
          ],
        );
}
