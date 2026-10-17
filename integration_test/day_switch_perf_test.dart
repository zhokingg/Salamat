// ignore_for_file: avoid_print
//
// How long a tap on the date strip takes, and what it costs in requests.
//
//   fvm flutter test integration_test/day_switch_perf_test.dart -d <udid>
//
// Every Supabase request goes through a client that adds a fixed delay
// (simulated slow network — the simulator has no link conditioner of its own)
// and records the table it hit. For each day switch the test reports:
//
//   * ms from `select(day)` to the new day fully rendered — diary and water
//     both in data state and the header showing the new date;
//   * which requests fired, and how many;
//   * how many frames the calorie card was missing (the "empty-state flash").
//
// Progress is visited first so its branch is alive in the IndexedStack —
// that is the realistic case, and the one where history used to refetch on
// every day change. Runs against the live backend on a fresh anonymous
// account; the numbers it prints are the deliverable, the asserts are the
// contract after the fix.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/l10n/app_localizations.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/history_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/selected_date_provider.dart';
import 'package:salamat/providers/water_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/services/supabase_service.dart';

const Duration kLatency = Duration(milliseconds: 300);

/// Delays every request by [kLatency] and logs `METHOD table`.
class _ThrottledClient extends http.BaseClient {
  _ThrottledClient(this._inner);
  final http.Client _inner;
  final List<String> log = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final seg = request.url.pathSegments;
    // /rest/v1/<table> or /auth/v1/<x> or /functions/v1/<fn>
    final target = seg.length >= 3 ? '${seg[0]}/${seg[2]}' : request.url.path;
    log.add('${request.method} $target');
    await Future<void>.delayed(kLatency);
    return _inner.send(request);
  }
}

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

MealEntry meal(String name, int kcal) => MealEntry(
      id: const Uuid().v4(),
      name: name,
      grams: 200,
      kcal: kcal,
      protein: 20,
      fat: 10,
      carbs: 40,
    );

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('switching days: time, requests, flash', (tester) async {
    final client = _ThrottledClient(http.Client());
    SupabaseService.httpClientOverride = client;
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

    // Two days of data so both have something to render.
    final notifier = container.read(mealsProvider.notifier);
    expect(await notifier.add(MealType.lunch, meal('Сегодня обед', 600)), isTrue);
    final yesterday = today().subtract(const Duration(days: 1));
    container.read(selectedDateProvider.notifier).select(yesterday);
    await container.read(mealsProvider.future);
    await settle(tester, ms: 1500);
    expect(await notifier.add(MealType.dinner, meal('Вчера ужин', 700)), isTrue);
    container.read(selectedDateProvider.notifier).goToToday();
    await container.read(mealsProvider.future);
    await settle(tester, ms: 1500);

    // Make the Progress branch alive, then come back.
    appRouter.go('/progress');
    await settle(tester, ms: 2500);
    await container.read(historyProvider.future);
    appRouter.go('/dashboard');
    await settle(tester, ms: 1500);

    Future<void> measure(String label, DateTime day) async {
      client.log.clear();
      var missingFrames = 0;
      var skeletonFrames = 0;
      var loadingNoValueFrames = 0;
      final sw = Stopwatch()..start();
      container.read(selectedDateProvider.notifier).select(day);
      // Pump frame by frame until the day is fully there, tracking frames
      // where the calorie card (the body of the screen) is not on screen.
      while (sw.elapsedMilliseconds < 15000) {
        await tester.pump(const Duration(milliseconds: 16));
        // The ring's caption is '<kcal unit> <left|over>' — one string, so
        // `textContaining`, not an exact match.
        if (find.textContaining(loc.dashboardLeftLabel).evaluate().isEmpty &&
            find
                .textContaining(loc.dashboardOverflowLabel)
                .evaluate()
                .isEmpty) {
          missingFrames++;
        }
        if (find
            .byWidgetPredicate(
                (w) => w.runtimeType.toString() == '_Skeleton')
            .evaluate()
            .isNotEmpty) {
          skeletonFrames++;
        }
        final m = container.read(mealsProvider);
        final w = container.read(waterProvider);
        if (m.isLoading && !m.hasValue) loadingNoValueFrames++;
        if (m is AsyncData<MealsState> &&
            !m.isLoading &&
            w is AsyncData<WaterState> &&
            !w.isLoading) {
          break;
        }
      }
      // One more frame so what the providers hold is what is painted.
      await tester.pump(const Duration(milliseconds: 16));
      sw.stop();
      // Let late requests (history) land in the log before reading it.
      await settle(tester, ms: 1200);
      print('[perf] $label: ${sw.elapsedMilliseconds} ms to render, '
          '${client.log.length} requests ${client.log}, '
          'frames without calorie card: $missingFrames '
          '(skeleton: $skeletonFrames, loading-without-value: '
          '$loadingNoValueFrames)');
    }

    await measure('today → yesterday (first visit)', yesterday);
    await measure('yesterday → today (revisit)', today());
    await measure('today → yesterday (revisit)', yesterday);
    final twoAgo = today().subtract(const Duration(days: 2));
    await measure('yesterday → 2 days ago (first visit, empty day)', twoAgo);

    // Contract after the fix. A first visit may fetch the day's meals and
    // water; nothing may re-fetch history, and a revisit fetches nothing.
    client.log.clear();
    await measure('2 days ago → today (revisit)', today());
    expect(client.log.where((r) => r.contains('meals')).length, 0,
        reason: 'revisiting a day must not refetch meals');
    expect(client.log.where((r) => r.contains('water_logs')).length, 0,
        reason: 'revisiting a day must not refetch water');
  });
}
