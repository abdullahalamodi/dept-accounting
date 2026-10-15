import 'package:flutter/material.dart';

import 'dukan_tokens.dart';

abstract final class DukanTheme {
  static ThemeData light() {
    const rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(DukanLayout.radius)),
    );
    const outline = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(DukanLayout.radius)),
      borderSide: BorderSide(color: DukanColors.controlBorder),
    );
    const scheme = ColorScheme.light(
      primary: DukanColors.primary,
      onPrimary: Colors.white,
      primaryContainer: DukanColors.primarySoft,
      onPrimaryContainer: DukanColors.primary,
      secondary: DukanColors.primary,
      secondaryContainer: DukanColors.sage,
      onSecondaryContainer: DukanColors.ink,
      surface: DukanColors.surface,
      onSurface: DukanColors.ink,
      onSurfaceVariant: DukanColors.muted,
      outline: DukanColors.controlBorder,
      outlineVariant: DukanColors.border,
      error: DukanColors.danger,
      onError: Colors.white,
      errorContainer: DukanColors.dangerSoft,
    );
    final text = DukanTypography.textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: DukanColors.background,
      fontFamily: DukanTypography.family,
      textTheme: text,
      listTileTheme: ListTileThemeData(
        titleTextStyle: text.bodyMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(color: DukanColors.muted),
        textColor: DukanColors.ink,
        iconColor: DukanColors.muted,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(48, DukanLayout.controlHeight),
          ),
          textStyle: WidgetStatePropertyAll(DukanTypography.action),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          shape: const WidgetStatePropertyAll(rounded),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return DukanColors.border;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return DukanColors.primaryHover;
            }
            return DukanColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? DukanColors.muted
                : Colors.white,
          ),
          side: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.focused)
                ? const BorderSide(color: DukanColors.ink, width: 3)
                : BorderSide.none,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, DukanLayout.controlHeight),
          textStyle: DukanTypography.action,
          shape: rounded,
          side: const BorderSide(color: DukanColors.controlBorder),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, DukanLayout.controlHeight),
          textStyle: DukanTypography.action,
          shape: rounded,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        constraints: const BoxConstraints(minHeight: DukanLayout.controlHeight),
        filled: true,
        fillColor: DukanColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: DukanTypography.controlVerticalPadding,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: outline.copyWith(
          borderSide: const BorderSide(color: DukanColors.primary, width: 1.5),
        ),
        errorBorder: outline.copyWith(
          borderSide: const BorderSide(color: DukanColors.danger),
        ),
        focusedErrorBorder: outline.copyWith(
          borderSide: const BorderSide(color: DukanColors.danger, width: 2),
        ),
        disabledBorder: outline.copyWith(
          borderSide: const BorderSide(color: DukanColors.border),
        ),
        labelStyle: DukanTypography.label,
        floatingLabelStyle: DukanTypography.label.copyWith(fontSize: 16),
        hintStyle: DukanTypography.label,
        helperStyle: DukanTypography.label.copyWith(fontSize: 12),
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: DukanTypography.control,
      ),
      chipTheme: ChipThemeData(
        labelStyle: DukanTypography.action,
        secondaryLabelStyle: DukanTypography.action,
        labelPadding: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        side: const BorderSide(color: DukanColors.border),
        shape: rounded,
        backgroundColor: DukanColors.surface,
        selectedColor: DukanColors.primarySoft,
        secondarySelectedColor: DukanColors.primarySoft,
        checkmarkColor: DukanColors.primary,
      ),
      dividerTheme: const DividerThemeData(
        color: DukanColors.border,
        thickness: 1,
        space: 1,
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(DukanColors.background),
        headingTextStyle: text.labelLarge?.copyWith(color: DukanColors.muted),
        dataTextStyle: text.bodyMedium,
        horizontalMargin: 24,
        columnSpacing: 32,
        headingRowHeight: 56,
        dataRowMinHeight: 64,
        dataRowMaxHeight: double.infinity,
        dividerThickness: 1,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: DukanColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(
            Radius.circular(DukanLayout.panelRadius),
          ),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: DukanColors.ink,
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
        color: DukanColors.primary,
      ),
    );
  }
}
