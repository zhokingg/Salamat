import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'salamat_theme.dart';

import '../services/dish_icon_service.dart';

export 'package:phosphor_flutter/phosphor_flutter.dart'
    show PhosphorIcon, PhosphorIcons, PhosphorIconsStyle, PhosphorIconData;

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

/// Flat food illustration for dish cards (search results, diary entries,
/// portion sheet). UI icons stay Phosphor — illustrations appear ONLY where
/// actual FOOD is shown.
///
/// The 24 assets live in `assets/food_icons/icon_01.svg … icon_24.svg`.
/// A dish resolves to an illustration through a simple keyword table over
/// its (lowercased) name; unknown dishes fall back to a generic plate.
class FoodIllustration extends StatelessWidget {
  const FoodIllustration.forDish(
    this.dishName, {
    super.key,
    this.size = 40,
    this.radius = SalamatTokens.radiusPill,
  });

  final String dishName;
  final double size;
  final double radius;

  /// Which SVG a dish name resolves to.
  ///
  /// The ten-category keyword table that used to live here is gone. It mapped
  /// everything meaty to one plate and everything sweet to another, so a
  /// diary of ten dishes showed three pictures. The 124-icon set answers the
  /// same question properly, and [DishIconService] does the matching — see
  /// there for the rules and for what falls through to the empty plate.
  static String assetFor(String dishName) => DishIconService.iconFor(dishName);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SvgPicture.asset(
        assetFor(dishName),
        width: size,
        height: size,
        fit: BoxFit.contain,
        // The set is drawn on transparent backgrounds now, so a placeholder
        // that paints nothing avoids a flash of box while the SVG parses.
        placeholderBuilder: (_) => SizedBox(width: size, height: size),
      ),
    );
  }
}
