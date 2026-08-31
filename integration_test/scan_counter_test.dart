// Captures the new scan-allowance UI states in both languages.
//
// LIMITATION, stated plainly: migration 0006 is not applied yet (you are
// applying it via the dashboard), so `scan_status()` does not exist and the
// server cannot report counts. The counter therefore stays hidden in a real
// run — which is itself the correct behaviour and is captured first.
//
// To photograph the states that only exist once the server answers, the test
// drives the provider's own `applyServerCounts` — the same method the Edge
// Function response feeds. That renders the real widget with real strings; it
// does NOT fake a server, and nothing is written to any database.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/subscription_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/dashboard/dashboard_screen.dart';
import 'package:salamat/screens/manual_entry/photo_limit_sheet.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['en', 'ru']) {
    testWidgets('scan counter states ($lang)', (WidgetTester tester) async {
      // `appRouter` is a top-level singleton and keeps its location across
      // tests in one process, so the funnel is skipped rather than re-walked:
      // these shots are about the counter, not onboarding.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);

      // 1. Real state today: migration not applied, server silent, so the
      //    counter is deliberately absent rather than showing a guess.
      await shot('scan_${lang}_01_no_server');

      final container =
          ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
      final notifier = container.read(subscriptionProvider.notifier);

      // 2. One scan spent — "2 of 3 left" / "Осталось 2 из 3".
      notifier.applyServerCounts(used: 1);
      await settle(tester, ms: 1200);
      await shot('scan_${lang}_02_two_left');

      // 3. Two spent — one left.
      notifier.applyServerCounts(used: 2);
      await settle(tester, ms: 1200);
      await shot('scan_${lang}_03_one_left');

      // 4. All three spent — the pill turns red.
      notifier.applyServerCounts(used: 3);
      await settle(tester, ms: 1200);
      await shot('scan_${lang}_04_none_left');

      // 5. Tapping the camera button in that state opens the limit sheet
      //    (manual entry first, subscription second) — the real path, with
      //    the corrected lifetime wording.
      showPhotoLimitSheet(tester.element(find.byType(DashboardScreen)));
      await settle(tester, ms: 1800);
      await shot('scan_${lang}_05_limit_sheet');
      if (find.byType(Navigator).evaluate().isNotEmpty) {
        appRouter.go('/dashboard');
        await settle(tester, ms: 1200);
      }
    });
  }
}
