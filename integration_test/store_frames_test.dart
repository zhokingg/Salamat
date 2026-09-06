// ignore_for_file: avoid_print
//
// The App Store frames: eight screens, two languages, ONE run on ONE account.
//
//   ./scripts/capture_store.sh
//   (SALAMAT_TEST=integration_test/store_frames_test.dart)
//
// WHY ONE ACCOUNT. This used to run a separate `testWidgets` per language.
// `SupabaseService.init` runs once per process, so the second language
// inherited the first one's session and seeded its day on top: sixteen meals,
// a red overrun, 2.5 L of water against a 2 L goal. Signing out between
// languages fixed the symptom but left two accounts, and nothing in the run
// proved which rows a given frame was a picture of.
//
// Now the account is created once, at the top, and everything is seeded onto
// it. Between languages the only things that change are the two a person could
// change: the interface language, and the dish names that go with it. Today's
// eight rows are DELETED and rewritten, never appended to, and the count is
// asserted against the database each time. Weights, water and the five days of
// history carry no language, so they are written once and left alone.
//
// The run fails, rather than producing a wrong frame, if:
//   * the interface language did not take effect;
//   * today holds anything other than the eight seeded dishes;
//   * "what to cook" came back with no suggestions;
//   * a screenshot is not exactly 1320 × 2868 (the shot server answers 500).

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
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/history_provider.dart';
import 'package:salamat/providers/locale_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/providers/water_provider.dart';
import 'package:salamat/providers/weight_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/cook/cook_screen.dart';
import 'package:salamat/screens/settings/settings_screen.dart';
import 'package:salamat/services/supabase_service.dart';

const int _shotPort = 8787;

/// The person in the frames.
const String _nameRu = 'Аида';
const String _nameEn = 'Aida';
const int _age = 31;
const double _height = 168;
const double _weight = 77.1;
const double _target = 70;

/// A day in progress: what is eaten leaves a real remainder against the norm,
/// rather than the near-zero a two-meal test day produces.
const int _calorieNorm = 2100;

/// Today: four meals, eight dishes, eight different icons — oatmeal, coffee,
/// plov, cucumber & tomato salad, chicken breast, buckwheat, apple, cottage
/// cheese. 1605 kcal, so 495 are left of 2100.
///
/// (meal, ru name, en name, grams, kcal, protein, fat, carbs)
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

/// Eight days of weigh-ins so the weight card and the progress chart have a
/// line to draw: 78.4 → 77.1, i.e. −1.3 kg.
const List<double> _weights = [78.4, 78.1, 78.2, 77.8, 77.6, 77.5, 77.2, 77.1];

/// Five sips of 250 ml → 1.25 of the 2.0 L goal.
const int _waterSips = 5;

/// The five days BEFORE today, keyed by how many days back.
///
/// Progress is the only screen that needs them, and it needs them to be real:
/// its calorie trend, protein score, streak and consistency grid are derived
/// from `meals` rows, so a one-day account gives one bar and "0 of 1 days on
/// target".
///
/// Built to clear the protein bar honestly rather than to make the number look
/// good: a day counts at 80 % of the 30 %-of-calories target, which is 126 g at
/// this norm. These five clear it; today, at 103.5 g, does not — so the screen
/// reads 5 of 6, not a suspicious 100 %.
///
/// Names are language-dependent like [_day], but no frame shows them, so they
/// are written once.
///
/// (ru name, en name, grams, kcal, protein, fat, carbs)
const Map<int, List<(String, String, double, int, double, double, double)>>
    _history = {
  1: [
    ('Омлет из трёх яиц', 'Three-egg omelette', 200, 330, 23, 25, 3),
    ('Творог 5%', 'Cottage cheese 5%', 200, 240, 34, 10, 6),
    ('Куриная грудка на гриле', 'Grilled chicken breast', 250, 330, 62, 7, 0),
    ('Гречка', 'Buckwheat', 200, 220, 8, 2, 45),
    ('Салат из огурцов и помидоров', 'Cucumber & tomato salad', 200, 110, 3, 8,
        8),
    ('Хлеб цельнозерновой', 'Wholegrain bread', 60, 150, 6, 2, 28),
    ('Кефир', 'Kefir', 250, 130, 9, 7, 10),
    ('Яблоко', 'Apple', 180, 95, 0.5, 0.3, 25),
  ],
  2: [
    ('Сырники', 'Syrniki', 180, 380, 26, 14, 38),
    ('Кофе с молоком', 'Coffee with milk', 200, 60, 3, 3, 6),
    ('Говядина тушёная', 'Braised beef', 220, 370, 55, 16, 2),
    ('Рис отварной', 'Boiled rice', 200, 255, 5, 1, 56),
    ('Салат из капусты', 'Cabbage salad', 180, 90, 3, 5, 9),
    ('Творог 5%', 'Cottage cheese 5%', 200, 240, 34, 10, 6),
    ('Грецкие орехи', 'Walnuts', 25, 163, 4, 16, 3),
    ('Яблоко', 'Apple', 180, 95, 0.5, 0.3, 25),
  ],
  3: [
    ('Яичница с помидорами', 'Fried eggs with tomato', 220, 310, 21, 22, 7),
    ('Хлеб цельнозерновой', 'Wholegrain bread', 60, 150, 6, 2, 28),
    ('Куриная грудка на гриле', 'Grilled chicken breast', 250, 330, 62, 7, 0),
    ('Булгур', 'Bulgur', 180, 220, 7, 2, 44),
    ('Греческий салат', 'Greek salad', 200, 180, 7, 14, 7),
    ('Творог 5%', 'Cottage cheese 5%', 200, 240, 34, 10, 6),
    ('Йогурт натуральный', 'Natural yoghurt', 250, 150, 13, 5, 14),
    ('Банан', 'Banana', 120, 105, 1, 0.3, 27),
  ],
  4: [
    ('Овсянка на молоке', 'Oatmeal with milk', 260, 320, 11, 8, 52),
    ('Варёные яйца', 'Boiled eggs', 120, 180, 13, 13, 1),
    ('Рыба на гриле', 'Grilled fish', 250, 325, 55, 11, 0),
    ('Гречка', 'Buckwheat', 180, 200, 7, 2, 41),
    ('Шурпа', 'Shurpa', 300, 330, 24, 15, 22),
    ('Хлеб цельнозерновой', 'Wholegrain bread', 60, 150, 6, 2, 28),
    ('Творог 5%', 'Cottage cheese 5%', 150, 180, 26, 8, 5),
    ('Айран', 'Ayran', 250, 110, 8, 6, 9),
  ],
  5: [
    ('Творожная запеканка', 'Cottage cheese bake', 220, 375, 31, 13, 33),
    ('Кофе с молоком', 'Coffee with milk', 200, 60, 3, 3, 6),
    ('Бешбармак', 'Beshbarmak', 300, 525, 32, 22, 49),
    ('Куриная грудка на гриле', 'Grilled chicken breast', 200, 265, 49, 6, 0),
    ('Салат из огурцов и помидоров', 'Cucumber & tomato salad', 200, 110, 3, 8,
        8),
    ('Рис отварной', 'Boiled rice', 150, 190, 3, 1, 42),
    ('Кефир', 'Kefir', 250, 130, 9, 7, 10),
    ('Яблоко', 'Apple', 180, 95, 0.5, 0.3, 25),
  ],
};

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Takes the frame, and FAILS the run if the server would not accept it.
///
/// The server reads the PNG's IHDR and answers 500 with the actual size when
/// it is not 1320 × 2868. Swallowing that — which this used to do — meant a run
/// could report success with a wrong-sized or missing frame on disk.
Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final req = await c
        .getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    final res = await req.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    if (res.statusCode != 200) {
      fail('screenshot $name rejected by the shot server: $body');
    }
  } on SocketException catch (e) {
    fail('screenshot $name: shot server unreachable ($e)');
  } finally {
    c.close(force: true);
  }
}

/// Today's dish names in `meals`, straight from the database, sorted.
///
/// The provider is a cache; this is the thing the frame is supposed to be a
/// picture of. Reading here is what makes "seeded twice" impossible to miss.
Future<List<String>> todayRows() async {
  try {
    return (await SupabaseService.getTodayFoodLogs())
        .map((r) => '${r['name']}')
        .toList()
      ..sort();
  } catch (e) {
    print('could not read today: $e');
    return const [];
  }
}

/// Deletes today's meals so the day can be written again in another language.
Future<void> clearToday() async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return;
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  try {
    await SupabaseService.client
        .from('meals')
        .delete()
        .eq('user_id', uid)
        .gte('eaten_at', start.toUtc().toIso8601String());
  } catch (e) {
    print('clearToday failed: $e');
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

/// Writes the five previous days straight into `meals`, for the same reason
/// [seedWeightHistory] exists. Prints each day's totals next to the threshold
/// they are scored against, so the number on the frame can be checked against
/// the rows that produced it.
Future<void> seedMealHistory(bool ru) async {
  final uid = SupabaseService.currentUser?.id;
  if (uid == null) return;
  final threshold = _calorieNorm * 0.30 / 4 * 0.8;
  final now = DateTime.now();
  const uuid = Uuid();
  for (final entry in _history.entries) {
    // Midday, so a timezone shift cannot push a row into the wrong day.
    final at = DateTime(now.year, now.month, now.day, 13)
        .subtract(Duration(days: entry.key));
    var kcal = 0;
    var protein = 0.0;
    for (final (nameRu, nameEn, g, k, p, f, c) in entry.value) {
      kcal += k;
      protein += p;
      try {
        await SupabaseService.client.from('meals').insert({
          'id': uuid.v4(),
          'user_id': uid,
          'name': ru ? nameRu : nameEn,
          'meal_type': 'lunch',
          'grams': g,
          'kcal': k,
          'protein': p,
          'fat': f,
          'carbs': c,
          'eaten_at': at.toUtc().toIso8601String(),
        });
      } catch (e) {
        print('history seed failed (D-${entry.key}, $nameRu): $e');
      }
    }
    print('  D-${entry.key}: ${entry.value.length} dishes, $kcal kcal, '
        'protein ${protein.toStringAsFixed(1)} g '
        '(threshold ${threshold.toStringAsFixed(1)} g) '
        '${protein >= threshold ? "on target" : "under"}');
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

  testWidgets('store frames — one account, both languages',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ru',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);

    // ---------------- one account for the whole run ----------------
    try {
      await SupabaseService.client.auth.signOut();
      await SupabaseService.client.auth.signInAnonymously();
    } catch (e) {
      print('could not start a clean session: $e');
    }
    await settle(tester, ms: 2500);
    final uid = SupabaseService.currentUser?.id;
    print('account: $uid');
    expect(uid, isNotNull, reason: 'no session — nothing can be seeded');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // ---------------- what carries no language, seeded once ----------------
    await seedWeightHistory();
    container.invalidate(weightLogsProvider);
    print('seeding history');
    await seedMealHistory(true);

    for (var i = 0; i < _waterSips; i++) {
      await container.read(waterProvider.notifier).add();
      await settle(tester, ms: 250);
    }
    await settle(tester, ms: 2000);
    final water = container.read(waterProvider).valueOrNull?.totalMl;
    print('water: $water ml of $kWaterGoalMl');
    expect(water, _waterSips * kWaterSipMl);

    const uuid = Uuid();

    // ---------------- both languages, same account ----------------
    for (final lang in const ['ru', 'en']) {
      final ru = lang == 'ru';

      // 1. The interface language, set through the provider a person's tap
      //    goes through, then given time to settle. The August frames were
      //    caught mid-switch, with English headings on a Russian screen.
      await container.read(localeProvider.notifier).setLocale(Locale(lang));
      await settle(tester, ms: 2500);
      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);

      final activeLocale = container.read(localeProvider).languageCode;
      print('[$lang] locale = $activeLocale');
      expect(activeLocale, lang, reason: 'the language did not take effect');
      final loc = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;

      // 2. Today, rewritten in this language. DELETE first: appending is what
      //    produced the doubled diary last time.
      await clearToday();
      container.invalidate(mealsProvider);
      await settle(tester, ms: 2500);

      await SupabaseService.upsertUser(
        name: ru ? _nameRu : _nameEn,
        gender: 'female',
        age: _age,
        heightCm: _height,
        weightKg: _weight,
        goal: 'lose',
        dailyCalories: _calorieNorm,
        targetWeightKg: _target,
        activityLevel: 'light',
        familiarity: 'intermediate',
      );
      container.invalidate(profileProvider);
      await settle(tester, ms: 2000);
      container.read(userProvider.notifier)
        ..setName(name: ru ? _nameRu : _nameEn, lastName: '')
        ..setGender(Gender.female)
        ..setGoal(Goal.lose)
        ..setAge(_age)
        ..setBody(height: _height, weight: _weight)
        ..setTargetWeight(_target)
        ..setActivityLevel(ActivityLevel.light)
        ..setFamiliarity(Familiarity.intermediate)
        ..setCalorieNorm(_calorieNorm);
      await settle(tester, ms: 800);

      String? plovId;
      for (final (type, nameRu, nameEn, g, kcal, p, f, c) in _day) {
        final id = uuid.v4();
        if (nameRu == 'Плов') plovId = id;
        await container.read(mealsProvider.notifier).add(
              type,
              MealEntry(
                id: id,
                name: ru ? nameRu : nameEn,
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

      // 3. Exactly what was seeded — in the database, not just in the cache.
      final rows = await todayRows();
      final expected = _day.map((e) => ru ? e.$2 : e.$3).toList()..sort();
      print('[$lang] today in db: ${rows.length} rows');
      expect(rows, expected,
          reason: 'today should hold the eight seeded dishes and nothing else');

      container.invalidate(mealsProvider);
      container.invalidate(historyProvider);
      await settle(tester, ms: 2500);
      final diary =
          container.read(mealsProvider).valueOrNull ?? const MealsState();
      final shownCount = MealType.values.expand(diary.forType).length;
      expect(shownCount, _day.length,
          reason: 'the diary shows $shownCount of ${_day.length} dishes');
      print('[$lang] diary: $shownCount dishes, ${diary.totalKcalAll} kcal, '
          '${_calorieNorm - diary.totalKcalAll} left');

      // ---- 01 home ----
      appRouter.go('/dashboard');
      await settle(tester, ms: 3500);
      await shot('${lang}_01_home');

      // ---- 02 diary ----
      appRouter.go('/meals');
      await settle(tester, ms: 3500);
      await shot('${lang}_02_diary');

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
      final suggest = find.text(loc.cookSuggestButton);
      if (suggest.evaluate().isNotEmpty) {
        await tester.tap(suggest.first, warnIfMissed: false);
        await settle(tester, ms: 18000);
      }
      // One "add to diary" button per suggested dish that is BUILT. The result
      // area is a plain ListView, so cards below the viewport are not in the
      // tree — this counts what is on screen, not what came back. Zero is the
      // case that matters: an empty result is a blank slab under the button,
      // which is what this frame must never be.
      final cards = find.text(loc.cookAddToDiary).evaluate().length;
      print('[$lang] cook: $cards suggestion card(s) built '
          '(lazy list — more may sit below the fold)');
      expect(cards, greaterThan(0),
          reason: 'the suggestion list came back empty');
      await shot('${lang}_04_cook');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);

      // ---- 05 the personal plan, with the BMI scale ----
      appRouter.go('/onboarding/summary');
      await settle(tester, ms: 3000);
      expect(find.text(loc.summaryTitle), findsOneWidget,
          reason: 'the plan headline is not in $lang');
      await shot('${lang}_05_plan');

      // ---- 06 progress ----
      appRouter.go('/progress');
      await settle(tester, ms: 4000);
      final stats = container.read(historyProvider).valueOrNull;
      if (stats != null) {
        print('[$lang] progress: ${stats.loggedDayCount} logged days, '
            'avg ${stats.dailyAverageKcal} kcal, '
            'protein score ${stats.proteinScore}% '
            '(${stats.proteinDaysOnTarget} of ${stats.loggedDayCount}), '
            'streak ${stats.streak}');
        expect(stats.loggedDayCount, _history.length + 1,
            reason: 'the week should hold today plus five seeded days');
      }
      await shot('${lang}_06_progress');

      // ---- 07 settings ----
      appRouter.push('/settings');
      await settle(tester, ms: 3000);
      final settingsLoc =
          AppLocalizations.of(tester.element(find.byType(SettingsScreen)))!;
      expect(find.text(settingsLoc.settingsTitle), findsWidgets,
          reason: 'settings is not in $lang — captured mid-switch?');
      await shot('${lang}_07_settings');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);

      // ---- 08 paywall ----
      // Offerings do not resolve here (the products are not approved yet), so
      // this is the error state, captured as it is. What must hold is the copy.
      appRouter.push('/paywall');
      await settle(tester, ms: 6000);
      final onScreen = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .join(' | ');
      for (final banned in const [
        'Google Play',
        'App Store',
        'к 8 ноя',
        '10 фото-сканов в день',
        '10 photo scans a day',
      ]) {
        expect(onScreen.contains(banned), isFalse,
            reason: 'paywall still says "$banned"');
      }
      await shot('${lang}_08_paywall');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);
    }

    print('done — one account, $uid');
  });
}
