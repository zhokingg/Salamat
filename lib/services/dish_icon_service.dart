/// Picks a dish icon for a name the recognition model invented.
///
/// The model does not return catalogue entries. It returns things like
/// «Куриное филе на гриле с помидором» and «Шаурма (донер в лаваше)», so an
/// exact lookup against the icon set would miss almost every time. What works
/// is keyword containment: normalise the name, find every keyword that occurs
/// in it, and keep the longest.
///
/// LONGEST WINS, WITHIN THE HEAD OF THE NAME.
///   Two rules, and the second exists because the first alone gets things
///   wrong.
///
///   1. The longest matched keyword wins. «куриный бульон» contains both a
///      chicken keyword and «бульон»; scoring by keyword length sends it to
///      the broth rather than to a chicken breast. So does «картофель фри» to
///      fries rather than boiled potato.
///
///   2. Matching is tried on the HEAD of the name first — everything before
///      the first preposition or conjunction — and only falls back to the
///      whole string if the head matches nothing. Length alone sent «борщ со
///      сметаной» to sour cream, «кофе с молоком» to milk, and «шаурма (донер
///      в лаваше)» to a flatbread, because the garnish happened to be spelled
///      with more letters than the dish. What comes after «с», «со», «на», «в»
///      or «with» is what the dish is served WITH; it is not the dish.
///
///   «салат из огурцов и помидоров» shows why the fallback matters: its head
///   is the bare word «салат», which no icon claims, so the whole string is
///   used and the cucumber-and-tomato salad wins on length.
///
/// MATCHING RULES
///   * a single-word keyword matches when any word of the name STARTS with it,
///     so «рисовая каша» matches «рис» but «картошка» does not match «ош»
///     (the two-letter Kyrgyz name for plov) the way a substring search would;
///   * a keyword containing a space matches as a plain substring of the whole
///     normalised name, which is how the multi-word disambiguators work.
library;

/// Where the SVGs live. Every value in [_keywords] is a file in this folder.
const String kDishIconDir = 'assets/dish_icons';

/// Shown when nothing matches. An empty plate.
const String kDishIconFallback = '$kDishIconDir/fallback.svg';

/// Icon file -> the words that should land on it.
///
/// Both languages in one list, because the model answers in the language of
/// the app and the app has two. Russian keywords are written in the stem form
/// that survives declension: «курин» covers куриный / куриная / куриное.
const Map<String, List<String>> _keywords = {
  // ---- Рис и крупы ----
  'plov.svg': ['плов', 'палов', 'ош', 'pilaf', 'plov', 'palov'],
  'rice.svg': ['рис', 'рисов', 'rice'],
  'buckwheat.svg': ['гречк', 'гречнев', 'buckwheat'],
  'oatmeal.svg': ['овсянк', 'овсян', 'геркулес', 'oatmeal', 'porridge'],
  'bulgur.svg': ['булгур', 'bulgur'],
  'couscous.svg': ['кускус', 'couscous'],
  'quinoa.svg': ['киноа', 'quinoa'],

  // ---- Супы ----
  'borsch.svg': ['борщ', 'borsch', 'borscht'],
  'shurpa.svg': ['шурпа', 'сорпа', 'shurpa', 'sorpa'],
  'lagman.svg': ['лагман', 'lagman', 'laghman'],
  'solyanka.svg': ['солянк', 'solyanka'],
  'chicken_broth.svg': ['бульон', 'broth', 'куриный бульон', 'chicken broth'],
  'kharcho.svg': ['харчо', 'kharcho'],
  'okroshka.svg': ['окрошк', 'okroshka'],
  'mushroom_soup.svg': [
    'грибной суп', 'суп с гриб', 'mushroom soup', 'грибной крем',
  ],
  'tom_yam.svg': ['том ям', 'том-ям', 'tom yum', 'tom yam'],
  'miso.svg': ['мисо', 'miso'],

  // ---- Мясо ----
  'shashlik.svg': ['шашлык', 'шашлыч', 'кебаб', 'люля', 'shashlik', 'kebab'],
  'steak.svg': ['стейк', 'steak', 'антрекот', 'ростбиф'],
  'cutlet.svg': ['котлет', 'cutlet', 'patty'],
  'beef_stroganoff.svg': ['бефстроганов', 'stroganoff'],
  'meatballs.svg': ['тефтел', 'фрикадельк', 'митбол', 'meatball'],
  'goulash.svg': ['гуляш', 'goulash', 'азу'],
  'ribs.svg': ['ребр', 'ribs'],
  'bacon.svg': ['бекон', 'bacon', 'грудинк'],
  'sausage.svg': ['колбас', 'салями', 'sausage', 'salami'],
  'frankfurters.svg': ['сосиск', 'сардельк', 'frankfurter', 'wiener'],
  // Added in the second icon drop. Until these existed every one of them
  // landed on the empty plate, which is what the fallback list was for.
  'beshbarmak.svg': [
    'бешбармак', 'бешбарм', 'бесбармак', 'беш', 'наарын', 'besh', 'beshbarmak',
  ],
  'kuurdak.svg': [
    'куырдак', 'куурдак', 'кувурдак', 'куырд', 'куурд', 'kuurdak', 'kuyrdak',
  ],
  'dymdama.svg': [
    'дымдама', 'думляма', 'димлама', 'дымлама', 'дамлама', 'dymdama',
    'dimlama', 'damlama',
  ],
  'dolma.svg': ['долма', 'толма', 'дулма', 'dolma', 'tolma', 'сарма'],

  // ---- Птица ----
  'chicken_breast.svg': [
    'курин', 'курица', 'куриц', 'кур', 'chicken', 'куриное филе',
    'куриная грудка', 'chicken breast', 'chicken fillet', 'филе куриц',
  ],
  'chicken_thigh.svg': ['бедр', 'голен', 'thigh', 'drumstick', 'окорочок'],
  'chicken_wings.svg': ['крыл', 'wings', 'крылышк'],
  'grilled_chicken.svg': [
    'курица гриль', 'куриц гриль', 'гриль курица', 'grilled chicken',
    'цыпленок гриль', 'чикен гриль',
  ],
  'turkey.svg': ['индейк', 'индюш', 'turkey'],
  'duck.svg': ['утка', 'уток', 'утин', 'duck'],

  // ---- Рыба и морепродукты ----
  'salmon.svg': ['лосос', 'семг', 'сем', 'salmon', 'кет'],
  'trout.svg': ['форел', 'trout'],
  'cod.svg': ['треск', 'cod', 'минтай', 'хек'],
  'tuna.svg': ['тунец', 'тунц', 'tuna'],
  'shrimp.svg': ['кревет', 'shrimp', 'prawn'],
  'squid.svg': ['кальмар', 'squid', 'осьминог'],
  'herring.svg': ['селедк', 'сельд', 'herring'],
  'grilled_fish.svg': [
    'рыба на гриле', 'рыба гриль', 'grilled fish', 'рыб', 'fish',
  ],

  // ---- Тесто ----
  'manty.svg': ['манты', 'мант', 'manty', 'manti'],
  'pelmeni.svg': ['пельмен', 'pelmeni', 'dumpling'],
  'vareniki.svg': ['вареник', 'vareniki'],
  'khinkali.svg': ['хинкал', 'khinkali'],
  'samsa.svg': ['самса', 'самс', 'samsa', 'sambusa'],
  'belyash.svg': ['беляш', 'belyash'],
  'cheburek.svg': ['чебурек', 'chebureki', 'cheburek'],
  'bliny.svg': ['блин', 'блинчик', 'blini', 'crepe', 'pancake'],
  'oladyi.svg': ['оладь', 'олади', 'oladyi', 'fritter'],
  'syrniki.svg': ['сырник', 'syrniki'],

  // ---- Хлеб ----
  'flatbread.svg': ['лепешк', 'токоч', 'flatbread', 'lepeshka', 'нан'],
  'white_loaf.svg': ['батон', 'белый хлеб', 'white bread', 'булк'],
  'rye_bread.svg': ['ржан', 'черный хлеб', 'rye bread', 'хлеб', 'bread'],
  'toast.svg': ['тост', 'toast'],
  'baguette.svg': ['багет', 'baguette'],
  'lavash.svg': ['лаваш', 'lavash', 'pita'],

  // ---- Паста ----
  'spaghetti.svg': ['спагетти', 'spaghetti', 'вермишел'],
  'mac_and_cheese.svg': [
    'макароны с сыром', 'mac and cheese', 'макарон', 'macaroni',
  ],
  'lasagna.svg': ['лазань', 'lasagna', 'lasagne'],
  'ravioli.svg': ['равиол', 'ravioli', 'ньокк', 'gnocchi'],
  'pasta_bolognese.svg': [
    'болонез', 'bolognese', 'паста', 'pasta', 'фетучин', 'карбонар',
  ],

  // ---- Салаты ----
  'salad_cucumber_tomato.svg': [
    'салат из огурцов', 'огурц', 'помидор', 'томат', 'cucumber', 'tomato',
    'ачик чучук', 'шакароб',
  ],
  'olivier.svg': ['оливье', 'olivier'],
  'caesar.svg': ['цезар', 'caesar'],
  'greek_salad.svg': ['гречески', 'greek salad'],
  'vinegret.svg': ['винегрет', 'vinegret', 'vinaigrette'],
  'cabbage_salad.svg': ['капуст', 'cabbage', 'coleslaw'],
  // Not 'нут': chickpea is the right word for hummus, but as a prefix it
  // also swallows «нутелла». A chickpea dish falling back is better than
  // chocolate spread arriving as hummus.
  'hummus.svg': ['хумус', 'хуммус', 'humus', 'hummus'],

  // ---- Овощи ----
  'boiled_potato.svg': [
    'картофель отварн', 'отварной картоф', 'вареный картоф', 'boiled potato',
    'картоф', 'картош', 'potato',
  ],
  'fried_potato.svg': [
    'картофель жарен', 'жареный картоф', 'жареная картош', 'fried potato',
  ],
  'mashed_potato.svg': ['пюре', 'mashed', 'толченк'],
  'stewed_vegetables.svg': [
    'тушеные овощ', 'овощное рагу', 'stewed vegetable', 'рагу', 'овощ',
    'vegetable', 'лечо',
  ],
  'corn.svg': ['кукуруз', 'corn'],
  'broccoli.svg': ['брокколи', 'броккол', 'broccoli'],
  'carrot.svg': ['морков', 'carrot'],
  'beet.svg': ['свекл', 'beet'],

  // ---- Молочное ----
  'cottage_cheese.svg': ['творог', 'творож', 'cottage cheese'],
  'yogurt.svg': ['йогурт', 'yogurt', 'yoghurt'],
  'kefir.svg': ['кефир', 'kefir', 'простокваш'],
  'sour_cream.svg': ['сметан', 'sour cream'],
  'cheese.svg': ['сыр', 'cheese', 'моцарелл', 'пармезан'],
  'brynza.svg': ['брынз', 'brynza', 'feta', 'фета', 'сулугуни'],
  'milk.svg': ['молоко', 'молочн', 'milk'],
  'ayran.svg': ['айран', 'ayran', 'тан', 'чалап', 'максым'],

  // ---- Яйца ----
  'fried_egg.svg': ['яичниц', 'глазунь', 'fried egg', 'scrambled'],
  'omelette.svg': ['омлет', 'omelette', 'omelet'],
  'boiled_egg.svg': ['вареное яйцо', 'boiled egg', 'яйц', 'яйк', 'egg'],

  // ---- Фастфуд ----
  'burger.svg': ['бургер', 'burger', 'чизбург', 'гамбург'],
  'pizza.svg': ['пицц', 'pizza'],
  'shawarma.svg': [
    'шаурм', 'шаверм', 'донер', 'doner', 'shawarma', 'shaurma', 'дюрюм',
  ],
  'hot_dog.svg': ['хот-дог', 'хот дог', 'hot dog', 'хотдог', 'hotdog'],
  'french_fries.svg': [
    'картофель фри', 'картошка фри', 'french fries', 'фри', 'fries',
  ],
  'nuggets.svg': ['наггетс', 'nugget', 'стрипс'],
  'sandwich.svg': ['сэндвич', 'сендвич', 'бутерброд', 'sandwich', 'тортилья'],

  // ---- Фрукты ----
  'apple.svg': ['яблок', 'apple'],
  'banana.svg': ['банан', 'banana'],
  'orange.svg': ['апельсин', 'мандарин', 'orange', 'tangerine'],
  'grapes.svg': ['виноград', 'grape'],
  'watermelon.svg': ['арбуз', 'watermelon'],
  'melon.svg': ['дын', 'melon'],
  'berries.svg': [
    'ягод', 'berry', 'berries', 'клубник', 'малин', 'черник', 'strawberry',
  ],
  'pear.svg': ['груш', 'pear'],

  // ---- Орехи и снеки ----
  'nuts.svg': ['орех', 'nuts', 'миндал', 'фисташк', 'кешью', 'almond'],
  'dried_fruits.svg': [
    'сухофрукт', 'курага', 'изюм', 'финик', 'чернослив', 'dried fruit',
  ],
  'seeds.svg': ['семечк', 'семен', 'sunflower seed', 'seeds'],
  'chips.svg': ['чипс', 'chips', 'crisps'],
  'popcorn.svg': ['попкорн', 'popcorn'],

  // ---- Сладкое ----
  'cake.svg': ['торт', 'cake', 'пирожн', 'чизкейк', 'cheesecake', 'кекс'],
  'cookie.svg': ['печень', 'cookie', 'biscuit', 'пряник', 'вафл'],
  'chocolate.svg': ['шоколад', 'chocolate', 'конфет', 'candy'],
  'ice_cream.svg': ['мороженое', 'мороженого', 'ice cream', 'пломбир'],
  'honey.svg': ['мед', 'меда', 'honey'],
  'jam.svg': ['варень', 'джем', 'повидло', 'jam', 'marmalade'],
  'baklava.svg': ['пахлав', 'baklava', 'чак-чак', 'чак чак'],
  'halva.svg': ['халв', 'halva'],

  // ---- Напитки ----
  'tea.svg': ['чай', 'чая', 'tea'],
  'coffee.svg': ['кофе', 'coffee', 'капучин', 'латте', 'эспрессо', 'americano'],
  'juice.svg': ['сок', 'сока', 'juice', 'фреш'],
  'water.svg': ['вода', 'воды', 'water'],
  'kompot.svg': ['компот', 'kompot', 'морс'],
  'soda.svg': ['газировк', 'кола', 'лимонад', 'soda', 'cola', 'sprite'],
  'smoothie.svg': ['смузи', 'smoothie'],
  'protein_shake.svg': [
    'протеинов', 'протеин', 'protein shake', 'protein', 'гейнер',
  ],
};

/// A resolved icon plus what made it match, so the choice can be explained.
class DishIconMatch {
  const DishIconMatch({
    required this.assetPath,
    required this.file,
    this.keyword,
  });

  final String assetPath;
  final String file;

  /// The keyword that won, or null when nothing matched and this is the
  /// fallback.
  final String? keyword;

  bool get isFallback => keyword == null;
}

class DishIconService {
  DishIconService._();

  /// Asset path for [name], never null — the fallback plate when nothing fits.
  static String iconFor(String? name) => match(name).assetPath;

  /// Same as [iconFor] but also reports which keyword won.
  static DishIconMatch match(String? name) {
    final n = normalise(name ?? '');
    if (n.isEmpty) return _fallback;

    // The head first — «борщ» out of «борщ со сметаной» — then the whole name
    // if the head claimed nothing.
    final head = _head(n);
    return (head.isEmpty ? null : _bestIn(head)) ?? _bestIn(n) ?? _fallback;
  }

  static const DishIconMatch _fallback = DishIconMatch(
    assetPath: kDishIconFallback,
    file: 'fallback.svg',
  );

  /// Everything before the first preposition or conjunction, which is where
  /// the garnish starts. Empty when the name opens with one.
  static String _head(String n) {
    final words = n.split(' ');
    final cut = words.indexWhere(_kSeparators.contains);
    if (cut < 0) return n;
    return words.take(cut).join(' ');
  }

  /// Standalone words that introduce what the dish is served WITH, rather than
  /// what it is. Kept short and literal — anything cleverer would need a
  /// parser, and this only has to survive dish names.
  static const Set<String> _kSeparators = {
    'с', 'со', 'в', 'во', 'на', 'из', 'под', 'по', 'и', 'а',
    'with', 'and', 'in', 'on', 'over', 'plus', 'served',
  };

  /// Longest matching keyword inside [text], or null.
  static DishIconMatch? _bestIn(String text) {
    final words = text.split(' ').where((w) => w.isNotEmpty).toList();
    String? bestFile;
    String? bestKeyword;
    var bestLength = 0;

    for (final entry in _keywords.entries) {
      for (final keyword in entry.value) {
        final hit = keyword.contains(' ')
            ? text.contains(keyword)
            : words.any((w) => w.startsWith(keyword));
        if (hit && keyword.length > bestLength) {
          bestLength = keyword.length;
          bestFile = entry.key;
          bestKeyword = keyword;
        }
      }
    }
    if (bestFile == null) return null;
    return DishIconMatch(
      assetPath: '$kDishIconDir/$bestFile',
      file: bestFile,
      keyword: bestKeyword,
    );
  }

  /// Lowercase, ё folded to е, punctuation and bracket characters replaced by
  /// spaces. The words inside brackets are KEPT — «Шаурма (донер в лаваше)»
  /// becomes «шаурма донер в лаваше», and the alternative name inside the
  /// brackets is often the one that matches.
  static String normalise(String raw) {
    final lower = raw.toLowerCase().replaceAll('ё', 'е');
    final buffer = StringBuffer();
    for (final rune in lower.runes) {
      final ch = String.fromCharCode(rune);
      final isLetter = RegExp(r'[a-zа-я0-9]').hasMatch(ch);
      buffer.write(isLetter ? ch : ' ');
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Every icon in the set, for tooling and tests.
  static List<String> get allFiles =>
      [..._keywords.keys, 'fallback.svg'];
}
