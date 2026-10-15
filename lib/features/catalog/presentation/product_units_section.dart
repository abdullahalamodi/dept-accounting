import 'package:flutter/material.dart';

import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dukan_design_system.dart';
import '../data/catalog_reference.dart';
import '../data/catalog_references_repository.dart';
import 'catalog_reference_field.dart';

class ProductUnitsSection extends StatelessWidget {
  const ProductUnitsSection({
    super.key,
    required this.repository,
    required this.unit,
    required this.alternateUnit,
    required this.factor,
    required this.fractional,
    required this.service,
    required this.enabled,
    required this.onFractionalChanged,
  });

  final CatalogReferencesRepository repository;
  final TextEditingController unit, alternateUnit, factor;

  String unitName(String id) =>
      repository
          .all(CatalogReferenceKind.unit)
          .where((r) => r.id == id)
          .firstOrNull
          ?.name ??
      '';
  final bool fractional, service, enabled;
  final ValueChanged<bool> onFractionalChanged;

  String? get _conversion {
    if (service ||
        alternateUnit.text.trim().isEmpty ||
        unit.text.trim().isEmpty) {
      return null;
    }
    try {
      final count = Numbers.parse(factor.text, decimals: 3);
      if (count < 1000) return null;
      return '1 ${unitName(alternateUnit.text)} = ${Numbers.format(count, decimals: 3)} ${unitName(unit.text)}';
    } on BusinessException {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      unit,
      alternateUnit,
      factor,
      repository.store,
    ]),
    builder: (context, _) {
      final conversion = _conversion;
      final hasAlternate = !service && alternateUnit.text.trim().isNotEmpty;
      final summary = [
        if (!service)
          if (hasAlternate)
            conversion ?? 'وحدة إضافية: ${unitName(alternateUnit.text)}'
          else
            'بدون وحدة إضافية',
        fractional ? 'يسمح بأجزاء من الوحدة' : 'وحدات كاملة فقط',
      ].join(' · ');
      return DukanPanel(
        title: 'الوحدات والكميات',
        description: service
            ? 'حدد الوحدة التي تقاس بها الخدمة.'
            : 'اختر الوحدة الأساسية، وأضف الكرتون أو الكيس عند الحاجة.',
        child: SectionStack.form(
          children: [
            CatalogReferenceField(
              repository: repository,
              kind: CatalogReferenceKind.unit,
              excludeId: alternateUnit.text,
              label: 'الوحدة الأساسية',
              helper: service
                  ? 'مثال: ساعة للخدمة التي تحسب بالوقت.'
                  : 'المخزون والأسعار يسجلان بهذه الوحدة.',
              controller: unit,
              enabled: enabled,
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(top: DukanSpace.lg),
              initiallyExpanded: hasAlternate || fractional,
              maintainState: true,
              title: const Text('إعدادات الوحدات المتقدمة'),
              subtitle: Text(summary, style: DukanTypography.label),
              children: [
                SectionStack.form(
                  children: [
                    if (!service) ...[
                      FieldGrid(
                        children: [
                          CatalogReferenceField(
                            repository: repository,
                            kind: CatalogReferenceKind.unit,
                            optional: true,
                            excludeId: unit.text,
                            label: 'وحدة إضافية (اختياري)',
                            helper: 'اتركها فارغة إذا كنت تستخدم الوحدة الأساسية فقط.',
                            controller: alternateUnit,
                            enabled: enabled,
                          ),
                          if (hasAlternate)
                            DukanField(
                              label: 'عدد الوحدات الأساسية',
                              hint: 'مثال: 12',
                              helper: 'كرتون يحتوي على 12 حبة؟ أدخل 12.',
                              controller: factor,
                              numeric: true,
                              enabled: enabled,
                            ),
                        ],
                      ),
                      if (conversion != null)
                        DukanNotice(
                          title: conversion,
                          message: 'تتحول الكمية تلقائيًا عند اختيار الوحدة الإضافية في الفاتورة.',
                          tone: DukanTone.info,
                        ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('السماح ببيع أجزاء من الوحدة'),
                      subtitle: const Text(
                        'فعّلها لبيع نصف كيلو أو ربع متر. اتركها مغلقة للحبة التي تباع كاملة.',
                      ),
                      value: fractional,
                      onChanged: enabled ? onFractionalChanged : null,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}
