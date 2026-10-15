import 'package:flutter/material.dart';

import '../../design_system/dukan_design_system.dart';
import '../numbers.dart';

class SectionStack extends StatelessWidget {
  const SectionStack({super.key, required this.children})
    : spacing = DukanSpace.xl;
  const SectionStack.form({super.key, required this.children})
    : spacing = DukanSpace.formGap;
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
    this.runSpacing = DukanSpace.formGap,
  });
  final List<Widget> children;
  final double minWidth;
  final double runSpacing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final count = ((c.maxWidth + DukanSpace.lg) / (minWidth + DukanSpace.lg))
          .floor()
          .clamp(1, children.length.clamp(1, 3));
      final width = (c.maxWidth - DukanSpace.lg * (count - 1)) / count;
      return Wrap(
        spacing: DukanSpace.lg,
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
  });
  final String label;
  final T? value;
  final List<({T value, String label})> items;
  final ValueChanged<T?> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey('$label-$value'),
    initialValue: value,
    isExpanded: true,
    style: DukanTypography.control,
    iconSize: 20,
    decoration: InputDecoration(labelText: label),
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
          padding: const EdgeInsets.only(bottom: DukanSpace.lg),
          child: DukanNotice(
            title: 'راجع البيانات',
            message: error!,
            tone: DukanTone.danger,
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
      DukanPageHeader(
        title: title,
        description:
            'دكّان · ${DateTime.now().toIso8601String().substring(0, 10)}',
        actions: [
          DukanButton(
            label: 'العودة',
            variant: DukanButtonVariant.secondary,
            onPressed: onBack,
          ),
          ...actions,
        ],
      ),
      child,
    ],
  );
}
