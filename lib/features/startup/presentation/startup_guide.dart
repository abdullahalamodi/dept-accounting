import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/dependencies.dart';
import '../../../core/ui/form_widgets.dart';
import '../../../design_system/dept_accounting_design_system.dart';
import '../data/startup_guide_repository.dart';
import 'startup_guide_view_model.dart';

class StartupGuide extends StatefulWidget {
  const StartupGuide({super.key, required this.dependencies});
  final AppDependencies dependencies;

  @override
  State<StartupGuide> createState() => _StartupGuideState();
}

class _StartupGuideState extends State<StartupGuide> {
  late final vm = StartupGuideViewModel(
    widget.dependencies.startupGuide,
    backupStatus: widget.dependencies.backups.status,
  );

  Future<void> open(StartupGuideStep step) async {
    if (await vm.start() && mounted) context.go(step.path);
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([vm, vm.query]),
    builder: (context, _) {
      if (vm.query.error != null) {
        return DeptAccountingStateView(
          state: DeptAccountingViewState.error,
          title: 'تعذر تحميل دليل البداية',
          message: vm.query.error!,
          actionLabel: 'إعادة المحاولة',
          onAction: vm.refresh,
        );
      }
      if (!vm.available) return const SizedBox.shrink();
      if (!vm.visible) {
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: DeptAccountingButton(
            label: 'دليل تجهيز المحل',
            icon: Icons.checklist_outlined,
            variant: DeptAccountingButtonVariant.quiet,
            onPressed: vm.start,
          ),
        );
      }
      final next = vm.next;
      return DeptAccountingPanel(
        title: next == null
            ? 'اكتملت مراجعة خطوات البداية'
            : 'جهّز محلك خطوة بخطوة',
        description: next == null
            ? 'يمكنك الرجوع لأي خطوة، وإعادة الخطوات التي تجاوزتها عند الحاجة.'
            : 'ابدأ بالأهم، وتابع تقدمك هنا. يمكنك تجاوز ما لا تحتاجه الآن.',
        action: DeptAccountingStatusTag(
          '${vm.resolvedCount} من ${vm.steps.length} خطوات',
          tone: next == null
              ? DeptAccountingTone.success
              : DeptAccountingTone.info,
        ),
        child: SectionStack.form(
          children: [
            if (next != null) ...[
              Semantics(
                value: '${vm.resolvedCount} من ${vm.steps.length}',
                label: 'تقدم تجهيز المحل',
                child: LinearProgressIndicator(
                  value: vm.resolvedCount / vm.steps.length,
                  backgroundColor: DeptAccountingColors.primarySoft,
                  color: DeptAccountingColors.primary,
                  borderRadius: BorderRadius.circular(
                    DeptAccountingLayout.radius,
                  ),
                ),
              ),
              Text(
                'الخطوة التالية: ${next.title}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(next.message),
              Wrap(
                spacing: DeptAccountingSpace.sm,
                runSpacing: DeptAccountingSpace.sm,
                children: [
                  DeptAccountingButton(
                    label: next.action,
                    onPressed: () => open(next),
                  ),
                  if (next.reviewLabel != null)
                    DeptAccountingButton(
                      label: next.reviewLabel!,
                      variant: DeptAccountingButtonVariant.secondary,
                      onPressed: () => vm.review(next.task),
                    ),
                  if (next.skipLabel != null)
                    DeptAccountingButton(
                      label: next.skipLabel!,
                      variant: DeptAccountingButtonVariant.quiet,
                      onPressed: () => vm.review(next.task, skip: true),
                    ),
                ],
              ),
            ],
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                next == null
                    ? 'مراجعة خطوات البداية'
                    : 'كل خطوات البداية بالترتيب',
              ),
              children: [
                for (var i = 0; i < vm.steps.length; i++)
                  _StepRow(
                    step: vm.steps[i],
                    number: i + 1,
                    current: vm.steps[i] == next,
                    onOpen: () => open(vm.steps[i]),
                    onRevisit: () => vm.revisit(vm.steps[i].task),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.number,
    required this.current,
    required this.onOpen,
    required this.onRevisit,
  });
  final StartupGuideStep step;
  final int number;
  final bool current;
  final VoidCallback onOpen, onRevisit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: DeptAccountingSpace.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DeptAccountingSpace.md),
          child: step.complete
              ? const Icon(
                  Icons.check_circle_outline,
                  color: DeptAccountingColors.primary,
                )
              : Text(
                  '$number.',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
        ),
        const SizedBox(width: DeptAccountingSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: DeptAccountingSpace.sm,
                runSpacing: DeptAccountingSpace.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    step.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  DeptAccountingStatusTag(
                    step.complete
                        ? 'مكتملة'
                        : step.skipped
                        ? 'غير مطلوبة الآن'
                        : current
                        ? 'الخطوة التالية'
                        : 'لم تبدأ',
                    tone: step.complete
                        ? DeptAccountingTone.success
                        : current
                        ? DeptAccountingTone.info
                        : DeptAccountingTone.neutral,
                  ),
                  DeptAccountingButton(
                    label: step.skipped ? 'إعادة الخطوة' : step.action,
                    variant: DeptAccountingButtonVariant.quiet,
                    onPressed: step.skipped ? onRevisit : onOpen,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
