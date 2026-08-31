// Live check of the barcode path, as far as a simulator allows.
//
// There is no camera, so the scanner cannot produce a detection. What is
// exercised here is everything on either side of it: the lookup through the
// Edge Function with real barcodes, the conversion into the value the
// confirmation sheet consumes, the save, and the row that lands in Supabase.
// The barcode viewfinder itself is captured in both languages.

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
import 'package:salamat/screens/dashboard/dashboard_screen.dart';
import 'package:salamat/services/barcode_lookup_service.dart';
import 'package:salamat/services/supabase_service.dart';

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
    testWidgets('barcode path ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);
      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);
      debugPrint('B|$lang uid=${SupabaseService.currentUser?.id}');

      // ── lookups, real codes ──
      const codes = <String, String>{
        '3017624010701': 'Nutella',
        '5449000000996': 'Coca-Cola',
        '4607025392477': 'RU product (expected miss)',
        '9999999999998': 'unknown code',
      };
      BarcodeProduct? saved;
      for (final e in codes.entries) {
        final sw = Stopwatch()..start();
        final r = await BarcodeLookupService.lookup(
          barcode: e.key,
          lang: lang,
        );
        sw.stop();
        if (r.isFound) {
          final p = r.product!;
          saved ??= p;
          debugPrint('B|$lang ${e.key} FOUND "${p.displayName}" '
              'kcal100=${p.kcalPer100} P=${p.proteinPer100} F=${p.fatPer100} '
              'C=${p.carbsPer100} serving=${p.servingG} (${sw.elapsedMilliseconds}ms)');
        } else {
          debugPrint('B|$lang ${e.key} MISS ${r.miss} (${sw.elapsedMilliseconds}ms)');
        }
      }

      // ── cache: the second lookup must not hit the network ──
      final sw2 = Stopwatch()..start();
      final again = await BarcodeLookupService.lookup(
        barcode: '3017624010701',
        lang: lang,
      );
      sw2.stop();
      debugPrint('B|$lang cached repeat found=${again.isFound} '
          '${sw2.elapsedMilliseconds}ms  '
          'isCached=${await BarcodeLookupService.isCached('3017624010701')}');

      // ── save exactly as the confirmation sheet does ──
      if (saved != null) {
        final grams = (saved.servingG ?? 100);
        final container = ProviderScope.containerOf(
            tester.element(find.byType(DashboardScreen)));
        await container.read(mealsProvider.notifier).add(
              MealType.snack,
              MealEntry(
                id: const Uuid().v4(),
                name: saved.displayName,
                grams: grams.toDouble(),
                kcal: (saved.kcalPer100 * grams / 100).round(),
                protein: saved.proteinPer100 * grams / 100,
                fat: saved.fatPer100 * grams / 100,
                carbs: saved.carbsPer100 * grams / 100,
                source: 'barcode',
              ),
            );
        await settle(tester, ms: 2500);
        final rows = await SupabaseService.getTodayFoodLogs();
        for (final r in rows) {
          debugPrint('B|$lang db_row name=${r['name']} kcal=${r['kcal']} '
              'protein=${r['protein']} fat=${r['fat']} carbs=${r['carbs']} '
              'grams=${r['grams']}');
        }
        appRouter.go('/meals');
        await settle(tester, ms: 2500);
        await shot('barcode_${lang}_03_diary');
      }

      // ── the barcode viewfinder ──
      appRouter.go('/dashboard');
      await settle(tester, ms: 1500);
      appRouter.push('/camera');
      await settle(tester, ms: 3000);
      await shot('barcode_${lang}_01_camera_photo_mode');
      final toggle = find.text(
        lang == 'ru' ? 'Штрихкод' : 'Barcode',
      );
      if (toggle.evaluate().isNotEmpty) {
        await tester.tap(toggle.first);
        await settle(tester, ms: 2500);
        await shot('barcode_${lang}_02_camera_barcode_mode');
        debugPrint('B|$lang toggled into barcode mode');
      } else {
        debugPrint('B|$lang toggle NOT FOUND');
      }
    });
  }
}
