import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/app_identity.dart';
import '../../../core/numbers.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import 'opening_stock_view_model.dart';

class OpeningStockPage extends StatefulWidget {
  const OpeningStockPage({
    super.key,
    required this.dependencies,
    required this.productId,
  });

  final AppDependencies dependencies;
  final String productId;

  @override
  State<OpeningStockPage> createState() => _OpeningStockPageState();
}

class _OpeningStockPageState extends State<OpeningStockPage> {
  late final vm = OpeningStockViewModel(
    widget.dependencies.catalog,
    widget.productId,
  );
  final quantity = TextEditingController();

  @override
  void dispose() {
    quantity.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: vm,
    builder: (context, _) {
      final d = widget.dependencies;
      final product = d.catalog.find(widget.productId);
      if (product == null) {
        return DeptAccountingStateView(
          state: DeptAccountingViewState.error,
          title: 'المنتج غير موجود',
          message: 'ارجع إلى قائمة المنتجات.',
          actionLabel: 'قائمة المنتجات',
          onAction: () => context.go('/catalog'),
        );
      }
      final unavailable = vm.unavailableReason;
      final currency = d.store.shop!.currencyLabel;
      final total = vm.total;
      return WorkPage(
        busy: vm.busy,
        desktopMaxWidth: DeptAccountingLayout.simpleFormWidth,
        title: 'المخزون الافتتاحي · ${product.name}',
        onBack: () => context.go('/catalog/${product.id}'),
        child: unavailable != null
            ? DeptAccountingStateView(
                state: DeptAccountingViewState.empty,
                title: 'المخزون الافتتاحي غير متاح',
                message: unavailable,
                actionLabel: product.service
                    ? 'بيانات المنتج'
                    : 'حركة المخزون والجرد',
                onAction: () => context.go(
                  product.service
                      ? '/catalog/${product.id}'
                      : '/inventory/${product.id}',
                ),
              )
            : SectionStack(
                children: [
                  ErrorNotice(vm.error),
                  const DeptAccountingNotice(
                    title: 'سجّل الكمية الموجودة لديك عند بدء استخدام $appName',
                    message: 'هذه الكمية مملوكة لك مسبقًا. للمشتريات الجديدة، سجّل فاتورة شراء. يتاح الافتتاح مرة واحدة قبل أول حركة للمنتج.',
                  ),
                  if (product.purchasePrice <= 0)
                    DeptAccountingPanel(
                      title: 'أضف تكلفة الوحدة أولًا',
                      description: 'تُحسب قيمة المخزون الافتتاحي من تكلفة الوحدة المسجّلة في بيانات المنتج.',
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DeptAccountingButton(
                          label: 'تعديل بيانات المنتج',
                          variant: DeptAccountingButtonVariant.secondary,
                          onPressed: () => context.go('/catalog/${product.id}'),
                        ),
                      ),
                    ),
                  DeptAccountingPanel(
                    title: 'الكمية والقيمة الافتتاحية',
                    description:
                        'تُقرأ تكلفة الوحدة تلقائيًا من بيانات المنتج.',
                    child: SectionStack.form(
                      children: [
                        DeptAccountingField(
                          label: 'الكمية الافتتاحية',
                          helper: product.fractional
                              ? 'بالوحدة الأساسية: ${product.unit} · حتى 3 منازل عشرية'
                              : 'بالوحدة الأساسية: ${product.unit} · وحدات كاملة فقط',
                          controller: quantity,
                          numeric: true,
                          enabled: product.purchasePrice > 0,
                          onChanged: vm.setQuantity,
                        ),
                        DeptAccountingSummaryLine(
                          label: 'تكلفة الوحدة لكل ${product.unit}',
                          value: Numbers.format(product.purchasePrice),
                          currency: currency,
                        ),
                        DeptAccountingSummaryLine(
                          label: 'قيمة المخزون الافتتاحي',
                          value: total == null ? '—' : Numbers.format(total),
                          currency: currency,
                          total: true,
                        ),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: DeptAccountingButton(
                            label: 'اعتماد المخزون الافتتاحي',
                            onPressed: total == null || total <= 0
                                ? null
                                : () async {
                                    if (await showDeptAccountingConfirmation(
                                          context,
                                          title: 'اعتماد المخزون الافتتاحي؟',
                                          message:
                                              'الكمية: ${quantity.text} ${product.unit}\nتكلفة الوحدة: ${Numbers.format(product.purchasePrice)} $currency\nالقيمة الإجمالية: ${Numbers.format(total)} $currency\nلا يمكن تعديل الافتتاح بعد اعتماده.',
                                          confirmLabel: 'اعتماد',
                                        ) &&
                                        mounted &&
                                        await vm.post() &&
                                        context.mounted) {
                                      showMessage(
                                        context,
                                        'تم اعتماد المخزون الافتتاحي',
                                      );
                                      context.go('/catalog');
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      );
    },
  );
}
