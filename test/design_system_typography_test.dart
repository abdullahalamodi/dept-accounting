import 'package:dept_accounting/design_system/dept_accounting_design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Every text role uses the Arabic family and shared ink, with quiet section headings', () {
    final theme = DeptAccountingTheme.light();
    final roles = {
      'displayLarge': theme.textTheme.displayLarge!,
      'displayMedium': theme.textTheme.displayMedium!,
      'displaySmall': theme.textTheme.displaySmall!,
      'headlineLarge': theme.textTheme.headlineLarge!,
      'headlineMedium': theme.textTheme.headlineMedium!,
      'headlineSmall': theme.textTheme.headlineSmall!,
      'titleLarge': theme.textTheme.titleLarge!,
      'titleMedium': theme.textTheme.titleMedium!,
      'titleSmall': theme.textTheme.titleSmall!,
      'bodyLarge': theme.textTheme.bodyLarge!,
      'bodyMedium': theme.textTheme.bodyMedium!,
      'bodySmall': theme.textTheme.bodySmall!,
      'labelLarge': theme.textTheme.labelLarge!,
      'labelMedium': theme.textTheme.labelMedium!,
      'labelSmall': theme.textTheme.labelSmall!,
    };
    for (final role in roles.entries) {
      expect(role.value.fontFamily, 'IBMPlexSansArabic', reason: role.key);
      expect(role.value.color, DeptAccountingColors.ink, reason: role.key);
    }
    expect(theme.textTheme.titleMedium!.fontWeight, FontWeight.w400);
    expect(theme.textTheme.titleMedium!.fontSize, 16);
  });
}
