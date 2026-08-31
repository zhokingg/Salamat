// Captures the screens changed by the fix pass, in English and Russian.
//
// Diagnostic/evidence only — it asserts nothing about product behaviour beyond
// reaching each state. Run through scripts/capture_store.sh's harness with
// SALAMAT_SHOT_DIR=docs/test-screens.

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
import 'package:salamat/screens/onboarding/widgets.dart';

const int _shotPort = 8787;

Future<void> settle(WidgetTester t, {int ms = 1500}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final r =
        await c.getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    final res = await r.close();
    await res.drain<void>();
  } catch (_) {
  } finally {
    c.close(force: true);
  }
}

Future<void> cta(WidgetTester t, {int ms = 1200}) async {
  await t.tap(find.byType(OnboardingPrimaryButton));
  await settle(t, ms: ms);
}

Future<void> pick(WidgetTester t, int i) async {
  await t.tap(find.byType(OnboardingSelectCard).at(i));
  await settle(t, ms: 400);
  await cta(t);
}

Future<void> goTo(WidgetTester t, String r, {int ms = 1800}) async {
  appRouter.go(r);
  await settle(t, ms: ms);
}

Future<void> pushTo(WidgetTester t, String r, {int ms = 1800}) async {
  appRouter.push(r);
  await settle(t, ms: ms);
}

Future<void> logMeal(
  WidgetTester t,
  String name,
  String kcal,
  MealType type, {
  List<String>? macros,
}) async {
  final ctx = t.element(find.byType(MealsScreen));
  showManualEntrySheet(ctx, initialMealType: type);
  await settle(t, ms: 1400);
  final sheet = find.byType(ManualEntrySheet);
  var f = find.descendant(of: sheet, matching: find.byType(TextField));
  await t.enterText(f.at(0), name);
  await settle(t, ms: 250);
  await t.enterText(f.at(1), kcal);
  await settle(t, ms: 250);
  if (macros != null) {
    final det = find.descendant(
      of: sheet,
      matching: find.byWidgetPredicate(
        (w) => w is Text && (w.data ?? '').isNotEmpty,
      ),
    );
    // The details row is the only tappable text that reveals more fields.
    for (var i = 0; i < det.evaluate().length; i++) {
      final before =
          find.descendant(of: sheet, matching: find.byType(TextField));
      if (before.evaluate().length >= 5) break;
      try {
        await t.tap(det.at(i), warnIfMissed: false);
        await settle(t, ms: 500);
      } catch (_) {}
    }
    f = find.descendant(of: sheet, matching: find.byType(TextField));
    if (f.evaluate().length >= 5) {
      for (var i = 0; i < 3; i++) {
        await t.enterText(f.at(2 + i), macros[i]);
        await settle(t, ms: 200);
      }
    }
  }
  FocusManager.instance.primaryFocus?.unfocus();
  await settle(t, ms: 500);
  await t.tap(find.descendant(of: sheet, matching: find.byType(ElevatedButton)));
  await settle(t, ms: 2200);
}

/// Drags the target wheel up so the target rises above the current weight,
/// which is what the new goal/target rule refuses.
Future<void> raiseTarget(WidgetTester t) async {
  final wheel = find.byType(OnboardingWheelPicker);
  // itemExtent is 58; +7 steps takes 65 -> 72, above the 70 kg current weight.
  await t.drag(wheel.first, const Offset(0, -58.0 * 7));
  await settle(t, ms: 1200);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture changed screens in both languages',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
    });
    app.main();
    await settle(tester, ms: 9000);

    // welcome -> name -> goal(lose) -> gender -> year -> weight -> target
    await cta(tester);
    await tester.enterText(find.byType(TextField).first, 'Aizhan');
    await settle(tester, ms: 400);
    await cta(tester);
    await pick(tester, 0); // lose
    await pick(tester, 0); // female
    await cta(tester); // year
    await cta(tester); // weight (165 cm / 70 kg)

    // ── target conflict, English ──
    await raiseTarget(tester);
    await shot('fixed_target_conflict_en');

    // back to a coherent target and on through the funnel
    await tester.drag(
      find.byType(OnboardingWheelPicker).first,
      const Offset(0, 58.0 * 7),
    );
    await settle(tester, ms: 1200);
    await cta(tester); // target
    await cta(tester); // celebration
    await cta(tester); // long term
    await pick(tester, 0); // familiarity
    await pick(tester, 0); // activity
    await cta(tester); // summary
    await cta(tester); // yes lose
    await cta(tester); // yes order
    await cta(tester); // yes health
    await cta(tester); // comparison
    await cta(tester); // social proof
    await settle(tester, ms: 6000); // building
    await cta(tester, ms: 2500); // plan -> dashboard

    // ── data: one entry without macros, one with ──
    await goTo(tester, '/meals');
    await logMeal(tester, 'Beef plov', '640', MealType.lunch);
    await logMeal(
      tester,
      'Macro check',
      '400',
      MealType.breakfast,
      macros: const ['40', '10', '50'],
    );
    await settle(tester, ms: 5000); // let the add-snackbar expire

    // ── English ──
    await goTo(tester, '/dashboard');
    await shot('fixed_home_en');
    await goTo(tester, '/meals');
    await shot('fixed_diary_en');
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/paywall', ms: 3000);
    await shot('fixed_paywall_en');

    // ── switch to Russian in Settings ──
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/settings');
    final ru = find.text('Русский');
    if (ru.evaluate().isNotEmpty) {
      await tester.tap(ru.first);
      await settle(tester, ms: 2000);
    }

    // ── Russian ──
    await goTo(tester, '/dashboard');
    await shot('fixed_home_ru');
    await goTo(tester, '/meals');
    await shot('fixed_diary_ru');
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/paywall', ms: 3000);
    await shot('fixed_paywall_ru');

    // ── target conflict, Russian ──
    // The funnel answers are already stored, so the real step re-renders.
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/onboarding/target', ms: 2500);
    await raiseTarget(tester);
    await shot('fixed_target_conflict_ru');
  });
}
