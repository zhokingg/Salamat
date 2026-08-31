// The dish icons where they show: the diary and the meal card.
//
// Seeds a day of real dish names through the provider — the same path the app
// takes when a meal is logged — so the icons are picked by the real matcher
// from names the model actually produces.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/router.dart';

const int _shotPort = 8787;

/// (meal, name, grams, kcal, p, f, c) — names as the model returns them.
const List<(MealType, String, double, int, double, double, double)> _day = [
  (MealType.breakfast, 'Овсянка на молоке', 250, 210, 7, 5, 34),
  (MealType.breakfast, 'Кофе с молоком', 200, 45, 2, 2, 5),
  (MealType.lunch, 'Плов', 300, 620, 24, 26, 72),
  (MealType.lunch, 'Салат из огурцов и помидоров', 150, 60, 2, 3, 7),
  (MealType.dinner, 'Шаурма (донер в лаваше)', 320, 640, 30, 28, 62),
  (MealType.snack, 'Яблоко', 180, 95, 0.5, 0.3, 25),
];

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['en', 'ru']) {
    testWidgets('dish icons ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      const uuid = Uuid();
      String? plovId;
      for (final (type, name, g, kcal, p, f, c) in _day) {
        final id = uuid.v4();
        if (name == 'Плов') plovId = id;
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
                // No eatenAt: the app never sets one, the server stamps it,
                // and passing one here left the optimistic copy and the
                // fetched row looking like two different entries.
              ),
            );
      }
      await settle(tester, ms: 1500);

      appRouter.go('/meals');
      await settle(tester, ms: 3000);
      await shot('dishicons_diary_$lang');

      appRouter.push('/meal/lunch/$plovId');
      await settle(tester, ms: 2500);
      await shot('dishicons_detail_$lang');
    });
  }
}
