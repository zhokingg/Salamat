import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'salamat_theme.dart';

export 'package:phosphor_flutter/phosphor_flutter.dart'
    show PhosphorIcons, PhosphorIconsStyle, PhosphorIconData;

/// Phosphor icon wrapper with an optional sticker "bubble" circle behind it.
///
/// Weight conventions:
///  - **Duotone** for semantic icons (food, water, flame, achievements)
///  - **Regular** for navigation / utility icons, colored [SalamatTokens.iconQuiet]
///    (active nav tab uses [SalamatTokens.accentDeep])
///
/// The bubble circle is sized at icon × 1.8. Preset factories cover the two
/// approved sticker icons: flame on [SalamatTokens.bubbleAmber], water drop
/// on [SalamatTokens.bubbleMint].
class SalamatIcon extends StatelessWidget {
  const SalamatIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.bubbleColor,
  });

  /// Flame sticker: duotone flame on the warm amber bubble.
  factory SalamatIcon.flame({Key? key, double size = 24}) => SalamatIcon(
        PhosphorIcons.flame(PhosphorIconsStyle.duotone),
        key: key,
        size: size,
        color: SalamatTokens.amber,
        bubbleColor: SalamatTokens.bubbleAmber,
      );

  /// Water-drop sticker: duotone drop on the mint bubble.
  factory SalamatIcon.drop({Key? key, double size = 24}) => SalamatIcon(
        PhosphorIcons.drop(PhosphorIconsStyle.duotone),
        key: key,
        size: size,
        color: SalamatTokens.accent,
        bubbleColor: SalamatTokens.bubbleMint,
      );

  /// Icon data — pick the weight at the call site, e.g.
  /// `PhosphorIcons.house(PhosphorIconsStyle.regular)`.
  final PhosphorIconData icon;

  final double size;

  /// Defaults to [SalamatTokens.textPrimary].
  final Color? color;

  /// When set, the icon sits centered on a circle of `size * 1.8`.
  final Color? bubbleColor;

  @override
  Widget build(BuildContext context) {
    final glyph = PhosphorIcon(
      icon,
      size: size,
      color: color ?? SalamatTokens.textPrimary,
    );
    if (bubbleColor == null) return glyph;
    final bubble = size * 1.8;
    return Container(
      width: bubble,
      height: bubble,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: bubbleColor, shape: BoxShape.circle),
      child: glyph,
    );
  }
}
