// Day totals: calories count every entry; macros count only entries whose
// macros are known. An entry logged with calories alone is "unknown", not
// "0 g", and must neither pull a total toward zero nor make the day look
// like it has a breakdown.

import 'package:flutter_test/flutter_test.dart';

import 'package:salamat/providers/meals_provider.dart';

MealEntry e(
  String id, {
  required int kcal,
  double protein = 0,
  double fat = 0,
  double carbs = 0,
}) =>
    MealEntry(
      id: id,
      name: id,
      grams: 100,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carbs: carbs,
    );

void main() {
  test('calories-only entry has no macros', () {
    expect(e('a', kcal: 300).hasMacros, isFalse);
    expect(e('b', kcal: 300, protein: 12).hasMacros, isTrue);
  });

  test('a day of calories-only entries: kcal summed, macros unknown', () {
    final s = const MealsState()
        .copyWithAdded(MealType.breakfast, e('a', kcal: 300))
        .copyWithAdded(MealType.lunch, e('b', kcal: 500));
    expect(s.totalKcalAll, 800);
    expect(s.hasAnyMacros, isFalse);
    expect(s.totalProtein, 0);
    expect(s.totalFat, 0);
    expect(s.totalCarbs, 0);
  });

  test('mixed day: macro totals come from the known entries only', () {
    final s = const MealsState()
        .copyWithAdded(MealType.breakfast, e('a', kcal: 300)) // unknown
        .copyWithAdded(
          MealType.lunch,
          e('b', kcal: 650, protein: 42, fat: 24, carbs: 77),
        )
        .copyWithAdded(
          MealType.dinner,
          e('c', kcal: 400, protein: 30, fat: 10, carbs: 20),
        );
    expect(s.totalKcalAll, 1350, reason: 'calories include the unknown one');
    expect(s.hasAnyMacros, isTrue);
    expect(s.totalProtein, 72);
    expect(s.totalFat, 34);
    expect(s.totalCarbs, 97);
  });
}
