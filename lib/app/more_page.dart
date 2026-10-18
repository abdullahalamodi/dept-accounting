import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/ui/form_widgets.dart';
import '../design_system/dept_accounting_design_system.dart';
import 'dependencies.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    final user = dependencies.store.user!;
    final destinations = [
      (
        path: '/parties',
        title: 'العملاء والموردون',
        subtitle: 'البيانات وكشوف الحسابات',
        icon: Icons.people_outline,
      ),
      if (user.canManage) ...[
        (
          path: '/inventory',
          title: 'المخزون',
          subtitle: 'الكميات وحركة المنتجات والجرد',
          icon: Icons.warehouse_outlined,
        ),
        (
          path: '/purchases',
          title: 'المشتريات',
          subtitle: 'فواتير الموردين والمدفوعات',
          icon: Icons.shopping_bag_outlined,
        ),
        (
          path: '/receiving',
          title: 'الاستلام السريع',
          subtitle: 'استلام المخزون وتسوية التكلفة',
          icon: Icons.local_shipping_outlined,
        ),
        (
          path: '/reports',
          title: 'التقارير والمحاسبة',
          subtitle: 'نتائج المحل والقيود ودفتر الأستاذ',
          icon: Icons.bar_chart_outlined,
        ),
      ],
      if (user.isOwner)
        (
          path: '/settings',
          title: 'الإعدادات والنسخ',
          subtitle: 'المحل والمستخدمون وحماية البيانات',
          icon: Icons.settings_outlined,
        ),
      if (dependencies.store.setting('pos_enabled') == 'true')
        (
          path: '/pos/${dependencies.store.id()}',
          title: 'نقطة البيع',
          subtitle: 'إنشاء فاتورة سريعة',
          icon: Icons.point_of_sale_outlined,
        ),
    ];
    return SectionStack(
      children: [
        const DeptAccountingPageHeader(
          title: 'المزيد',
          description: 'كل ما تحتاجه لإدارة محلك',
        ),
        DeptAccountingRecordTile(
          title: user.displayName,
          subtitle: '${user.roleLabel} · ${dependencies.store.shop!.name}',
          leading: Icons.person_outline,
          onTap: () => context.go('/profile'),
        ),
        for (final item in destinations)
          DeptAccountingRecordTile(
            title: item.title,
            subtitle: item.subtitle,
            leading: item.icon,
            onTap: () => context.go(item.path),
          ),
      ],
    );
  }
}
