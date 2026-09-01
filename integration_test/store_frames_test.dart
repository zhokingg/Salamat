// ignore_for_file: avoid_print
//
// Five store frames per language, on a day that looks like a person's.
//
// The older store_screens_test walks onboarding and types two meals in through
// the UI, which is faithful but leaves the app almost empty — one dish, no
// weight history, no water. These frames are for the listing, so the day is
// seeded first: a full day of eating across four meals with eight different
// dishes, a week of weigh-ins, and water already drunk. Everything goes in
// through the same providers and tables the app itself writes.
//
//   ./scripts/capture_store.sh   (SALAMAT_TEST=integration_test/store_frames_test.dart)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/l10n/app_localizations.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/providers/water_provider.dart';
import 'package:salamat/providers/weight_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/cook/cook_screen.dart';
import 'package:salamat/services/supabase_service.dart';

const int _shotPort = 8787;

/// A day in progress: eaten so far leaves a real remainder against the norm,
/// rather than the near-zero a two-meal test day produces.
const int _calorieNorm = 2100;

/// (meal, ru name, en name, grams, kcal, protein, fat, carbs)
///
/// Eight dishes, eight different icons — oatmeal, coffee, plov, cucumber &
/// tomato salad, chicken breast, buckwheat, apple, cottage cheese.
const List<(MealType, String, String, double, int, double, double, double)>
    _day = [
  (MealType.breakfast, 'Овсянка на молоке', 'Oatmeal with milk', 260, 320, 11,
      8, 52),
  (MealType.breakfast, 'Кофе с молоком', 'Coffee with milk', 200, 60, 3, 3, 6),
  (MealType.lunch, 'Плов', 'Plov', 280, 520, 20, 22, 60),
  (MealType.lunch, 'Салат из огурцов и помидоров', 'Cucumber & tomato salad',
      160, 90, 2, 6, 7),
  (MealType.dinner, 'Куриная грудка на гриле', 'Grilled chicken breast', 180,
      240, 44, 5, 0),
  (MealType.dinner, 'Гречка', 'Buckwheat', 150, 160, 6, 2, 33),
  (MealType.snack, 'Яблоко', 'Apple', 180, 95, 0.5, 0.3, 25),
  (MealType.snack, 'Творог 5%', 'Cottage cheese 5%', 100, 120, 17, 5, 3),
];

/// Eight days of weigh-ins so the progress chart has a line to draw.
const List<double> _weights = [78.4, 78.1, 78.2, 77.8, 77.6, 77.5, 77.2, 77.1];

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final r =
        await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    await (await r.close()).drain<void>();
  } catch (_) {
  } finally {
    c.close(force: true);
  }
}

/// Writes the back-dated weigh-ins straight to `weight_logs`.
///
/// `SupabaseService.logWeight` stamps `logged_at` with now(), which would pile
/// all eight onto today and draw a vertical line. The rows are identical in
/// every other respect to what the app writes.
Future<void> seedWeightHistory() async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return;
  final today = DateTime.now();
  for (var i = 0; i < _weights.length; i++) {
    final at = today.subtract(Duration(days: _weights.length - 1 - i));
    try {
      await SupabaseService.client.from('weight_logs').insert({
        'user_id': uid,
        'weight_kg': _weights[i],
        'logged_at': at.toUtc().toIso8601String(),
      });
    } catch (e) {
      print('weight seed failed: $e');
    }
  }
}

Future<void> stockPantry(WidgetTester tester, List<String> items) async {
  for (final item in items) {
    final field = find.descendant(
      of: find.byType(CookScreen),
      matching: find.byType(TextField),
    );
    if (field.evaluate().isEmpty) return;
    await tester.enterText(field.first, item);
    await settle(tester, ms: 300);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, ms: 700);
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await settle(tester, ms: 1800);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['en', 'ru']) {
    final ru = lang == 'ru';

    testWidgets('store frames ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // A FRESH account per language.
      //
      // `SupabaseService.init` runs once per process, so the second language
      // in the same run inherited the first one's session and seeded a second
      // day onto the same account: sixteen meals, 730 kcal over the norm in
      // red, and 2.5 L of water against a 2 L goal. Signing out and back in
      // anonymously gives each language its own empty day.
      try {
        await SupabaseService.client.auth.signOut();
        await SupabaseService.client.auth.signInAnonymously();
      } catch (e) {
        print('could not reset the session: $e');
      }
      await settle(tester, ms: 2500);
      print('[$lang] account ${SupabaseService.currentUser?.id}');

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      container.read(userProvider.notifier)
        ..setName(name: ru ? 'Аида' : 'Aida', lastName: '')
        ..setGender(Gender.female)
        ..setGoal(Goal.lose)
        ..setAge(31)
        ..setBody(height: 168, weight: 77.1)
        ..setTargetWeight(70)
        ..setActivityLevel(ActivityLevel.light)
        ..setFamiliarity(Familiarity.intermediate)
        ..setCalorieNorm(_calorieNorm);
      await settle(tester, ms: 600);

      // The meals provider still holds the previous account's state right
      // after the session swap, and the first insert of the batch was landing
      // in that gap — breakfast shipped with one item instead of two. Rebuild
      // it against the new user before seeding, and check afterwards.
      container.invalidate(mealsProvider);
      await settle(tester, ms: 2500);

      const uuid = Uuid();
      String? plovId;
      for (final (type, nameRu, nameEn, g, kcal, p, f, c) in _day) {
        final id = uuid.v4();
        final name = ru ? nameRu : nameEn;
        if (nameRu == 'Плов') plovId = id;
        await container.read(mealsProvider.notifier).add(
              type,
              MealEntry(
                id: id,
                name: name,
                grams: g,
                kcal: kcal,
                protein: p,
                fat: f,
                carbs: c,
                source: 'photo',
              ),
            );
      }

      // Every dish must be there. A frame with a missing meal is worse than a
      // failed run, because nothing about it looks wrong.
      await settle(tester, ms: 2000);
      var state = container.read(mealsProvider).valueOrNull ?? const MealsState();
      var count = MealType.values.expand(state.forType).length;
      if (count != _day.length) {
        print('seeded $count of ${_day.length}; retrying the missing ones');
        final have = MealType.values
            .expand(state.forType)
            .map((e) => e.name)
            .toSet();
        for (final (type, nameRu, nameEn, g, kcal, p, f, c) in _day) {
          final name = ru ? nameRu : nameEn;
          if (have.contains(name)) continue;
          await container.read(mealsProvider.notifier).add(
                type,
                MealEntry(
                  id: uuid.v4(),
                  name: name,
                  grams: g,
                  kcal: kcal,
                  protein: p,
                  fat: f,
                  carbs: c,
                  source: 'photo',
                ),
              );
        }
        await settle(tester, ms: 2500);
        state = container.read(mealsProvider).valueOrNull ?? const MealsState();
        count = MealType.values.expand(state.forType).length;
      }
      print('[$lang] meals seeded: $count of ${_day.length}');
      expect(count, _day.length, reason: 'a dish is missing from the day');

      await seedWeightHistory();
      container.invalidate(weightLogsProvider);

      // Water, through the provider the + button uses.
      for (var i = 0; i < 5; i++) {
        await container.read(waterProvider.notifier).add();
        await settle(tester, ms: 250);
      }
      await settle(tester, ms: 2000);

      // ---- 01 diary ----
      appRouter.go('/meals');
      await settle(tester, ms: 3500);
      await shot('${lang}_01_diary');

      // ---- 02 home ----
      appRouter.go('/dashboard');
      await settle(tester, ms: 3500);
      await shot('${lang}_02_home');

      // ---- 03 the meal card ----
      appRouter.push('/meal/lunch/$plovId');
      await settle(tester, ms: 3000);
      await shot('${lang}_03_meal');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);

      // ---- 04 what to cook ----
      appRouter.push('/cook');
      await settle(tester, ms: 2500);
      await stockPantry(
        tester,
        ru
            ? const ['Курица', 'Рис', 'Помидоры']
            : const ['Chicken', 'Rice', 'Tomatoes'],
      );
      // `suggest-meal` is deployed and answering now, so ask for real cards
      // rather than shooting the stocked-but-idle screen.
      final ctx = tester.element(find.byType(CookScreen));
      final button = find.text(AppLocalizations.of(ctx)!.cookSuggestButton);
      if (button.evaluate().isNotEmpty) {
        await tester.tap(button.first, warnIfMissed: false);
        await settle(tester, ms: 16000);
      }
      await shot('${lang}_04_cook');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);

      // ---- 05 the personal plan, with the BMI scale ----
      appRouter.go('/onboarding/summary');
      await settle(tester, ms: 3000);
      await shot('${lang}_05_plan');
    });
  }
}
