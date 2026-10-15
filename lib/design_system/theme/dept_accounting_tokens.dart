import 'package:flutter/material.dart';

abstract final class DeptAccountingColors {
  static const primary = Color(0xFF17654D);
  static const primaryHover = Color(0xFF104C3A);
  static const ink = Color(0xFF233D35);
  static const muted = Color(0xFF62766B);
  static const border = Color(0xFFE5EAE6);
  static const controlBorder = border;
  static const background = Color(0xFFF5F7F4);
  static const surface = Colors.white;
  static const sage = Color(0xFFE7EFCD);
  static const primarySoft = Color(0xFFEAF3EB);
  static const chartSecondary = Color(0xFF9AB77C);
  static const warning = Color(0xFF895B16);
  static const warningSoft = Color(0xFFFFF4DD);
  static const danger = Color(0xFFB23636);
  static const dangerSoft = Color(0xFFFCEDEC);
  static const info = Color(0xFF245D86);
  static const infoSoft = Color(0xFFEAF2FA);
}

abstract final class DeptAccountingSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 48.0;
  static const formGap = 14.0;
}

abstract final class DeptAccountingLayout {
  static const compact = 600.0;
  static const expanded = 1100.0;
  static const sidebar = 244.0;
  static const maxContent = 1440.0;
  static const minTarget = 48.0;
  static const controlHeight = 52.0;
  static const compactControlHeight = 36.0;
  static const paginationControlHeight = 36.0;
  static const compactNoticeMaxHeight = 160.0;
  static const badgeRadius = 4.0;
  static const smallRadius = 6.0;
  static const radius = 8.0;
  static const brandRadius = 10.0;
  static const panelRadius = 12.0;
}

abstract final class DeptAccountingTypography {
  static const family = 'IBMPlexSansArabic';
  static const regular = FontWeight.w400;
  static const emphasis = FontWeight.w500;
  static const controlFontSize = 14.0;
  static const controlLineHeight = 24.0;
  static const controlVerticalPadding = 14.0;
  static const control = TextStyle(
    fontFamily: family,
    fontSize: controlFontSize,
    fontWeight: regular,
    height: controlLineHeight / controlFontSize,
    color: DeptAccountingColors.ink,
  );
  static const compactControl = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: regular,
    height: 1.5,
    color: DeptAccountingColors.ink,
  );
  static const label = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: regular,
    height: 1.5,
    color: DeptAccountingColors.muted,
  );
  static const action = control;
  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: regular,
    height: 1.7,
    color: DeptAccountingColors.ink,
  );
  static const tableBody = TextStyle(
    fontFamily: family,
    fontSize: 13,
    fontWeight: regular,
    height: 1.6,
    color: DeptAccountingColors.ink,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const tableHeading = TextStyle(
    fontFamily: family,
    fontSize: 12,
    fontWeight: emphasis,
    height: 1.5,
    color: DeptAccountingColors.muted,
  );
  static const sectionTitle = TextStyle(
    fontFamily: family,
    fontSize: 16,
    fontWeight: regular,
    height: 1.6,
    color: DeptAccountingColors.ink,
  );
  static final textTheme = TextTheme(
    displayLarge: sectionTitle.copyWith(fontSize: 40, fontWeight: emphasis),
    displayMedium: sectionTitle.copyWith(fontSize: 36, fontWeight: emphasis),
    displaySmall: sectionTitle.copyWith(fontSize: 32, fontWeight: emphasis),
    headlineLarge: sectionTitle.copyWith(fontSize: 32, fontWeight: emphasis),
    headlineMedium: sectionTitle.copyWith(fontSize: 26, fontWeight: emphasis),
    headlineSmall: sectionTitle.copyWith(fontSize: 22, fontWeight: emphasis),
    titleLarge: sectionTitle.copyWith(fontSize: 20),
    titleMedium: sectionTitle,
    titleSmall: control,
    bodyLarge: control,
    bodyMedium: control,
    bodySmall: caption,
    labelLarge: control.copyWith(height: 1.5),
    labelMedium: label.copyWith(color: DeptAccountingColors.ink),
    labelSmall: caption.copyWith(height: 1.5),
  );

  static double controlHeight(BuildContext context) {
    final textHeight =
        MediaQuery.textScalerOf(context).scale(controlFontSize) *
        control.height!;
    return textHeight + controlVerticalPadding * 2 >
            DeptAccountingLayout.controlHeight
        ? textHeight + controlVerticalPadding * 2
        : DeptAccountingLayout.controlHeight;
  }
}

enum DeptAccountingTone { success, warning, danger, info, neutral }

extension DeptAccountingToneColors on DeptAccountingTone {
  Color get foreground => switch (this) {
    DeptAccountingTone.success => DeptAccountingColors.primary,
    DeptAccountingTone.warning => DeptAccountingColors.warning,
    DeptAccountingTone.danger => DeptAccountingColors.danger,
    DeptAccountingTone.info => DeptAccountingColors.info,
    DeptAccountingTone.neutral => DeptAccountingColors.muted,
  };

  Color get background => switch (this) {
    DeptAccountingTone.success => DeptAccountingColors.primarySoft,
    DeptAccountingTone.warning => DeptAccountingColors.warningSoft,
    DeptAccountingTone.danger => DeptAccountingColors.dangerSoft,
    DeptAccountingTone.info => DeptAccountingColors.infoSoft,
    DeptAccountingTone.neutral => DeptAccountingColors.background,
  };

  IconData get icon => switch (this) {
    DeptAccountingTone.success => Icons.check_circle_outline,
    DeptAccountingTone.warning => Icons.warning_amber_rounded,
    DeptAccountingTone.danger => Icons.error_outline,
    DeptAccountingTone.info => Icons.info_outline,
    DeptAccountingTone.neutral => Icons.circle_outlined,
  };
}
