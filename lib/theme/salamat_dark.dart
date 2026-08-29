import 'package:flutter/material.dart';

import 'colors.dart';
import 'theme_flag.dart';

/// Dark redesign tokens, transcribed from the HTML prototype
/// (`Salamat AI Nutrition (standalone).html`). See `docs/design-system.md`
/// for where every value comes from and `docs/token-map.md` for the mapping
/// off the legacy palette.
///
/// The prototype declares its tokens once, as CSS custom properties on
/// `.salamat` (light) and `.salamat.dark` (dark), and every inline style
/// refers back to them. This class is the 1:1 Flutter counterpart: a
/// [ThemeExtension] so screens read roles (`c.surface2`) instead of literals,
/// and so [AppSkin] can swap the whole set behind one flag.
@immutable
class SalamatColorsDark extends ThemeExtension<SalamatColorsDark> {
  const SalamatColorsDark({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.surface3,
    required this.text,
    required this.text2,
    required this.text3,
    required this.line,
    required this.line2,
    required this.primary,
    required this.primarySoft,
    required this.primaryInk,
    required this.onPrimary,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.accentSoft,
    required this.warn,
    required this.err,
    required this.sheet,
    required this.scrim,
    required this.skeletonBase,
    required this.skeletonHighlight,
    required this.shadow1,
    required this.shadow2,
  });

  /// Screen canvas. `--bg`
  final Color bg;

  /// Cards, bottom navigation. `--surface`
  final Color surface;

  /// Nested tiles, inputs, icon buttons, chips. `--surface-2`
  final Color surface2;

  /// Progress tracks, ring tracks, slider rails. `--surface-3`
  final Color surface3;

  /// Primary text. `--text`
  final Color text;

  /// Secondary text. `--text-2`
  final Color text2;

  /// Captions, eyebrows, units. `--text-3`
  final Color text3;

  /// Dividers inside cards. `--line`
  final Color line;

  /// Field borders, sheet grabber, chart goal line. `--line-2`
  final Color line2;

  /// Neon green accent: CTAs, calorie ring, protein. `--primary`
  final Color primary;

  /// Tinted backing for accent chips and tiles. `--primary-soft`
  final Color primarySoft;

  /// Accent text ON a background (never on an accent fill). `--primary-ink`
  final Color primaryInk;

  /// Text/icons ON an accent fill. The prototype hardcodes `#04140A`
  /// 14 times rather than routing it through a variable.
  final Color onPrimary;

  /// Carbs, "Salamat noticed", avatar. `--secondary`
  final Color secondary;
  final Color secondarySoft;

  /// Fat, water, second gradient stop. `--accent`
  final Color accent;
  final Color accentSoft;

  /// Over-target (chart bar). `--warn`
  final Color warn;

  /// Errors, heart rate. `--err`
  final Color err;

  /// Modal sheet background. `--sheet`
  final Color sheet;

  /// Scrim under a sheet. `--scrim`
  final Color scrim;

  /// `--skeleton` is a 3-stop gradient in CSS; Flutter shimmer takes two
  /// colors, so the middle stop becomes [skeletonHighlight].
  final Color skeletonBase;
  final Color skeletonHighlight;

  final List<BoxShadow> shadow1;
  final List<BoxShadow> shadow2;

  // ── prototype: .salamat.dark ──────────────────────────────────────────
  static const dark = SalamatColorsDark(
    bg: Color(0xFF000000),
    surface: Color(0xFF0C0F14),
    surface2: Color(0xFF141922),
    surface3: Color(0xFF1C2230),
    text: Color(0xFFF5F7FA),
    text2: Color(0xFF98A2B3),
    text3: Color(0xFF6B7686),
    line: Color(0x1AFFFFFF), // rgba(255,255,255,0.10)
    line2: Color(0x29FFFFFF), // rgba(255,255,255,0.16)
    primary: Color(0xFF3AE07E),
    primarySoft: Color(0x243AE07E), // rgba(58,224,126,0.14)
    primaryInk: Color(0xFF86EFAC),
    onPrimary: Color(0xFF04140A),
    secondary: Color(0xFF8B8DF7),
    secondarySoft: Color(0x298B8DF7), // rgba(139,141,247,0.16)
    accent: Color(0xFF2DD4BF),
    accentSoft: Color(0x242DD4BF), // rgba(45,212,191,0.14)
    warn: Color(0xFFFBBF24),
    err: Color(0xFFF87171),
    sheet: Color(0xFF10141B),
    scrim: Color(0x9E000000), // rgba(0,0,0,0.62)
    skeletonBase: Color(0xFF141922),
    skeletonHighlight: Color(0xFF1E242F),
    shadow1: [
      BoxShadow(color: Color(0x99000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x80000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    shadow2: [
      BoxShadow(color: Color(0xB3000000), blurRadius: 8, offset: Offset(0, 2)),
      BoxShadow(color: Color(0xB3000000), blurRadius: 60, offset: Offset(0, 24)),
    ],
  );

  // ── prototype: .salamat (light) ───────────────────────────────────────
  static const light = SalamatColorsDark(
    bg: Color(0xFFF8F9FB),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1F3F7),
    surface3: Color(0xFFE8ECF2),
    text: Color(0xFF111827),
    text2: Color(0xFF6B7280),
    text3: Color(0xFF9AA3AF),
    line: Color(0x14111827), // rgba(17,24,39,0.08)
    line2: Color(0x24111827), // rgba(17,24,39,0.14)
    primary: Color(0xFF22C55E),
    primarySoft: Color(0x1A22C55E), // rgba(34,197,94,0.10)
    primaryInk: Color(0xFF15803D),
    onPrimary: Color(0xFF04140A),
    secondary: Color(0xFF6366F1),
    secondarySoft: Color(0x1A6366F1),
    accent: Color(0xFF14B8A6),
    accentSoft: Color(0x1A14B8A6),
    warn: Color(0xFFF59E0B),
    err: Color(0xFFEF4444),
    sheet: Color(0xFFFFFFFF),
    scrim: Color(0x6B111827), // rgba(17,24,39,0.42)
    skeletonBase: Color(0xFFEEF1F6),
    skeletonHighlight: Color(0xFFF7F9FC),
    shadow1: [
      BoxShadow(color: Color(0x0A111827), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0D111827), blurRadius: 16, offset: Offset(0, 6)),
    ],
    shadow2: [
      BoxShadow(color: Color(0x0D111827), blurRadius: 6, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x17111827), blurRadius: 40, offset: Offset(0, 18)),
    ],
  );

  /// Rollback skin: the LEGACY palette poured into the new role names, so
  /// flipping [kAppSkin] restores the old colours without touching screen
  /// code. Layout stays the redesigned one — see `docs/token-map.md`.
  static const legacy = SalamatColorsDark(
    bg: SalamatColors.bg,
    surface: SalamatColors.surf,
    surface2: SalamatColors.g4,
    surface3: SalamatColors.g3,
    text: SalamatColors.ink,
    text2: SalamatColors.i2,
    text3: SalamatColors.i3,
    line: SalamatColors.line,
    line2: SalamatColors.i3,
    primary: SalamatColors.g2,
    primarySoft: SalamatColors.g4,
    primaryInk: SalamatColors.g1,
    onPrimary: SalamatColors.surf,
    secondary: SalamatColors.g1,
    secondarySoft: SalamatColors.g3,
    accent: SalamatColors.g2,
    accentSoft: SalamatColors.g4,
    warn: SalamatColors.warn,
    err: SalamatColors.danger,
    sheet: SalamatColors.surf,
    scrim: Color(0x6B131A10),
    skeletonBase: SalamatColors.g4,
    skeletonHighlight: SalamatColors.surf,
    shadow1: [
      BoxShadow(color: Color(0x08131A10), blurRadius: 4, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x0A131A10), blurRadius: 16, offset: Offset(0, 6)),
    ],
    shadow2: [
      BoxShadow(color: Color(0x0D131A10), blurRadius: 6, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x17131A10), blurRadius: 40, offset: Offset(0, 18)),
    ],
  );

  /// Camera chrome. The prototype hardcodes these outside the token system,
  /// identically in both themes, so they are not part of the light/dark swap.
  static const camBg = Color(0xFF07090C);
  static const camGradientCenter = Color(0xFF1B2027);
  static const camGlass = Color(0x1FFFFFFF); // rgba(255,255,255,0.12)
  static const camGlassStrong = Color(0x24FFFFFF); // rgba(255,255,255,0.14)
  static const camScanFill = Color(0x1022C55E); // rgba(34,197,94,0.06)
  static const camBoxFill = Color(0x1A22C55E); // rgba(34,197,94,0.10)

  /// Pro card gradient in Profile + crown tile on the paywall.
  static const proCardFrom = Color(0xFF111827);
  static const proCardTo = Color(0xFF1F2937);
  static const proCrown = Color(0xFFFDE68A);
  static const crownTileFrom = Color(0xFFF59E0B);
  static const crownTileTo = Color(0xFFEF4444);

  @override
  SalamatColorsDark copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? surface3,
    Color? text,
    Color? text2,
    Color? text3,
    Color? line,
    Color? line2,
    Color? primary,
    Color? primarySoft,
    Color? primaryInk,
    Color? onPrimary,
    Color? secondary,
    Color? secondarySoft,
    Color? accent,
    Color? accentSoft,
    Color? warn,
    Color? err,
    Color? sheet,
    Color? scrim,
    Color? skeletonBase,
    Color? skeletonHighlight,
    List<BoxShadow>? shadow1,
    List<BoxShadow>? shadow2,
  }) {
    return SalamatColorsDark(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      primary: primary ?? this.primary,
      primarySoft: primarySoft ?? this.primarySoft,
      primaryInk: primaryInk ?? this.primaryInk,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      secondarySoft: secondarySoft ?? this.secondarySoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      warn: warn ?? this.warn,
      err: err ?? this.err,
      sheet: sheet ?? this.sheet,
      scrim: scrim ?? this.scrim,
      skeletonBase: skeletonBase ?? this.skeletonBase,
      skeletonHighlight: skeletonHighlight ?? this.skeletonHighlight,
      shadow1: shadow1 ?? this.shadow1,
      shadow2: shadow2 ?? this.shadow2,
    );
  }

  @override
  SalamatColorsDark lerp(SalamatColorsDark? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return SalamatColorsDark(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surface2: c(surface2, other.surface2),
      surface3: c(surface3, other.surface3),
      text: c(text, other.text),
      text2: c(text2, other.text2),
      text3: c(text3, other.text3),
      line: c(line, other.line),
      line2: c(line2, other.line2),
      primary: c(primary, other.primary),
      primarySoft: c(primarySoft, other.primarySoft),
      primaryInk: c(primaryInk, other.primaryInk),
      onPrimary: c(onPrimary, other.onPrimary),
      secondary: c(secondary, other.secondary),
      secondarySoft: c(secondarySoft, other.secondarySoft),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      warn: c(warn, other.warn),
      err: c(err, other.err),
      sheet: c(sheet, other.sheet),
      scrim: c(scrim, other.scrim),
      skeletonBase: c(skeletonBase, other.skeletonBase),
      skeletonHighlight: c(skeletonHighlight, other.skeletonHighlight),
      shadow1: t < 0.5 ? shadow1 : other.shadow1,
      shadow2: t < 0.5 ? shadow2 : other.shadow2,
    );
  }
}

/// Radii, spacing and component metrics, all lifted from the prototype.
class SalamatDarkDims {
  SalamatDarkDims._();

  // ── radii ──
  static const double rPill = 99;
  static const double rSplashTile = 34;
  static const double rSheetTop = 32;
  static const double rViewfinder = 28;
  static const double rHero = 24;
  static const double rCard = 22;
  static const double rTile = 20;
  static const double rButton = 18;
  static const double rField = 16;
  static const double rGlass = 15;
  static const double rIcon42 = 14;
  static const double rIcon38 = 13;
  static const double rIcon36 = 12;
  static const double rAdd = 10;
  static const double rStep = 9;
  static const double rBar = 8;
  static const double rCheck = 7;
  static const double rCell = 5;

  // ── screen padding ──
  /// Onboarding: `padding: 60px 24px 34px`.
  static const EdgeInsets onboardingPad =
      EdgeInsets.only(left: 24, right: 24, top: 60, bottom: 34);

  /// Main screens: `padding: 0 20px`.
  static const double screenPadH = 20;

  // ── card padding ──
  static const double padHero = 22;
  static const double padCard = 20;
  static const double padCardTight = 18;
  static const double padCardSmall = 16;
  static const EdgeInsets padMealCard =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);

  // ── gaps (the prototype's actual set) ──
  static const double gap2 = 2;
  static const double gap4 = 4;
  static const double gap5 = 5;
  static const double gap6 = 6;
  static const double gap8 = 8;
  static const double gap10 = 10;
  static const double gap12 = 12;
  static const double gap14 = 14;
  static const double gap16 = 16;
  static const double gap20 = 20;
  static const double gap22 = 22;
  static const double gap24 = 24;
  static const double gap26 = 26;
  static const double gap28 = 28;
  static const double gap32 = 32;

  // ── components ──
  static const double ctaPad = 17;

  /// The prototype sizes its CTA by padding (17 + a 16/1.2 line ~= 54).
  /// Kept as an explicit height for call sites that need a fixed box.
  static const double buttonHeight = 54;
  static const double sheetButtonPad = 16;
  static const double navHeight = 94;
  static const double navTabWidth = 62;
  static const double navIcon = 21;
  static const double fabSize = 58;
  static const double fabOverlap = 18;
  static const double fabIcon = 24;
  static const double ringSize = 132;
  static const double ringStroke = 11;
  static const double macroBar = 6;
  static const double macroBarPlan = 3;
  static const double onbProgressBar = 4;
  static const double sliderTrack = 6;
  static const double sliderThumb = 28;
  static const double chartHeight = 132;
  static const double weightChartHeight = 84;
  static const double shutterSize = 78;
  static const double iconBtn36 = 36;
  static const double iconBtn38 = 38;
  static const double iconTile42 = 42;
  static const double glassBtn = 48;
  static const double splashTile = 112;
  static const double splashIcon = 46;

  /// Viewfinder frame: `inset: 112px 34px 176px`.
  static const EdgeInsets viewfinderInset =
      EdgeInsets.only(top: 112, left: 34, right: 34, bottom: 176);

  /// The prototype's single easing curve.
  static const Curve ease = Cubic(0.22, 1, 0.36, 1);
}

/// Type scale. The prototype uses the **system** font
/// (`'Figtree', -apple-system, system-ui, sans-serif`) and only two weights,
/// 500 and 600. Figtree ships no Cyrillic at all, so this app renders in the
/// platform system face — which is exactly what the prototype itself falls
/// back to for any non-Latin text. No network font, no bundled font.
/// Rationale: `docs/design-system.md` → "Шрифт".
class SalamatDarkType {
  SalamatDarkType._();

  /// `null` = platform system font (SF Pro on iOS, Roboto on Android).
  static const String? family = null;

  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semi = FontWeight.w600;

  static TextStyle _s({
    required double size,
    FontWeight weight = medium,
    double? height,
    double? tracking,
    bool tabular = false,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        // CSS `em` tracking → Flutter's absolute letterSpacing.
        letterSpacing: tracking == null ? null : tracking * size,
        fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
      );

  // ── display / numerals ──
  static TextStyle get logo => _s(size: 38, weight: semi, tracking: -0.04);
  static TextStyle get display =>
      _s(size: 38, weight: semi, height: 1.06, tracking: -0.04);
  static TextStyle get numXxl => _s(
      size: 82, weight: semi, height: 1, tracking: -0.05, tabular: true);
  static TextStyle get numXl => _s(
      size: 38, weight: semi, height: 1, tracking: -0.04, tabular: true);
  static TextStyle get numL => _s(
      size: 34, weight: semi, height: 1, tracking: -0.04, tabular: true);
  static TextStyle get numM =>
      _s(size: 26, weight: semi, tracking: -0.03, tabular: true);

  // ── headings ──
  static TextStyle get h1 =>
      _s(size: 30, weight: semi, height: 1.1, tracking: -0.035);
  static TextStyle get h2 => _s(size: 24, weight: semi, tracking: -0.03);
  static TextStyle get h3 => _s(size: 21, weight: semi, tracking: -0.02);
  static TextStyle get title => _s(size: 20, weight: semi, tracking: -0.02);

  // ── body ──
  static TextStyle get bodyL => _s(size: 16);
  static TextStyle get body => _s(size: 15);
  static TextStyle get bodyM => _s(size: 14.5);
  static TextStyle get bodyS => _s(size: 14);
  static TextStyle get captionL => _s(size: 13.5, height: 1.5);
  static TextStyle get caption => _s(size: 13);
  static TextStyle get captionS => _s(size: 12.5);
  static TextStyle get captionXs => _s(size: 12);
  static TextStyle get micro => _s(size: 11.5);
  static TextStyle get tab => _s(size: 10);

  // ── buttons ──
  static TextStyle get btn => _s(size: 16, weight: semi);
  static TextStyle get btnS => _s(size: 15.5, weight: semi);

  // ── eyebrows (uppercase, wide tracking) ──
  static TextStyle get eyebrow =>
      _s(size: 11, weight: semi, height: 1, tracking: 0.12);
  static TextStyle get eyebrowS =>
      _s(size: 10.5, weight: semi, tracking: 0.06);

  /// Numeric variants for values that recalculate in place.
  static TextStyle get numBody => _s(size: 15, weight: semi, tabular: true);
  static TextStyle get numCaption => _s(size: 13, tabular: true);
  static TextStyle get numTitle =>
      _s(size: 20, weight: semi, tracking: -0.02, tabular: true);
  static TextStyle get numH3 =>
      _s(size: 21, weight: semi, tracking: -0.02, tabular: true);
  static TextStyle get numStat => _s(size: 16, weight: semi, tabular: true);

  /// Migration shim for call sites that used `GoogleFonts.manrope(...)`.
  ///
  /// Keeps the caller's size/colour but enforces two prototype rules:
  /// the platform system family, and only two weights — anything w600 and
  /// above collapses to 600, anything below to 500. Call sites that the
  /// prototype specifies exactly use the named scale entries instead.
  static TextStyle style({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
    Color? decorationColor,
    List<FontFeature>? fontFeatures,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: fontSize,
        fontWeight: fontWeight == null
            ? null
            : (fontWeight.index >= FontWeight.w600.index ? semi : medium),
        color: color,
        height: height,
        letterSpacing: letterSpacing,
        decoration: decoration,
        decorationColor: decorationColor,
        fontFeatures: fontFeatures,
      );

  static TextTheme theme(Color text) => TextTheme(
        displayLarge: display.copyWith(color: text),
        displayMedium: h1.copyWith(color: text),
        headlineMedium: h2.copyWith(color: text),
        headlineSmall: h3.copyWith(color: text),
        titleLarge: title.copyWith(color: text),
        bodyLarge: bodyL.copyWith(color: text),
        bodyMedium: body.copyWith(color: text),
        bodySmall: caption.copyWith(color: text),
        labelLarge: btn.copyWith(color: text),
        labelSmall: eyebrow.copyWith(color: text),
      ).apply(fontFamily: SalamatDarkType.family);
}

/// Builds the [ThemeData] for the redesign, with the palette chosen by
/// [kAppSkin] so a single flag rolls the whole thing back.
class SalamatDarkTheme {
  SalamatDarkTheme._();

  static SalamatColorsDark get colors => switch (kAppSkin) {
        AppSkin.protoDark => SalamatColorsDark.dark,
        AppSkin.protoLight => SalamatColorsDark.light,
        AppSkin.legacy => SalamatColorsDark.legacy,
      };

  static Brightness get brightness =>
      kAppSkin == AppSkin.protoDark ? Brightness.dark : Brightness.light;

  static ThemeData get theme {
    final c = colors;
    final b = brightness;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: SalamatDarkType.family,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      colorScheme: ColorScheme(
        brightness: b,
        primary: c.primary,
        onPrimary: c.onPrimary,
        secondary: c.secondary,
        onSecondary: c.onPrimary,
        error: c.err,
        onError: c.onPrimary,
        surface: c.surface,
        onSurface: c.text,
      ),
      textTheme: SalamatDarkType.theme(c.text),
      dividerColor: c.line,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: c.text),
        titleTextStyle: SalamatDarkType.h3.copyWith(color: c.text),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: c.scrim,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SalamatDarkDims.rSheetTop),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.sheet,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
        ),
        titleTextStyle: SalamatDarkType.h3.copyWith(color: c.text),
        contentTextStyle: SalamatDarkType.captionL.copyWith(color: c.text2),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surface2,
        contentTextStyle: SalamatDarkType.captionL.copyWith(color: c.text),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rButton),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface2,
        hintStyle: SalamatDarkType.bodyS.copyWith(color: c.text3),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
          borderSide: BorderSide(color: c.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
          borderSide: BorderSide(color: c.primary, width: 1.5),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: c.primary,
        linearTrackColor: c.surface3,
        circularTrackColor: c.surface3,
      ),
      iconTheme: IconThemeData(color: c.text2),
      extensions: [c],
    );
  }
}

/// `context.c` — the redesign palette for the current skin.
extension SalamatDarkContext on BuildContext {
  SalamatColorsDark get c =>
      Theme.of(this).extension<SalamatColorsDark>() ?? SalamatDarkTheme.colors;
}

/// Skin palette without a [BuildContext].
///
/// [kAppSkin] is a compile-time constant, so this resolves to exactly the same
/// instance the [SalamatColorsDark] theme extension carries. Use `context.c`
/// where a context is at hand; use this inside `const`-heavy widget trees and
/// static helpers.
SalamatColorsDark get sc => SalamatDarkTheme.colors;
