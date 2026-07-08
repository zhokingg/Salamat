import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

/// Light "fresh green" theme tokens — the final design direction.
///
/// Single source of truth for the redesign. Screens migrate to these tokens
/// in phases; until a screen is migrated it may still reference the legacy
/// palette in [SalamatColors].
///
/// Rules of the palette:
///  - sage [background] canvas; depth comes from LAYERED COLOR, not borders
///    or shadows: cream [surface] cards sit on sage, white [surfaceAlt]
///    cards sit on cream
///  - the green [accent] is reserved for actions and progress;
///    [accentDeep] for active states and emphasis; [amber] highlights
///    streaks / weight / achievement badges
///  - text/icons ON accent fills use [onAccent] (white)
///  - big numerals stay w500–w600 (premium calm, not bold shouting)
class SalamatTokens {
  SalamatTokens._();

  // ---- colors ----
  static const background = Color(0xFFDDEBC9);
  static const surface = Color(0xFFFBF6E8);
  static const surfaceAlt = Color(0xFFFFFFFF);
  static const accent = Color(0xFF6FA53C);
  static const accentDeep = Color(0xFF52802B);
  static const amber = Color(0xFFF0B45C);
  static const pillBg = Color(0xFFE9F2DC);
  static const pillText = Color(0xFF52802B);
  static const textPrimary = Color(0xFF35402A);
  static const textMuted = Color(0xFF8A9478);
  static const iconQuiet = Color(0xFFA9B396);
  static const onAccent = Color(0xFFFFFFFF);
  static const danger = SalamatColors.danger;

  /// Neutral beige track for rings / progress on cream surfaces.
  static const ringTrack = Color(0xFFE4DFC8);

  /// Sticker-icon bubble fills.
  static const bubbleAmber = Color(0xFFF5E5C4); // flame
  static const bubbleMint = Color(0xFFE4EDE0); // water drop

  // ---- shapes ----
  static const double radiusCard = 18.0;
  static const double radiusHero = 24.0;
  static const double radiusCta = 20.0;
  static const double radiusPill = 12.0;

  /// Standard card decoration: borderless color layer.
  /// Level 1 (default) — cream [surface] on sage; pass
  /// `color: surfaceAlt` for level-2 white cards on cream.
  static BoxDecoration card({double? radius, Color? color}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(radius ?? radiusCard),
      );

  /// Pill/badge decoration.
  static BoxDecoration pill() => BoxDecoration(
        color: pillBg,
        borderRadius: BorderRadius.circular(radiusPill),
      );
}

/// Type helpers for the fresh-green theme. Manrope stays; large numerals are
/// deliberately w500–w600 — premium data displays read calm, not heavy.
class SalamatType {
  SalamatType._();

  static const List<String> _fallback = ['Roboto', 'Noto Sans', 'sans-serif'];

  static TextStyle _manrope({
    required double fontSize,
    required FontWeight weight,
    double height = 1.2,
    double letterSpacing = 0,
    Color color = SalamatTokens.textPrimary,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      ).copyWith(fontFamilyFallback: _fallback);

  /// Hero numeral (main calorie count).
  static TextStyle get numXl => _manrope(
      fontSize: 48, weight: FontWeight.w600, height: 1.0, letterSpacing: -1.0);

  /// Card-level numeral (macros, weight).
  static TextStyle get numLg => _manrope(
      fontSize: 26, weight: FontWeight.w600, height: 1.0, letterSpacing: -0.4);

  static TextStyle get h1 => _manrope(
      fontSize: 32, weight: FontWeight.w700, height: 1.1, letterSpacing: -0.6);

  static TextStyle get h2 => _manrope(
      fontSize: 24, weight: FontWeight.w700, height: 1.15, letterSpacing: -0.4);

  static TextStyle get title =>
      _manrope(fontSize: 18, weight: FontWeight.w700, letterSpacing: -0.2);

  static TextStyle get body =>
      _manrope(fontSize: 16, weight: FontWeight.w500, height: 1.45);

  static TextStyle get caption => _manrope(
      fontSize: 13,
      weight: FontWeight.w500,
      height: 1.35,
      color: SalamatTokens.textMuted);

  /// Tracking-wide all-caps eyebrow ("КАЛОРИИ", "ИМТ").
  static TextStyle get eyebrow => _manrope(
      fontSize: 11,
      weight: FontWeight.w700,
      height: 1.0,
      letterSpacing: 1.4,
      color: SalamatTokens.textMuted);

  /// Text on accent-filled buttons.
  static TextStyle get btn => _manrope(
      fontSize: 16,
      weight: FontWeight.w700,
      letterSpacing: 0.1,
      color: SalamatTokens.onAccent);

  static TextTheme get theme => TextTheme(
        displayLarge: numXl,
        displayMedium: h1,
        headlineMedium: h2,
        titleLarge: title,
        bodyLarge: body,
        bodyMedium: body,
        bodySmall: caption,
        labelLarge: btn,
        labelSmall: eyebrow,
      );
}

/// Assembled [ThemeData] for the light fresh-green look.
class SalamatTheme {
  SalamatTheme._();

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: SalamatTokens.background,
        splashFactory: InkRipple.splashFactory,
        colorScheme: const ColorScheme.light(
          primary: SalamatTokens.accent,
          onPrimary: SalamatTokens.onAccent,
          secondary: SalamatTokens.accentDeep,
          onSecondary: SalamatTokens.onAccent,
          surface: SalamatTokens.surface,
          onSurface: SalamatTokens.textPrimary,
          surfaceContainerHighest: SalamatTokens.pillBg,
          outline: SalamatTokens.iconQuiet,
          error: SalamatTokens.danger,
        ),
        textTheme: SalamatType.theme,
        dividerColor: SalamatTokens.ringTrack,
        dividerTheme: const DividerThemeData(
          color: SalamatTokens.ringTrack,
          thickness: 1,
          space: 1,
        ),
        cardTheme: CardThemeData(
          color: SalamatTokens.surface,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusCard),
          ),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: SalamatTokens.background,
          foregroundColor: SalamatTokens.textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: SalamatType.title,
          iconTheme: const IconThemeData(color: SalamatTokens.textPrimary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: SalamatTokens.accent,
            foregroundColor: SalamatTokens.onAccent,
            disabledBackgroundColor: SalamatTokens.pillBg,
            disabledForegroundColor: SalamatTokens.textMuted,
            elevation: 0,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SalamatTokens.radiusCta),
            ),
            textStyle: SalamatType.btn,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: SalamatTokens.accentDeep,
            textStyle: SalamatType.body
                .copyWith(fontWeight: FontWeight.w700, color: null),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: SalamatTokens.accentDeep,
            side: const BorderSide(color: SalamatTokens.accent, width: 1.5),
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SalamatTokens.radiusCta),
            ),
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: SalamatTokens.surface,
          selectedItemColor: SalamatTokens.accentDeep,
          unselectedItemColor: SalamatTokens.iconQuiet,
          elevation: 0,
          type: BottomNavigationBarType.fixed,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: SalamatTokens.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusCard),
          ),
          titleTextStyle: SalamatType.title,
          contentTextStyle: SalamatType.body,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: SalamatTokens.pillBg,
          contentTextStyle:
              SalamatType.body.copyWith(color: SalamatTokens.pillText),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: SalamatTokens.accent,
          linearTrackColor: SalamatTokens.ringTrack,
          circularTrackColor: SalamatTokens.ringTrack,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: SalamatTokens.surfaceAlt,
          hintStyle:
              SalamatType.body.copyWith(color: SalamatTokens.textMuted),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
            borderSide:
                const BorderSide(color: SalamatTokens.accent, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
            borderSide:
                const BorderSide(color: SalamatTokens.danger, width: 1.5),
          ),
        ),
      );
}
