import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'salamat_theme.dart';

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

  /// Keyword table, checked in order — first hit wins. Categories follow the
  /// approved set (dumplings, noodles, soup, salad, meat, breakfast, bread,
  /// dessert, drink, default) plus two Central-Asia staples the icon pack
  /// covers directly: rice/plov and samsa.
  static const List<(List<String>, String)> _rules = [
    // dumplings → манты на тарелке
    (
      [
        'мант', 'пельмен', 'вареник', 'хинкал', 'чучвар', 'хошан',
        'хоргун', 'dumpling',
      ],
      'icon_08'
    ),
    // rice, plov & grains → рис
    (
      ['плов', 'рис', 'ганфан', 'гречк', 'булгур', 'киноа', 'перловк',
        'plov', 'rice'],
      'icon_10'
    ),
    // samsa & hand pies → самса
    (['самс', 'самбус', 'пирожок', 'чебурек', 'беляш', 'эмпанад', 'samsa'],
        'icon_23'),
    // noodles → лагман в воке
    (
      [
        'лагман', 'лапш', 'бешбармак', 'норын', 'орам', 'паст', 'спагетти',
        'макарон', 'рамен', 'noodle', 'удон',
      ],
      'icon_09'
    ),
    // soup → шурпа в горшочке
    (
      [
        'суп', 'шурп', 'борщ', 'бульон', 'солянк', 'харчо', 'щи',
        'окрошк', 'мастав', 'рассольник', 'soup',
      ],
      'icon_07'
    ),
    // fast food & crunchy snacks → корзинка
    (
      [
        'бургер', 'пицц', 'хот-дог', 'наггетс', 'донер', 'шаурм', 'фри',
        'чипс', 'орех', 'миндал', 'арахис', 'фисташ', 'фундук',
      ],
      'icon_18'
    ),
    // fish & seafood → рыбная тарелка
    (
      ['рыб', 'лосос', 'форел', 'сельд', 'тунец', 'минтай', 'скумбри',
        'кревет', 'fish'],
      'icon_20'
    ),
    // breakfast → завтрак с яичницей
    (
      [
        'завтрак', 'яичниц', 'омлет', 'яйц', 'каш', 'овсян', 'сырник',
        'блин', 'оладь', 'egg', 'omelet', 'breakfast',
      ],
      'icon_22'
    ),
    // dessert → золотистая выпечка (checked before meat: «печенье» vs «печень»)
    (
      [
        'торт', 'десерт', 'печенье', 'шоколад', 'конфет', 'морожен',
        'чак-чак', 'халв', 'сладк', 'пирог', 'варень', 'хворост',
        'парвард', 'нават', 'сахар', 'зефир', 'щербет', 'шербет', 'мед',
        'мёд', 'dessert', 'cake',
      ],
      'icon_01'
    ),
    // meat & hearty stews → жареное мясо с приборами
    (
      [
        'мяс', 'говядин', 'баранин', 'свинин', 'фарш', 'куриц', 'курин',
        'котлет', 'шашлык', 'стейк', 'казы', 'куурдак', 'кебаб', 'жарко',
        'гуляш', 'долм', 'димлам', 'печень', 'индейк', 'утк', 'колбас',
        'сосиск', 'meat', 'chicken', 'beef',
      ],
      'icon_15'
    ),
    // bread & flatbreads → лепёшки/сушки
    (
      [
        'хлеб', 'лепешк', 'лепёшк', 'лаваш', 'патыр', 'катлам', 'шелпек',
        'токаш', 'батон', 'булк', 'баурсак', 'боурсак', 'сушк', 'бублик',
        'тост', 'бутерброд', 'сэндвич', 'хачапур', 'bread',
      ],
      'icon_16'
    ),
    // salad & vegetables → тарелка салата
    (
      [
        'салат', 'овощ', 'винегрет', 'помидор', 'огурец', 'морков', 'лук',
        'капуст', 'перец', 'баклажан', 'тыкв', 'свекл', 'свёкл', 'редис',
        'зелень', 'salad',
      ],
      'icon_03'
    ),
    // fruits & berries → яркая доска
    (
      [
        'яблок', 'банан', 'виноград', 'дын', 'арбуз', 'груш', 'апельсин',
        'мандарин', 'урюк', 'кураг', 'изюм', 'персик', 'гранат', 'хурм',
        'ягод', 'клубник', 'фрукт', 'apple', 'banana', 'fruit',
      ],
      'icon_14'
    ),
    // drinks & dairy → белая пиала
    (
      [
        'чай', 'кофе', 'сок', 'айран', 'кефир', 'компот', 'молок',
        'напиток', 'смузи', 'йогурт', 'кумыс', 'катык', 'курт', 'сузьм',
        'каймак', 'сметан', 'творог', 'сыр', 'брынз', 'масло', 'кол',
        'вода', 'лимонад', 'tea', 'juice',
      ],
      'icon_06'
    ),
  ];

  static String assetFor(String dishName) {
    final n = dishName.toLowerCase();
    for (final (keywords, asset) in _rules) {
      for (final k in keywords) {
        if (n.contains(k)) return 'assets/food_icons/$asset.svg';
      }
    }
    // default → сытная тарелка
    return 'assets/food_icons/icon_05.svg';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SvgPicture.asset(
        assetFor(dishName),
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}
