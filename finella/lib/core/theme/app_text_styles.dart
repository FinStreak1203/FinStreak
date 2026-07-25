import 'package:flutter/material.dart';

// ── Font size scale ────────────────────────────────────────────
// Change any value here and every widget that uses AppTextStyles
// will reflect it automatically.
class AppFontSize {
  AppFontSize._();

  static const double xs   = 10;
  static const double sm   = 11;
  static const double base = 12;
  static const double md   = 13;
  static const double lg   = 14;
  static const double xl   = 15;
  static const double x2l  = 16;
  static const double x3l  = 18;
  static const double x4l  = 20;
  static const double x5l  = 22;
  static const double x6l  = 24;
  static const double x7l  = 28;
  static const double x8l  = 32;
  static const double x9l  = 40;
  static const double x10l = 52;
}

// ── Centralised text styles (Open Sans — bundled) ─────────────
// One place to rule all typography.
// Usage:  style: AppTextStyles.headingLarge
class AppTextStyles {
  AppTextStyles._();

  // ── Bundled font family name (matches pubspec.yaml) ───────
  static const String fontFamily = 'OpenSans';

  // ── Base factory — every style derives from this ──────────
  static TextStyle _s({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = const Color(0xFF111827),
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  // ── Display / Hero ────────────────────────────────────────
  static TextStyle get displayHero => _s(size: AppFontSize.x10l, weight: FontWeight.w700);
  static TextStyle get display     => _s(size: AppFontSize.x8l,  weight: FontWeight.w700);

  // ── Headings ──────────────────────────────────────────────
  static TextStyle get h1 => _s(size: AppFontSize.x7l, weight: FontWeight.w700);
  static TextStyle get h2 => _s(size: AppFontSize.x6l, weight: FontWeight.w700);
  static TextStyle get h3 => _s(size: AppFontSize.x4l, weight: FontWeight.w700);
  static TextStyle get h4 => _s(size: AppFontSize.x3l, weight: FontWeight.w700);
  static TextStyle get h5 => _s(size: AppFontSize.x2l, weight: FontWeight.w700);
  static TextStyle get h6 => _s(size: AppFontSize.xl,  weight: FontWeight.w700);

  // ── Body ──────────────────────────────────────────────────
  static TextStyle get bodyLarge  => _s(size: AppFontSize.x2l, weight: FontWeight.w500, height: 1.5);
  static TextStyle get body       => _s(size: AppFontSize.lg,  weight: FontWeight.w500, height: 1.5);
  static TextStyle get bodySmall  => _s(size: AppFontSize.base, weight: FontWeight.w500, height: 1.4);

  // ── Labels ────────────────────────────────────────────────
  static TextStyle get labelLarge  => _s(size: AppFontSize.lg,   weight: FontWeight.w700);
  static TextStyle get label       => _s(size: AppFontSize.md,   weight: FontWeight.w600);
  static TextStyle get labelSmall  => _s(size: AppFontSize.base, weight: FontWeight.w600, color: const Color(0xFF6B7280));
  static TextStyle get labelXSmall => _s(size: AppFontSize.sm,   weight: FontWeight.w600, color: const Color(0xFF9CA3AF));

  // ── Captions / Hints ─────────────────────────────────────
  static TextStyle get caption      => _s(size: AppFontSize.xs, weight: FontWeight.w600, color: const Color(0xFF9CA3AF));
  static TextStyle get captionBold  => _s(size: AppFontSize.xs, weight: FontWeight.w700, letterSpacing: 0.8);

  // ── Buttons ───────────────────────────────────────────────
  static TextStyle get buttonLarge  => _s(size: AppFontSize.x2l, weight: FontWeight.w700, color: Colors.white);
  static TextStyle get button       => _s(size: AppFontSize.xl,  weight: FontWeight.w700, color: Colors.white);
  static TextStyle get buttonSmall  => _s(size: AppFontSize.md,  weight: FontWeight.w700, color: Colors.white);
  static TextStyle get buttonOutline => _s(size: AppFontSize.xl, weight: FontWeight.w700, color: const Color(0xFF2E7D32));

  // ── Amounts / Numbers ─────────────────────────────────────
  static TextStyle get amountHero  => _s(size: AppFontSize.x8l, weight: FontWeight.w700, color: Colors.white);
  static TextStyle get amountLarge => _s(size: AppFontSize.x5l, weight: FontWeight.w700);
  static TextStyle get amount      => _s(size: AppFontSize.x3l, weight: FontWeight.w700);
  static TextStyle get amountSmall => _s(size: AppFontSize.lg,  weight: FontWeight.w700);

  // ── Navigation / Tabs ─────────────────────────────────────
  static TextStyle get tabActive   => _s(size: AppFontSize.lg, weight: FontWeight.w700, color: Colors.white);
  static TextStyle get tabInactive => _s(size: AppFontSize.lg, weight: FontWeight.w700, color: const Color(0xFF6B7280));

  // ── App bar title ─────────────────────────────────────────
  static TextStyle get appBarTitle => _s(size: AppFontSize.x3l, weight: FontWeight.w700);

  // ── Convenience: colour overrides ─────────────────────────
  static TextStyle white(TextStyle base) => base.copyWith(color: Colors.white);
  static TextStyle green(TextStyle base) => base.copyWith(color: const Color(0xFF2E7D32));
  static TextStyle red(TextStyle base)   => base.copyWith(color: const Color(0xFFEF4444));
  static TextStyle gray(TextStyle base)  => base.copyWith(color: const Color(0xFF6B7280));
}
