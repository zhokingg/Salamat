// ignore_for_file: avoid_print
//
// A meal write that the server rejects must not leave the dish sitting in the
// diary. Forces a real rejection by reusing a row id that already exists
// (duplicate key on meals_pkey) — the same class of failure as no network,
// and the only one that can be produced on demand.

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

int countAll(MealsState s) => MealType.values.expand(s.forType).length;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['ru', 'en']) {
    testWidgets('a rejected meal write is rolled back ($lang)',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      appRouter.go('/meals');
      await settle(tester, ms: 2500);

      MealEntry entry(String id, String name) => MealEntry(
            id: id,
            name: name,
            grams: 300,
            kcal: 430,
            protein: 18,
            fat: 14,
            carbs: 55,
            source: 'manual',
          );

      // 1. A write that works.
      final goodId = const Uuid().v4();
      final ok = await container
          .read(mealsProvider.notifier)
          .add(MealType.lunch, entry(goodId, 'Лагман'));
      await settle(tester, ms: 2000);
      final afterGood = container.read(mealsProvider).valueOrNull!;
      print('[$lang] good write -> $ok, entries ${countAll(afterGood)}, '
          'failure ${afterGood.writeFailure?.dish}');

      // 2. The same id again: Postgres rejects it on the primary key.
      final bad = await container
          .read(mealsProvider.notifier)
          .add(MealType.dinner, entry(goodId, 'Плов'));
      await settle(tester, ms: 2500);
      final afterBad = container.read(mealsProvider).valueOrNull!;
      print('[$lang] bad write  -> $bad, entries ${countAll(afterBad)}, '
          'failure ${afterBad.writeFailure?.dish}');

      await shot('mealfail_${lang}_diary');

      expect(ok, isTrue, reason: 'the first write should have gone through');
      expect(bad, isFalse, reason: 'a duplicate id must be reported as failed');
      expect(countAll(afterBad), countAll(afterGood),
          reason: 'the rejected dish is still in the diary');
      expect(afterBad.writeFailure?.dish, 'Плов');
    });
  }
}
