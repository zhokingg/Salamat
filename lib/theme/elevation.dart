import 'package:flutter/material.dart';

import 'colors.dart';

/// Premium depth tokens. Keep these tight — depth comes from restraint:
/// large-blur, low-opacity shadows; soft 1px borders; gradient stops with
/// minimal contrast. If a surface looks "flashy" it's probably overdoing it.
class SalamatElevation {
  SalamatElevation._();

  /// Card radius for primary surfaces. Buttons keep their own 14px radius.
  static const double cardRadius = 22.0;

  /// Tiles inside cards / data chips.
  static const double tileRadius = 16.0;

  /// Pill radius for badges and language toggles.
  static const double pillRadius = 12.0;

  /// One-pixel hairline used for card outlines. Subtle warm gray that
  /// disappears against the off-white background but defines edges on the
  /// surface color.
  static const Color hairline = Color(0xFFE7EFE3);

  /// Default elevated card shadow. Three layers: a tight contact shadow,
  /// a soft mid-blur, and a wide diffuse glow. Total alpha kept under 0.08
  /// so cards float without competing with content.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x08111810),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x0A111810),
      blurRadius: 16,
      offset: Offset(0, 6),
    ),
    BoxShadow(
      color: Color(0x06111810),
      blurRadius: 36,
      offset: Offset(0, 14),
    ),
  ];

  /// Used for the *selected* state of an OnboardingSelectCard — slightly
  /// stronger than [card] to telegraph emphasis without being loud.
  static const List<BoxShadow> selectedCard = [
    BoxShadow(
      color: Color(0x122E6A4A),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x081A3F2C),
      blurRadius: 38,
      offset: Offset(0, 18),
    ),
  ];

  /// Primary button shadow — green-tinted so it visually sits *under* the
  /// gradient fill rather than just shading the canvas.
  static const List<BoxShadow> primaryButton = [
    BoxShadow(
      color: Color(0x2826593C),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x10000000),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// Vertical brand gradient for primary buttons. The g1→g2 stops are the
  /// existing palette colors with a tiny lift at the top edge — the
  /// gradient gives the button a felt-finish look without changing hue.
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF2F6A47),
      SalamatColors.g1,
    ],
  );

  /// Sweep gradient stops for the dashboard / progress rings.
  static const List<Color> ringGradient = [
    SalamatColors.g1,
    SalamatColors.g2,
  ];

  /// Page background subtle warm tint. The base canvas is still
  /// [SalamatColors.bg] (mint-cream); this gradient is the same hue with a
  /// half-percent vertical drift to give scrollable surfaces a sense of depth.
  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF8FBF5),
      SalamatColors.bg,
    ],
  );
}
