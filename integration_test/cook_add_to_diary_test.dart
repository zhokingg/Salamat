// ignore_for_file: avoid_print
//
// "Add to diary" on the cook screen must land the dish in `meals`.
//
//   fvm flutter test integration_test/cook_add_to_diary_test.dart -d <udid>
//
// The write is driven through the same code the button uses —
// `suggestionEntry` + `MealsNotifier.add` — against the live backend on a
// fresh anonymous account, so the row is subject to the real constraints and
// RLS. The suggestion UI itself is not driven: it needs the `suggest-meal`
// Edge Function and a pantry, and the bug was never there.
//
// Regression guard: before the fix every suggestion carried grams 0, Postgres
// rejected it with 23514 (`meals_grams_check`, then `grams > 0`), and the
// screen said "added". Needs migration 0011 (`grams >= 0`) applied: the
// unweighed recipe below is written with grams 0 on purpose.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/cook/cook_screen.dart';
import 'package:salamat/services/meal_suggestion_service.dart';
import 'package:salamat/services/supabase_service.dart';

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// A suggestion shaped exactly like the Edge Function's JSON.
final MealSuggestion _plov = MealSuggestion.fromJson({
  'name': 'Плов с курицей',
  'time_minutes': 40,
  'ingredients': [
    {'name': 'рис', 'amount': '150 г'},
    {'name': 'куриное бедро', 'amount': '200 г'},
    {'name': 'морковь', 'amount': '1 шт'},
    {'name': 'масло', 'amount': '30 мл'},
    {'name': 'соль', 'amount': 'по вкусу'},
  ],
  'kcal': {'min': 620, 'max': 720},
  'protein_g': {'min': 38, 'max': 46},
  'fat_g': {'min': 20, 'max': 28},
  'carbs_g': {'min': 70, 'max': 84},
  'steps': ['Обжарить', 'Засыпать рис', 'Томить 25 минут'],
})!;

/// Nothing weighed: only pieces and "to taste".
final MealSuggestion _omelette = MealSuggestion.fromJson({
  'name': 'Омлет',
  'ingredients': [
    {'name': 'яйца', 'amount': '3 шт'},
    {'name': 'соль', 'amount': 'по вкусу'},
  ],
  'kcal': {'min': 280, 'max': 340},
})!;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('weighedGrams adds up grams and millilitres only', () {
    expect(_plov.weighedGrams, 380); // 150 + 200 + 30; "1 шт" ignored
    expect(_omelette.weighedGrams, 0);
    expect(
      MealSuggestion.fromJson({
        'name': 'x',
        'kcal': {'min': 1, 'max': 2},
        'ingredients': [
          {'name': 'a', 'amount': '0,5 кг'},
          {'name': 'b', 'amount': '100ml'},
          {'name': 'c', 'amount': '2 x 50 g'},
        ],
      })!
          .weighedGrams,
      650, // 500 + 100 + 50 (the first number-unit pair of "2 x 50 g")
    );
  });

  testWidgets('a generated dish lands in meals for today and in the diary',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ru',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(bootstrapProvider.future);
    await container.read(mealsProvider.future);
    appRouter.go('/dashboard');
    await settle(tester, ms: 2500);

    final before = await SupabaseService.getFoodLogsForDay(DateTime.now());
    expect(before, isEmpty, reason: 'fresh anonymous account expected');

    // 1. Weighed recipe.
    final plov = suggestionEntry(_plov);
    expect(plov.grams, 380);
    expect(plov.kcal, 670);
    expect(plov.protein, 42);
    expect(plov.fat, 24);
    expect(plov.carbs, 77);
    final ok1 = await container
        .read(mealsProvider.notifier)
        .add(MealType.lunch, plov);
    expect(ok1, isTrue, reason: 'the write was rejected');

    // 2. Recipe with nothing weighed: portion unknown, written as 0 — the
    //    row the old constraint used to reject.
    final omelette = suggestionEntry(_omelette);
    expect(omelette.grams, 0);
    expect(omelette.kcal, 310);
    final ok2 = await container
        .read(mealsProvider.notifier)
        .add(MealType.breakfast, omelette);
    expect(ok2, isTrue,
        reason: 'grams 0 rejected — is migration 0011 applied?');
    await settle(tester, ms: 1500);

    // In the provider — what the home screen renders.
    final state = container.read(mealsProvider).valueOrNull!;
    expect(state.writeFailure, isNull);
    expect(state.forType(MealType.lunch).map((e) => e.id), contains(plov.id));
    expect(state.forType(MealType.breakfast).map((e) => e.id),
        contains(omelette.id));
    expect(find.text('Плов с курицей'), findsWidgets,
        reason: 'the dish is not on the home screen');

    // In the database, under today.
    final rows = await SupabaseService.getFoodLogsForDay(DateTime.now());
    final row = rows.singleWhere((r) => r['id'] == plov.id,
        orElse: () => throw TestFailure('plov row missing from meals'));
    expect(row['name'], 'Плов с курицей');
    expect((row['grams'] as num).toDouble(), 380);
    expect(row['kcal'], 670);
    expect((row['protein'] as num).toDouble(), 42);
    expect((row['fat'] as num).toDouble(), 24);
    expect((row['carbs'] as num).toDouble(), 77);
    expect(row['meal_type'], 'lunch');
    final eatenAt = DateTime.parse(row['eaten_at'] as String).toLocal();
    final now = DateTime.now();
    expect((eatenAt.year, eatenAt.month, eatenAt.day),
        (now.year, now.month, now.day));
    final omeletteRow = rows.singleWhere((r) => r['id'] == omelette.id,
        orElse: () => throw TestFailure('omelette row missing from meals'));
    expect((omeletteRow['grams'] as num).toDouble(), 0);
    expect(omeletteRow['kcal'], 310);
    expect(omeletteRow['meal_type'], 'breakfast');
    print('[cook] rows today: '
        '${rows.map((r) => '${r['name']} ${r['grams']} g ${r['kcal']} kcal').toList()}');
  });
}
