import 'package:flutter/material.dart';

import 'dept_accounting_tokens.dart';

abstract final class DeptAccountingTheme {
  static ThemeData light() {
    const rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(DeptAccountingLayout.radius),
      ),
    );
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(DeptAccountingLayout.radius),
      ),
      borderSide: BorderSide(color: DeptAccountingColors.controlBorder),
    );
    const scheme = ColorScheme.light(
      primary: DeptAccountingColors.primary,
      onPrimary: Colors.white,
      primaryContainer: DeptAccountingColors.primarySoft,
      onPrimaryContainer: DeptAccountingColors.primary,
      secondary: DeptAccountingColors.primary,
      secondaryContainer: DeptAccountingColors.sage,
      onSecondaryContainer: DeptAccountingColors.ink,
      surface: DeptAccountingColors.surface,
      onSurface: DeptAccountingColors.ink,
      onSurfaceVariant: DeptAccountingColors.muted,
      outline: DeptAccountingColors.controlBorder,
      outlineVariant: DeptAccountingColors.border,
      error: DeptAccountingColors.danger,
      onError: Colors.white,
      errorContainer: DeptAccountingColors.dangerSoft,
    );
    final text = DeptAccountingTypography.textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DeptAccountingColors.background,
      fontFamily: DeptAccountingTypography.family,
      textTheme: text,
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: DeptAccountingColors.muted,
        ),
        textColor: DeptAccountingColors.ink,
        iconColor: DeptAccountingColors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(48, DeptAccountingLayout.controlHeight),
          ),
          textStyle: WidgetStatePropertyAll(DeptAccountingTypography.action),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(rounded),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return DeptAccountingColors.border;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return DeptAccountingColors.primaryHover;
            }
            return DeptAccountingColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? DeptAccountingColors.muted
                : Colors.white,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: DeptAccountingColors.ink, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, DeptAccountingLayout.controlHeight),
          textStyle: DeptAccountingTypography.action,
          shape: rounded,
          side: const BorderSide(color: DeptAccountingColors.controlBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, DeptAccountingLayout.controlHeight),
          textStyle: DeptAccountingTypography.action,
          shape: rounded,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        constraints: const BoxConstraints(
          minHeight: DeptAccountingLayout.controlHeight,
        ),
        filled: true,
        fillColor: DeptAccountingColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: DeptAccountingTypography.controlVerticalPadding,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(
            color: DeptAccountingColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: outline.copyWith(
          borderSide: const BorderSide(color: DeptAccountingColors.danger),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: const BorderSide(
            color: DeptAccountingColors.danger,
            width: 2,
          ),
        ),
        disabledBorder: outline.copyWith(
          borderSide: const BorderSide(color: DeptAccountingColors.border),
        ),
        labelStyle: DeptAccountingTypography.label,
        floatingLabelStyle: DeptAccountingTypography.label.copyWith(
          fontSize: 16,
        ),
        hintStyle: DeptAccountingTypography.label,
        helperStyle: DeptAccountingTypography.label.copyWith(fontSize: 12),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: DeptAccountingTypography.control,
      ),
      chipTheme: ChipThemeData(
        labelStyle: DeptAccountingTypography.action,
        secondaryLabelStyle: DeptAccountingTypography.action,
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        side: const BorderSide(color: DeptAccountingColors.border),
        shape: rounded,
        backgroundColor: DeptAccountingColors.surface,
        selectedColor: DeptAccountingColors.primarySoft,
        secondarySelectedColor: DeptAccountingColors.primarySoft,
        checkmarkColor: DeptAccountingColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: DeptAccountingColors.border,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(
          DeptAccountingColors.background,
        ),
        headingTextStyle: DeptAccountingTypography.tableHeading,
        dataTextStyle: DeptAccountingTypography.tableBody,
        horizontalMargin: 24,
        columnSpacing: 32,
        headingRowHeight: 48,
        dataRowMinHeight: 56,
        dataRowMaxHeight: double.infinity,
        dividerThickness: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: DeptAccountingColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DeptAccountingLayout.panelRadius),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: DeptAccountingColors.ink,
        contentTextStyle: TextStyle(
          fontFamily: 'IBMPlexSansArabic',
          color: Colors.white,
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: const TooltipThemeData(
        waitDuration: Duration(milliseconds: 400),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: DeptAccountingColors.primary,
      ),
    );
  }
}
