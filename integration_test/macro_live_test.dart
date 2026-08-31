// Live end-to-end check of the manual-entry macro backfill.
//
// Logs a dish with the macro fields left empty, waits for the background
// lookup, then reads the row BACK OUT OF SUPABASE and prints what is actually
// stored. Proves the values came from the database, not from local state.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/manual_entry/manual_entry_sheet.dart';
import 'package:salamat/screens/meals/meals_screen.dart';
import 'package:salamat/services/macro_lookup_service.dart';
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

  testWidgets('manual entry backfills real macros into the database',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);

    appRouter.go('/meals');
    await settle(tester, ms: 2500);

    // Log a dish with the macro fields deliberately left empty.
    final ctx = tester.element(find.byType(MealsScreen));
    showManualEntrySheet(ctx, initialMealType: MealType.lunch);
    await settle(tester, ms: 1400);
    final sheet = find.byType(ManualEntrySheet);
    final f = find.descendant(of: sheet, matching: find.byType(TextField));
    await tester.enterText(f.at(0), 'Beef plov');
    await settle(tester, ms: 300);
    await tester.enterText(f.at(1), '640');
    await settle(tester, ms: 300);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, ms: 400);
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
    );

    // Straight after saving the entry has no macros yet — the save is not
    // blocked on the lookup.
    await settle(tester, ms: 1200);
    await shot('live_macros_01_just_saved');
    debugPrint('LIVE|saved, awaiting backfill');

    // Give the lookup + updateEntry round trip time to land.
    await settle(tester, ms: 20000);
    await shot('live_macros_02_after_backfill');

    // Isolate the service itself, so a silent failure in the backfill is
    // distinguishable from a failure in the lookup.
    debugPrint('LIVE|isReady=${SupabaseService.isReady} '
        'isSignedIn=${SupabaseService.isSignedIn}');
    try {
      final m = await MacroLookupService.lookup(
        dish: 'Direct probe plov',
        kcal: 640,
        lang: 'en',
      );
      debugPrint('LIVE|direct_lookup='
          '${m == null ? 'NULL' : '${m.protein}/${m.fat}/${m.carbs}'}');
    } catch (e) {
      debugPrint('LIVE|direct_lookup_threw=$e');
    }

    // Raw invoke, so the transport error is visible rather than swallowed.
    try {
      final res = await SupabaseService.client.functions.invoke(
        'suggest-meal',
        body: {
          'mode': 'macros',
          'dish': 'Raw probe plov',
          'kcal': 640,
          'lang': 'en',
        },
      );
      debugPrint('LIVE|raw_status=${res.status} raw_data=${res.data}');
    } catch (e, st) {
      debugPrint('LIVE|raw_threw=${e.runtimeType} $e');
      debugPrint('LIVE|raw_stack=${st.toString().split("\n").take(3).join(" | ")}');
    }

    // Read the row back out of Supabase — the database, not local state.
    final rows = await SupabaseService.getTodayFoodLogs();
    debugPrint('LIVE|rows=${rows.length}');
    for (final r in rows) {
      debugPrint('LIVE|db_row name=${r['food_name'] ?? r['name']} '
          'kcal=${r['kcal']} protein=${r['protein']} '
          'fat=${r['fat']} carbs=${r['carbs']}');
    }
  });
}
