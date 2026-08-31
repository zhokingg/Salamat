// Live verification of the paths unlocked by migrations 0004, 0005 and 0006.
//
// Water, the scan allowance and the macro backfill have never actually run
// against a real database before. This drives them on the simulator and reads
// every result back out of Supabase, printing LIVE| lines for the report.
//
// The simulator has no camera, so `recognize-food` is invoked directly with a
// small embedded JPEG — but through the APP'S OWN SESSION, so the counters and
// the UI belong to the same user.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/subscription_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/dashboard/dashboard_screen.dart';
import 'package:salamat/screens/manual_entry/manual_entry_sheet.dart';
import 'package:salamat/screens/meals/meals_screen.dart';
import 'package:salamat/services/supabase_service.dart';

const int _shotPort = 8787;

/// 96x96 JPEG, one of the app's own food icons. Small enough to embed; the
/// point is to exercise the real endpoint, not to be a good photograph.
const String _tinyJpegB64 =
    '/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAA'
    'A6ABAAMAAAABAAEAAKACAAQAAAABAAAAYKADAAQAAAABAAAAYAAAAAD/7QA4UGhvdG9zaG9wIDMu'
    'MAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgAYABgAwEiAAIR'
    'AQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAAB'
    'fQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5'
    'OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeo'
    'qaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMB'
    'AQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYS'
    'QVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNU'
    'VVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5'
    'usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMABAQEBAQEBgQEBgkGBgYJ'
    'DAkJCQkMDwwMDAwMDxIPDw8PDw8SEhISEhISEhUVFRUVFRkZGRkZHBwcHBwcHBwcHP/bAEMBBAUF'
    'BwcHDAcHDB0UEBQdHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0dHR0d'
    'HR0dHf/dAAQABv/aAAwDAQACEQMRAD8A+/qKKKACqOp6np+jWMupapOltbQDc8jnAA/qT2A5NXSQ'
    'BknAFfMXxg8QLrfiC18L2z77TTVFzcgfdaZx+7U+u1efxrzswxiwtCVV79PUxrVFTi5HaH46+E/P'
    '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'
    '93/GtYAAYHAFLRXckkYpWCiiimM//9k=';

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

  testWidgets('live: water, scans, macros', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);

    appRouter.go('/dashboard');
    await settle(tester, ms: 2500);

    final container =
        ProviderScope.containerOf(tester.element(find.byType(DashboardScreen)));
    final subs = container.read(subscriptionProvider.notifier);
    await subs.refreshFromServer();
    await settle(tester, ms: 1500);
    final uid = SupabaseService.currentUser?.id;
    debugPrint('LIVE|uid=$uid');
    await shot('mig_01_scans_3_of_3');

    // ── 1. water ──────────────────────────────────────────────────────
    final plus = find.text('+250');
    if (plus.evaluate().isEmpty) {
      debugPrint('LIVE|water control NOT FOUND');
    } else {
      await tester.tap(plus.first);
      await settle(tester, ms: 3500);
      await shot('mig_02_water_after_250');
      try {
        final rows = await SupabaseService.client
            .from('water_logs')
            .select()
            .order('logged_at');
        debugPrint('LIVE|water_logs rows=${(rows as List).length}');
        for (final r in rows) {
          debugPrint('LIVE|water_row $r');
        }
      } catch (e) {
        debugPrint('LIVE|water_logs read failed: $e');
      }
    }

    // ── 2. scan allowance, through the app's own session ──────────────
    for (var i = 1; i <= 4; i++) {
      try {
        final res = await SupabaseService.client.functions.invoke(
          'recognize-food',
          body: {'imageBase64': _tinyJpegB64, 'mediaType': 'image/jpeg'},
        );
        final d = res.data;
        final scan = (d is Map) ? d['_scan'] : null;
        final conf = (d is Map) ? d['confidence'] : null;
        debugPrint('LIVE|scan$i status=${res.status} conf=$conf _scan=$scan');
        if (scan is Map && scan['used'] is num) {
          subs.applyServerCounts(used: (scan['used'] as num).toInt());
        }
      } catch (e) {
        debugPrint('LIVE|scan$i threw ${e.runtimeType}: $e');
        await subs.refreshFromServer();
      }
      await settle(tester, ms: 1500);
      await shot('mig_03_after_scan_$i');
    }

    try {
      final rows = await SupabaseService.client
          .from('scan_events')
          .select()
          .order('created_at');
      debugPrint('LIVE|scan_events rows=${(rows as List).length}');
      for (final r in rows) {
        debugPrint('LIVE|scan_row $r');
      }
    } catch (e) {
      debugPrint('LIVE|scan_events read failed: $e');
    }

    // ── 3. macro backfill ─────────────────────────────────────────────
    appRouter.go('/meals');
    await settle(tester, ms: 2500);
    final ctx = tester.element(find.byType(MealsScreen));
    showManualEntrySheet(ctx, initialMealType: MealType.dinner);
    await settle(tester, ms: 1400);
    final sheet = find.byType(ManualEntrySheet);
    final f = find.descendant(of: sheet, matching: find.byType(TextField));
    await tester.enterText(f.at(0), 'Lagman');
    await settle(tester, ms: 300);
    await tester.enterText(f.at(1), '520');
    await settle(tester, ms: 300);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, ms: 400);
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
    );
    await settle(tester, ms: 20000);
    await shot('mig_04_diary_macros');

    final meals = await SupabaseService.getTodayFoodLogs();
    debugPrint('LIVE|meals rows=${meals.length}');
    for (final r in meals) {
      final p = (r['protein'] as num?)?.toDouble() ?? 0;
      final fat = (r['fat'] as num?)?.toDouble() ?? 0;
      final c = (r['carbs'] as num?)?.toDouble() ?? 0;
      debugPrint('LIVE|meal_row name=${r['name']} kcal=${r['kcal']} '
          'protein=$p fat=$fat carbs=$c sums=${p * 4 + fat * 9 + c * 4}');
    }
  });
}
