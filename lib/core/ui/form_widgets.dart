import 'package:flutter/material.dart';

import '../../design_system/dept_accounting_design_system.dart';
import '../app_identity.dart';
import '../numbers.dart';

class SectionStack extends StatelessWidget {
  const SectionStack({super.key, required this.children})
    : spacing = DeptAccountingSpace.xl;
  const SectionStack.form({super.key, required this.children})
    : spacing = DeptAccountingSpace.formGap;
  final List<Widget> children;
  final double spacing;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(height: spacing),
        children[i],
      ],
    ],
  );
}

class FieldGrid extends StatelessWidget {
  const FieldGrid({
    super.key,
    required this.children,
    this.minWidth = 260,
    this.runSpacing = DeptAccountingSpace.formGap,
  });
  final List<Widget> children;
  final double minWidth;
  final double runSpacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count =
          ((c.maxWidth + DeptAccountingSpace.lg) /
                  (minWidth + DeptAccountingSpace.lg))
              .floor()
              .clamp(1, children.length.clamp(1, 3));
      final width = (c.maxWidth - DeptAccountingSpace.lg * (count - 1)) / count;
      return Wrap(
        spacing: DeptAccountingSpace.lg,
        runSpacing: runSpacing,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class ChoiceField<T> extends StatelessWidget {
  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.compact = false,
  });
  final String label;
  final T? value;
  final List<({T value, String label})> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  final bool compact;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    style: compact
        ? DeptAccountingTypography.compactControl
        : DeptAccountingTypography.control,
    iconSize: 20,
    decoration: InputDecoration(
      labelText: label.isEmpty ? null : label,
      constraints: compact
          ? const BoxConstraints(
              minHeight: DeptAccountingLayout.compactControlHeight,
            )
          : null,
      contentPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
          : null,
    ),
    items: [
      for (final item in items)
        DropdownMenuItem(
          value: item.value,
          child: Text(item.label, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: enabled ? onChanged : null,
  );
}

String errorMessage(Object error) => error is BusinessException
    ? error.message
    : 'تعذر إكمال العملية. لم تُعتمد تغييرات جزئية. حاول مرة أخرى.';
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class ActionViewModel extends ChangeNotifier {
  bool busy = false;
  bool _disposed = false;
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String? error;
  Future<bool> run(Future<void> Function() action) async {
    if (busy) return false;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await action();
      return true;
    } catch (e) {
      error = errorMessage(e);
      return false;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  bool perform(void Function() action) {
    error = null;
    try {
      action();
      notifyListeners();
      return true;
    } catch (e) {
      error = errorMessage(e);
      notifyListeners();
      return false;
    }
  }

  void changed() {
    error = null;
    notifyListeners();
  }
}

class ErrorNotice extends StatelessWidget {
  const ErrorNotice(this.error, {super.key});
  final String? error;
  @override
  Widget build(BuildContext context) => error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: DeptAccountingSpace.lg),
          child: DeptAccountingNotice(
            title: 'راجع البيانات',
            message: error!,
            tone: DeptAccountingTone.danger,
          ),
        );
}

class WorkPage extends StatelessWidget {
  const WorkPage({
    super.key,
    required this.title,
    required this.child,
    required this.onBack,
    this.actions = const [],
  });
  final String title;
  final Widget child;
  final VoidCallback onBack;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => SectionStack(
    children: [
      DeptAccountingPageHeader(
        title: title,
        description:
            '$appName · ${DateTime.now().toIso8601String().substring(0, 10)}',
        actions: [
          DeptAccountingButton(
            label: 'العودة',
            variant: DeptAccountingButtonVariant.secondary,
            onPressed: onBack,
          ),
          ...actions,
        ],
      ),
      child,
    ],
  );
}
