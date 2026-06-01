import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Type scale. Manrope chosen over Urbanist for its tighter geometry at
/// display sizes and better Cyrillic coverage — both critical for the
/// Russian headlines that drive this product. Letter-spacing is dialed
/// down on large weights; body weights stay neutral.
class SalamatText {
  /// Fonts the system can fall back to for glyphs Manrope doesn't ship:
  /// the tenge sign (₸ / U+20B8), some Cyrillic currency abbreviations,
  /// and assorted emoji/symbols. Listed roughly in priority order.
  static const List<String> _manropeFallback = [
    'Roboto',
    'Noto Sans',
    'sans-serif',
  ];

  static TextStyle _heading({
    required double fontSize,
    FontWeight weight = FontWeight.w800,
    double height = 1.1,
    double letterSpacing = -0.5,
    Color? color,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color ?? SalamatColors.ink,
      ).copyWith(fontFamilyFallback: _manropeFallback);

  static TextStyle _body({
    required double fontSize,
    FontWeight weight = FontWeight.w500,
    double height = 1.45,
    Color? color,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
        color: color ?? SalamatColors.ink,
      ).copyWith(fontFamilyFallback: _manropeFallback);

  static TextStyle get h1 =>
      _heading(fontSize: 44, height: 1.05, letterSpacing: -0.8);

  static TextStyle get h2 =>
      _heading(fontSize: 32, height: 1.1, letterSpacing: -0.6);

  static TextStyle get h3 =>
      _heading(fontSize: 22, weight: FontWeight.w700, letterSpacing: -0.3);

  static TextStyle get title =>
      _heading(fontSize: 18, weight: FontWeight.w700, letterSpacing: -0.2);

  static TextStyle get body => _body(fontSize: 16);

  static TextStyle get bodyMuted =>
      _body(fontSize: 16, color: SalamatColors.i2);

  static TextStyle get caption =>
      _body(fontSize: 13, height: 1.35, color: SalamatColors.i2);

  static TextStyle get btn => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.1,
        color: SalamatColors.surf,
      ).copyWith(fontFamilyFallback: _manropeFallback);

  static TextStyle get btnDark => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0.1,
        color: SalamatColors.ink,
      ).copyWith(fontFamilyFallback: _manropeFallback);

  /// Tracking-wide all-caps label for tiny eyebrow text ("CALORIES", "BMI").
  static TextStyle get eyebrow => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        height: 1.0,
        letterSpacing: 1.4,
        color: SalamatColors.i3,
      ).copyWith(fontFamilyFallback: _manropeFallback);

  static TextTheme get theme => TextTheme(
        displayLarge: h1,
        displayMedium: h2,
        headlineMedium: h3,
        titleLarge: title,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: btn,
      );
}
