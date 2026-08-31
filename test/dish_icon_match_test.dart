// ignore_for_file: avoid_print
//
// What the matcher does with names the model actually produces.
//
// Pure logic — no network, no camera — so it runs as a plain widget test too.
// Kept here because it is a report, not an assertion about pixels.

import 'package:flutter_test/flutter_test.dart';

import 'package:salamat/services/dish_icon_service.dart';

const List<String> _fromTheModel = [
  // The five you named.
  'Шаурма (донер в лаваше)',
  'Куриное филе на гриле с помидором',
  'Салат из огурцов и помидоров',
  'Плов',
  'Лагман',
  // Others this app has actually shown or is likely to.
  'Куриный бульон',
  'Картофель фри',
  'Картофель жареный с луком',
  'Борщ со сметаной',
  'Манты с говядиной',
  'Овсянка на молоке',
  'Творог 5%',
  'Яблоко',
  'Хот-дог',
  'Grilled chicken breast with vegetables',
  'Cucumber and tomato salad',
  'Beef stroganoff with mashed potato',
  'Двойной чизбургер',
  'Кофе с молоком',
  'Протеиновый коктейль',
  // The five the second icon drop added.
  'Бешбармак',
  'Куырдак из баранины',
  'Дымдама',
  'Долма',
  'Хумус с питой',
];

/// Deliberately awkward: dishes with no icon, vague answers, and things that
/// are food but not in the set. What lands here is the shopping list for the
/// next round of keywords.
const List<String> _expectedToFallBack = [
  'Домашний обед',
  'Мясо по-французски',
  'Суши с лососем',
  'Фалафель',
  'Плошка с гарниром',
  'Ассорти',
  'Тортилья с курицей и овощами',
  'Что-то из холодильника',
  'Лепёшка с каймаком',
  'Тарелка еды',
  'Хачапури по-аджарски',
  'Бургер-боул',
];

void main() {
  test('dish icon matching, on names the model returns', () {
    print('\n| name | -> file | matched on |');
    print('|---|---|---|');
    for (final n in _fromTheModel) {
      final m = DishIconService.match(n);
      print('| $n | ${m.file} | ${m.keyword ?? "-"} |');
    }

    print('\n--- names that fall back ---');
    print('\n| name | -> file | matched on |');
    print('|---|---|---|');
    for (final n in _expectedToFallBack) {
      final m = DishIconService.match(n);
      print('| $n | ${m.file} | ${m.keyword ?? "-"} |');
    }

    // Normalisation is the part everything else rests on.
    expect(DishIconService.normalise('Шаурма (донер в лаваше)'),
        'шаурма донер в лаваше');
    expect(DishIconService.normalise('Творог 5%'), 'творог 5');

    // The rule the whole design turns on.
    expect(DishIconService.match('Куриный бульон').file, 'chicken_broth.svg');
    expect(DishIconService.match('Картофель фри').file, 'french_fries.svg');

    // The five added in the second drop, including the spellings the brief
    // called out.
    expect(DishIconService.match('Бешбармак').file, 'beshbarmak.svg');
    expect(DishIconService.match('Беш').file, 'beshbarmak.svg');
    expect(DishIconService.match('Куурдак').file, 'kuurdak.svg');
    expect(DishIconService.match('Куырдак').file, 'kuurdak.svg');
    expect(DishIconService.match('Толма').file, 'dolma.svg');
    expect(DishIconService.match('Humus').file, 'hummus.svg');
    expect(DishIconService.match('Дымдама').file, 'dymdama.svg');

    // Nothing may point at a file that is not in the set.
    for (final f in DishIconService.allFiles) {
      expect(f.endsWith('.svg'), isTrue);
    }
  });
}
