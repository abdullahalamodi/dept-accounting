import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/dept_accounting_tokens.dart';

class DeptAccountingDesktopContent extends StatelessWidget {
  const DeptAccountingDesktopContent({
    super.key,
    required this.child,
    this.maxWidth = DeptAccountingLayout.formWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact
      ? child
      : Align(
          alignment: AlignmentDirectional.topStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SizedBox(width: double.infinity, child: child),
          ),
        );
}

class DeptAccountingSectionTabs<T> extends StatelessWidget {
  const DeptAccountingSectionTabs({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final List<({T value, String label})> items;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: DeptAccountingColors.border)),
    ),
    child: Wrap(
      spacing: DeptAccountingSpace.lg,
      runSpacing: DeptAccountingSpace.xs,
      children: [
        for (final item in items)
          Semantics(
            selected: value == item.value,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: value == item.value
                    ? DeptAccountingColors.primary
                    : DeptAccountingColors.muted,
                shape: const RoundedRectangleBorder(),
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onPressed: onChanged == null
                  ? null
                  : () => onChanged!(item.value),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: value == item.value
                          ? DeptAccountingColors.primary
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(item.label),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class DeptAccountingListToolbar extends StatelessWidget {
  const DeptAccountingListToolbar({
    super.key,
    required this.search,
    this.filters = const [],
    this.actions = const [],
  });

  final Widget search;
  final List<Widget> filters;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) =>
      MediaQuery.sizeOf(context).width < DeptAccountingLayout.compact &&
          filters.isEmpty &&
          actions.isEmpty
      ? search
      : LayoutBuilder(
          builder: (context, constraints) => Wrap(
            spacing: DeptAccountingSpace.md,
            runSpacing: DeptAccountingSpace.md,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: math.min(320, constraints.maxWidth),
                child: search,
              ),
              for (final filter in filters)
                SizedBox(
                  width: math.min(220, constraints.maxWidth),
                  child: filter,
                ),
              ...actions,
            ],
          ),
        );
}

class DeptAccountingDesktopActionBar extends StatelessWidget {
  const DeptAccountingDesktopActionBar({
    super.key,
    required this.actions,
    this.summary,
  });

  final Widget? summary;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Material(
    color: DeptAccountingColors.surface,
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: DeptAccountingColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: 24,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (summary != null)
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: summary!,
              ),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
      ),
    ),
  );
}

class DeptAccountingMetricGrid extends StatelessWidget {
  const DeptAccountingMetricGrid({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = ((constraints.maxWidth + 16) / 256).floor().clamp(1, 4);
      final width = math.min(
        280.0,
        (constraints.maxWidth - (count - 1) * 16) / count,
      );
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

class DeptAccountingDesktopViewport extends StatelessWidget {
  const DeptAccountingDesktopViewport({
    super.key,
    required this.body,
    this.footer,
  });
  final Widget body;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (constraints.hasBoundedHeight) Expanded(child: body) else body,
        ?footer,
      ],
    ),
  );
}
