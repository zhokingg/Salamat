// ignore_for_file: avoid_print
//
// Manual entry with calories only must stay calories only.
//
//   fvm flutter test integration_test/manual_entry_macros_test.dart -d <udid>
//
// Live backend, fresh anonymous account. The write goes through
// `MealsNotifier.add`, which is exactly what the sheet's "Add" button now
// calls. Before the fix the sheet called `addWithMacroBackfill`, which looked
// the macros up after the save and wrote them into the row a few seconds
// later — so the assertion here waits long enough for that to have happened
// and checks that it did not.
//
// `meals.protein/fat/carbs` are `numeric not null default 0`; 0/0/0 is the
// schema's representation of "unknown" (`MealEntry.hasMacros`), so that is
// what "null" means on this table.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/l10n/app_localizations.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/services/supabase_service.dart';

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('calories-only manual entry keeps its macros unknown',
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
    final loc = AppLocalizations.of(tester.element(find.byType(Scaffold).first))!;

    // What the sheet builds when only name + kcal are typed in.
    final soup = MealEntry(
      id: const Uuid().v4(),
      name: 'Шорпо',
      grams: 100,
      kcal: 320,
      protein: 0,
      fat: 0,
      carbs: 0,
      source: 'manual',
    );
    expect(await container.read(mealsProvider.notifier).add(MealType.lunch, soup),
        isTrue);

    // Long enough for the old background lookup to have landed.
    await settle(tester, ms: 8000);

    final rows = await SupabaseService.getFoodLogsForDay(DateTime.now());
    final row = rows.singleWhere((r) => r['id'] == soup.id,
        orElse: () => throw TestFailure('row missing from meals'));
    expect(row['kcal'], 320);
    expect((row['protein'] as num).toDouble(), 0, reason: 'protein was filled in');
    expect((row['fat'] as num).toDouble(), 0, reason: 'fat was filled in');
    expect((row['carbs'] as num).toDouble(), 0, reason: 'carbs were filled in');

    // Reload from the server and look at the day the way the screens do.
    await container.read(mealsProvider.notifier).reload();
    await settle(tester, ms: 1500);
    var state = container.read(mealsProvider).valueOrNull!;
    final live = state.forType(MealType.lunch).singleWhere((e) => e.id == soup.id);
    expect(live.hasMacros, isFalse);
    expect(state.totalKcalAll, 320);
    expect(state.hasAnyMacros, isFalse);
    expect(state.totalProtein, 0);
    // Home: the bars show a dash, not "0 / N g".
    expect(find.textContaining('${loc.valueDash} / '), findsNWidgets(3),
        reason: 'macro bars should read "— / target" when nothing is known');

    // A second entry WITH macros: calories add up, macros come from it alone.
    final plov = MealEntry(
      id: const Uuid().v4(),
      name: 'Плов',
      grams: 300,
      kcal: 650,
      protein: 42,
      fat: 24,
      carbs: 77,
      source: 'manual',
    );
    expect(
        await container.read(mealsProvider.notifier).add(MealType.dinner, plov),
        isTrue);
    await settle(tester, ms: 1500);
    state = container.read(mealsProvider).valueOrNull!;
    expect(state.totalKcalAll, 970);
    expect(state.hasAnyMacros, isTrue);
    expect(state.totalProtein, 42);
    expect(state.totalFat, 24);
    expect(state.totalCarbs, 77);
    expect(find.textContaining('42 / '), findsOneWidget);
    print('[manual] rows: '
        '${rows.map((r) => '${r['name']} ${r['kcal']} kcal P${r['protein']} F${r['fat']} C${r['carbs']}').toList()}');
  });
}
