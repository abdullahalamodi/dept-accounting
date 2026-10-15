import 'package:flutter/material.dart';

abstract final class DukanColors {
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

abstract final class DukanSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const section = 48.0;
  static const formGap = 14.0;
}

abstract final class DukanLayout {
  static const compact = 600.0;
  static const expanded = 1100.0;
  static const sidebar = 244.0;
  static const maxContent = 1440.0;
  static const minTarget = 48.0;
  static const controlHeight = 52.0;
  static const badgeRadius = 4.0;
  static const smallRadius = 6.0;
  static const radius = 8.0;
  static const brandRadius = 10.0;
  static const panelRadius = 12.0;
}

abstract final class DukanTypography {
  static const controlFontSize = 14.0;
  static const controlLineHeight = 24.0;
  static const controlVerticalPadding = 14.0;
  static const control = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontSize: controlFontSize,
    fontWeight: FontWeight.w400,
    height: controlLineHeight / controlFontSize,
    color: DukanColors.ink,
  );
  static const label = TextStyle(
    fontFamily: 'IBMPlexSansArabic',
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: DukanColors.muted,
  );
  static final action = control.copyWith(fontWeight: FontWeight.w500);

  static double controlHeight(BuildContext context) {
    final textHeight =
        MediaQuery.textScalerOf(context).scale(controlFontSize) *
        control.height!;
    return textHeight + controlVerticalPadding * 2 > DukanLayout.controlHeight
        ? textHeight + controlVerticalPadding * 2
        : DukanLayout.controlHeight;
  }
}

enum DukanTone { success, warning, danger, info, neutral }

extension DukanToneColors on DukanTone {
  Color get foreground => switch (this) {
    DukanTone.success => DukanColors.primary,
    DukanTone.warning => DukanColors.warning,
    DukanTone.danger => DukanColors.danger,
    DukanTone.info => DukanColors.info,
    DukanTone.neutral => DukanColors.muted,
  };

  Color get background => switch (this) {
    DukanTone.success => DukanColors.primarySoft,
    DukanTone.warning => DukanColors.warningSoft,
    DukanTone.danger => DukanColors.dangerSoft,
    DukanTone.info => DukanColors.infoSoft,
    DukanTone.neutral => DukanColors.background,
  };

  IconData get icon => switch (this) {
    DukanTone.success => Icons.check_circle_outline,
    DukanTone.warning => Icons.warning_amber_rounded,
    DukanTone.danger => Icons.error_outline,
    DukanTone.info => Icons.info_outline,
    DukanTone.neutral => Icons.circle_outlined,
  };
}
