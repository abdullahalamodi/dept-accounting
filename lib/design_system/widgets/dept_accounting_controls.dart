import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';

enum DeptAccountingButtonVariant { primary, secondary, quiet, danger }

class DeptAccountingButton extends StatelessWidget {
  const DeptAccountingButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.variant = DeptAccountingButtonVariant.primary,
    this.loading = false,
    this.compact = false,
  });

  const DeptAccountingButton.table({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
  }) : compact = true,
       variant = DeptAccountingButtonVariant.primary;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final DeptAccountingButtonVariant variant;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final action = loading ? null : onPressed;
    final style = compact ? _compactButtonStyle(context) : null;
    final iconSize = compact ? 16.0 : 18.0;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading) ...[
          SizedBox(
            width: iconSize,
            height: iconSize,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
        ] else if (icon != null) ...[
          Icon(icon, size: iconSize),
          const SizedBox(width: 8),
        ],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    return Semantics(
      liveRegion: loading,
      child: switch (variant) {
        DeptAccountingButtonVariant.primary => FilledButton(
          style: style,
          onPressed: action,
          child: content,
        ),
        DeptAccountingButtonVariant.secondary => OutlinedButton(
          style: style,
          onPressed: action,
          child: content,
        ),
        DeptAccountingButtonVariant.quiet => TextButton(
          style: style,
          onPressed: action,
          child: content,
        ),
        DeptAccountingButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: DeptAccountingColors.danger,
          ).merge(style),
          onPressed: action,
          child: content,
        ),
      },
    );
  }
}

ButtonStyle _compactButtonStyle(BuildContext context) => ButtonStyle(
  minimumSize: WidgetStatePropertyAll(
    Size(
      DeptAccountingLayout.compactControlHeight,
      DeptAccountingTypography.compactControlHeight(context),
    ),
  ),
  padding: const WidgetStatePropertyAll(
    DeptAccountingLayout.compactControlPadding,
  ),
  textStyle: const WidgetStatePropertyAll(
    DeptAccountingTypography.compactControl,
  ),
  visualDensity: VisualDensity.standard,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
);

class DeptAccountingIconButton extends StatelessWidget {
  const DeptAccountingIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
    this.compact = false,
  });

  const DeptAccountingIconButton.table({
    super.key,
    required this.tooltip,
    required this.icon,
    this.onPressed,
  }) : compact = true;

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? DeptAccountingTypography.compactControlHeight(context)
        : DeptAccountingTypography.controlHeight(context);
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: compact ? 16 : 18),
      onPressed: onPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? DeptAccountingColors.muted
              : states.contains(WidgetState.hovered)
              ? DeptAccountingColors.primaryHover
              : DeptAccountingColors.primary,
        ),
        overlayColor: WidgetStatePropertyAll(
          DeptAccountingColors.primary.withValues(alpha: .08),
        ),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(DeptAccountingLayout.radius),
            ),
          ),
        ),
        minimumSize: WidgetStatePropertyAll(Size.square(height)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        visualDensity: VisualDensity.standard,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class DeptAccountingPanel extends StatelessWidget {
  const DeptAccountingPanel({
    super.key,
    this.title,
    this.description,
    this.action,
    required this.child,
    this.padding = const EdgeInsets.all(DeptAccountingSpace.xl),
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
    color: DeptAccountingColors.surface,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: DeptAccountingColors.border),
      borderRadius: BorderRadius.circular(DeptAccountingLayout.panelRadius),
    ),
    child: ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.all(DeptAccountingSpace.xl),
              child: LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: constraints.maxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (description != null)
                            Text(
                              description!,
                              style: const TextStyle(
                                color: DeptAccountingColors.muted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    ?action,
                  ],
                ),
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

class DeptAccountingPageHeader extends StatelessWidget {
  const DeptAccountingPageHeader({
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
          Text(
            description,
            style: const TextStyle(color: DeptAccountingColors.muted),
          ),
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

class DeptAccountingStatusTag extends StatelessWidget {
  const DeptAccountingStatusTag(
    this.label, {
    super.key,
    this.tone = DeptAccountingTone.neutral,
    this.compact = false,
  });
  final String label;
  final DeptAccountingTone tone;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: compact
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: tone.background,
      borderRadius: BorderRadius.circular(DeptAccountingLayout.badgeRadius),
    ),
    child: Text(
      label,
      maxLines: compact ? 1 : null,
      overflow: compact ? TextOverflow.ellipsis : null,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: tone.foreground,
        fontSize: compact ? 10 : null,
        fontWeight: compact
            ? DeptAccountingTypography.regular
            : DeptAccountingTypography.emphasis,
      ),
    ),
  );
}

class DeptAccountingMetricCard extends StatelessWidget {
  const DeptAccountingMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
  });
  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => DeptAccountingPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: DeptAccountingColors.muted)),
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
              ?.copyWith(color: DeptAccountingColors.muted),
        ),
      ],
    ),
  );
}

class DeptAccountingField extends StatelessWidget {
  const DeptAccountingField({
    super.key,
    required this.label,
    this.hint,
    this.helper,
    this.controller,
    this.initialValue,
    this.validator,
    this.readOnly = false,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofocus = false,
    this.enabled = true,
    this.numeric = false,
    this.textDirection,
    this.textAlign = TextAlign.start,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.autocorrect = true,
    this.maxLines = 1,
    this.compact = false,
  });
  final String label;
  final String? hint;
  final String? helper;
  final TextEditingController? controller;
  final String? initialValue;
  final FormFieldValidator<String>? validator;
  final bool readOnly;
  final VoidCallback? onTap;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool enabled;
  final bool numeric;
  final TextDirection? textDirection;
  final TextAlign textAlign;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool autocorrect;
  final int maxLines;
  final bool compact;

  @override
  Widget build(BuildContext context) => TextFormField(
    style: compact
        ? DeptAccountingTypography.compactControl
        : DeptAccountingTypography.control,
    controller: controller,
    initialValue: numeric && initialValue == '0' ? '' : initialValue,
    validator: validator,
    readOnly: readOnly,
    onTap: onTap,
    onChanged: onChanged,
    onFieldSubmitted: onSubmitted,
    focusNode: focusNode,
    autofocus: autofocus,
    enabled: enabled,
    maxLines: maxLines,
    obscureText: obscureText,
    autocorrect: autocorrect && !obscureText,
    enableSuggestions: autocorrect && !obscureText,
    textDirection: textDirection ?? (numeric ? TextDirection.ltr : null),
    textAlign: textAlign,
    keyboardType: numeric
        ? const TextInputType.numberWithOptions(decimal: true)
        : maxLines > 1
        ? TextInputType.multiline
        : TextInputType.text,
    textInputAction: maxLines == 1
        ? TextInputAction.next
        : TextInputAction.newline,
    decoration: InputDecoration(
      labelText: label.isEmpty ? null : label,
      constraints: compact
          ? const BoxConstraints(
              minHeight: DeptAccountingLayout.compactControlHeight,
            )
          : null,
      contentPadding: compact
          ? DeptAccountingLayout.compactControlPadding
          : null,
      hintText: hint,
      helperText: helper,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      suffixIcon: suffixIcon,
    ),
  );
}

class DeptAccountingFilterChip extends StatelessWidget {
  const DeptAccountingFilterChip({
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
    final height = DeptAccountingTypography.controlHeight(context);
    final textHeight =
        MediaQuery.textScalerOf(context)
            .scale(DeptAccountingTypography.controlFontSize) *
        DeptAccountingTypography.control.height!;
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

class DeptAccountingNotice extends StatelessWidget {
  const DeptAccountingNotice({
    super.key,
    required this.title,
    this.message,
    this.tone = DeptAccountingTone.info,
  });
  final String title;
  final String? message;
  final DeptAccountingTone tone;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scrollable =
        size.width < DeptAccountingLayout.compact &&
        (tone == DeptAccountingTone.warning || tone == DeptAccountingTone.info);
    final content = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(tone.icon, color: tone.foreground, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
    );
    return Semantics(
      liveRegion: tone == DeptAccountingTone.danger,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: scrollable
              ? (size.height * .25).clamp(
                  0,
                  DeptAccountingLayout.compactNoticeMaxHeight,
                )
              : double.infinity,
        ),
        child: Container(
          padding: const EdgeInsets.all(DeptAccountingSpace.lg),
          decoration: BoxDecoration(
            color: tone.background,
            borderRadius: BorderRadius.circular(DeptAccountingLayout.radius),
          ),
          child: scrollable
              ? SingleChildScrollView(primary: false, child: content)
              : content,
        ),
      ),
    );
  }
}

enum DeptAccountingViewState { empty, error, loading }

class DeptAccountingStateView extends StatelessWidget {
  const DeptAccountingStateView({
    super.key,
    required this.state,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final DeptAccountingViewState state;
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
          if (state == DeptAccountingViewState.loading)
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              state == DeptAccountingViewState.error
                  ? Icons.error_outline
                  : Icons.inbox_outlined,
              size: 32,
              color: state == DeptAccountingViewState.error
                  ? DeptAccountingColors.danger
                  : DeptAccountingColors.muted,
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
            style: const TextStyle(color: DeptAccountingColors.muted),
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 20),
            DeptAccountingButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    ),
  );
}

Future<bool> showDeptAccountingConfirmation(
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
          DeptAccountingButton(
            label: 'العودة',
            variant: DeptAccountingButtonVariant.quiet,
            onPressed: () => Navigator.pop(context, false),
          ),
          DeptAccountingButton(
            label: confirmLabel,
            variant: destructive
                ? DeptAccountingButtonVariant.danger
                : DeptAccountingButtonVariant.primary,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    ) ??
    false;

class DeptAccountingAmount extends StatelessWidget {
  const DeptAccountingAmount(
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
            fontWeight: emphasized
                ? DeptAccountingTypography.emphasis
                : DeptAccountingTypography.regular,
          ),
        ),
        Text(
          currency,
          style: const TextStyle(
            color: DeptAccountingColors.muted,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

class DeptAccountingEditorLayout extends StatelessWidget {
  const DeptAccountingEditorLayout({
    super.key,
    required this.form,
    required this.summary,
    this.minFormWidth = 576,
  });
  final Widget form;
  final Widget summary;
  final double minFormWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      if (size.maxWidth < minFormWidth + 324) {
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

class DeptAccountingSummaryLine extends StatelessWidget {
  const DeptAccountingSummaryLine({
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
              color: total
                  ? DeptAccountingColors.ink
                  : DeptAccountingColors.muted,
              fontWeight: total ? DeptAccountingTypography.emphasis : null,
            ),
          ),
        ),
        const SizedBox(width: 16),
        DeptAccountingAmount(value, emphasized: total, currency: currency),
      ],
    ),
  );
}

class DeptAccountingPasswordField extends StatefulWidget {
  const DeptAccountingPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.helper,
    this.validator,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final String? helper;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<DeptAccountingPasswordField> createState() =>
      _DeptAccountingPasswordFieldState();
}

class _DeptAccountingPasswordFieldState
    extends State<DeptAccountingPasswordField> {
  bool hidden = true;

  @override
  Widget build(BuildContext context) => DeptAccountingField(
    label: widget.label,
    controller: widget.controller,
    helper: widget.helper,
    validator: widget.validator,
    onSubmitted: widget.onSubmitted,
    obscureText: hidden,
    autocorrect: false,
    suffixIcon: IconButton(
      tooltip: hidden ? 'إظهار ${widget.label}' : 'إخفاء ${widget.label}',
      onPressed: () => setState(() => hidden = !hidden),
      icon: Icon(
        hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
  );
}
