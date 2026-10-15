import 'package:flutter/material.dart';

import '../theme/dukan_tokens.dart';

enum DukanButtonVariant { primary, secondary, quiet, danger }

class DukanButton extends StatelessWidget {
  const DukanButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = DukanButtonVariant.primary,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DukanButtonVariant variant;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final action = loading ? null : onPressed;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: 18),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Semantics(
      liveRegion: loading,
      child: switch (variant) {
        DukanButtonVariant.primary => FilledButton(
          onPressed: action,
          child: content,
        ),
        DukanButtonVariant.secondary => OutlinedButton(
          onPressed: action,
          child: content,
        ),
        DukanButtonVariant.quiet => TextButton(
          onPressed: action,
          child: content,
        ),
        DukanButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(backgroundColor: DukanColors.danger),
          onPressed: action,
          child: content,
        ),
      },
    );
  }
}

class DukanPanel extends StatelessWidget {
  const DukanPanel({
    super.key,
    this.title,
    this.description,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.all(DukanSpace.xl),
    this.showHeaderDivider = true,
    this.minHeight = 0,
  });

  final String? title;
  final String? description;
  final Widget? action;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHeaderDivider;
  final double minHeight;

  @override
  Widget build(BuildContext context) => Material(
    color: DukanColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: DukanColors.border),
      borderRadius: BorderRadius.circular(DukanLayout.panelRadius),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(DukanSpace.xl),
              child: Wrap(
                spacing: 16,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (description != null)
                        Text(
                          description!,
                          style: const TextStyle(color: DukanColors.muted),
                        ),
                    ],
                  ),
                  ?action,
                ],
              ),
            ),
            if (showHeaderDivider) const Divider(),
          ],
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

class DukanPageHeader extends StatelessWidget {
  const DukanPageHeader({
    super.key,
    required this.title,
    required this.description,
    this.actions = const [],
  });
  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final text = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 4),
          Text(description, style: const TextStyle(color: DukanColors.muted)),
        ],
      );
      if (size.maxWidth < 700) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            text,
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: text),
          const SizedBox(width: 24),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      );
    },
  );
}

class DukanStatusTag extends StatelessWidget {
  const DukanStatusTag(this.label, {super.key, this.tone = DukanTone.neutral});
  final String label;
  final DukanTone tone;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(DukanLayout.badgeRadius),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600),
    ),
  );
}

class DukanMetricCard extends StatelessWidget {
  const DukanMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
  });
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => DukanPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: DukanColors.muted)),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
        ),
        const SizedBox(height: 4),
        Text(
          caption,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: DukanColors.muted),
        ),
      ],
    ),
  );
}

class DukanField extends StatelessWidget {
  const DukanField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.controller,
    this.initialValue,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.numeric = false,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
  });
  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final String? initialValue;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool numeric;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool autocorrect;
  final int maxLines;

  @override
  Widget build(BuildContext context) => TextFormField(
    style: DukanTypography.control,
    controller: controller,
    initialValue: initialValue,
    validator: validator,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    maxLines: maxLines,
    obscureText: obscureText,
    autocorrect: autocorrect && !obscureText,
    enableSuggestions: autocorrect && !obscureText,
    textDirection: numeric ? TextDirection.ltr : null,
    textAlign: TextAlign.start,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : TextInputType.text,
    textInputAction: maxLines == 1
        ? TextInputAction.next
        : TextInputAction.newline,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffixIcon,
    ),
  );
}

class DukanFilterChip extends StatelessWidget {
  const DukanFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final Widget label;
  final bool selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final height = DukanTypography.controlHeight(context);
    final textHeight =
        MediaQuery.textScalerOf(context)
            .scale(DukanTypography.controlFontSize) *
        DukanTypography.control.height!;
    return FilterChip(
      label: label,
      selected: selected,
      onSelected: onSelected,
      padding: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: (height - textHeight - 2) / 2,
      ),
    );
  }
}

class DukanNotice extends StatelessWidget {
  const DukanNotice({
    super.key,
    required this.title,
    this.message,
    this.tone = DukanTone.info,
  });
  final String title;
  final String? message;
  final DukanTone tone;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: tone == DukanTone.danger,
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tone.background,
        borderRadius: BorderRadius.circular(DukanLayout.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tone.icon, color: tone.foreground, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: tone.foreground),
                ),
                if (message != null)
                  Text(message!, style: TextStyle(color: tone.foreground)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

enum DukanViewState { empty, error, loading }

class DukanStateView extends StatelessWidget {
  const DukanStateView({
    super.key,
    required this.state,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final DukanViewState state;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Semantics(
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == DukanViewState.loading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              state == DukanViewState.error
                  ? Icons.error_outline
                  : Icons.inbox_outlined,
              size: 32,
              color: state == DukanViewState.error
                  ? DukanColors.danger
                  : DukanColors.muted,
            ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: const TextStyle(color: DukanColors.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            DukanButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}

Future<bool> showDukanConfirmation(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          DukanButton(
            label: 'العودة',
            variant: DukanButtonVariant.quiet,
            onPressed: () => Navigator.pop(context, false),
          ),
          DukanButton(
            label: confirmLabel,
            variant: destructive
                ? DukanButtonVariant.danger
                : DukanButtonVariant.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
    false;

class DukanAmount extends StatelessWidget {
  const DukanAmount(
    this.value, {
    super.key,
    this.currency = 'ر.ي',
    this.emphasized = false,
  });
  final String value;
  final String currency;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$value $currency',
    excludeSemantics: true,
    child: Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          value,
          textDirection: TextDirection.ltr,
          style: TextStyle(
            fontFeatures: const [FontFeature.tabularFigures()],
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          currency,
          style: const TextStyle(color: DukanColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class DukanEditorLayout extends StatelessWidget {
  const DukanEditorLayout({
    super.key,
    required this.form,
    required this.summary,
  });
  final Widget form;
  final Widget summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < 900) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [form, const SizedBox(height: 24), summary],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: form),
          const SizedBox(width: 24),
          SizedBox(width: 300, child: summary),
        ],
      );
    },
  );
}

class DukanSummaryLine extends StatelessWidget {
  const DukanSummaryLine({
    super.key,
    required this.label,
    required this.value,
    this.total = false,
    this.currency = 'ر.ي',
  });
  final String label;
  final String value;
  final bool total;
  final String currency;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: total ? DukanColors.ink : DukanColors.muted,
              fontWeight: total ? FontWeight.w600 : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        DukanAmount(value, emphasized: total, currency: currency),
      ],
    ),
  );
}
