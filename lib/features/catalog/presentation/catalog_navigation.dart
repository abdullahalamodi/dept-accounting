import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/dukan_design_system.dart';

class CatalogNavigation extends StatelessWidget {
  const CatalogNavigation({
    super.key,
    required this.selected,
    required this.canManage,
  });
  final String selected;
  final bool canManage;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: DukanSpace.sm,
    runSpacing: DukanSpace.sm,
    children: [
      for (final item in [
        (path: '/catalog', label: 'المنتجات'),
        if (canManage) ...[
          (path: '/catalog/categories', label: 'التصنيفات'),
          (path: '/catalog/units', label: 'الوحدات'),
        ],
      ])
        DukanFilterChip(
          label: Text(item.label),
          selected: selected == item.path,
          onSelected: (_) => context.go(item.path),
        ),
    ],
  );
}
