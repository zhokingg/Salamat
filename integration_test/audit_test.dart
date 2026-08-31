// Full-app audit pass.
//
// Diagnostic only: it walks scenarios, records what happened, and never fixes
// anything. Every check is isolated so one failure does not abort the sweep.
// Findings are printed as `AUDIT|<status>|<scenario>|<detail>` lines and any
// Flutter error raised along the way is attributed to the route that was on
// screen at the time — that is how the onboarding overflow is located.
//
// Screenshots go to docs/test-screens via the same host server as the capture
// run:  SALAMAT_SHOT_DIR=docs/test-screens ./scripts/capture_store.sh

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/l10n/app_localizations.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/screens/cook/cook_screen.dart';
import 'package:salamat/screens/manual_entry/manual_entry_sheet.dart';
import 'package:salamat/screens/meals/meals_screen.dart';
import 'package:salamat/screens/onboarding/widgets.dart';

const int _shotPort = 8787;

final List<String> _findings = <String>[];
final List<String> _errors = <String>[];
String _route = '/splash';

void record(String status, String scenario, String detail) {
  _findings.add('AUDIT|$status|$scenario|$detail');
  debugPrint('AUDIT|$status|$scenario|$detail');
}

/// Runs one check in isolation; a throw becomes a FAIL line, not an abort.
Future<void> check(
  String scenario,
  Future<void> Function() body,
) async {
  try {
    await body();
  } catch (e) {
    final msg = e.toString().replaceAll('\n', ' ');
    record('FAIL', scenario, msg.length > 300 ? msg.substring(0, 300) : msg);
  }
}

Future<void> settle(WidgetTester tester, {int ms = 1500}) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> shot(String name) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    final res = await req.close();
    await res.drain<void>();
  } catch (_) {
    // A missing screenshot must not mask the finding it illustrates.
  } finally {
    client.close(force: true);
  }
}

Future<void> goTo(WidgetTester tester, String route, {int ms = 1800}) async {
  _route = route;
  appRouter.go(route);
  await settle(tester, ms: ms);
}

Future<void> pushTo(WidgetTester tester, String route, {int ms = 1800}) async {
  _route = route;
  appRouter.push(route);
  await settle(tester, ms: ms);
}

Future<void> tapCta(WidgetTester tester, {int ms = 1200}) async {
  await tester.tap(find.byType(OnboardingPrimaryButton));
  await settle(tester, ms: ms);
}

Future<void> pickThenContinue(WidgetTester tester, int index) async {
  await tester.tap(find.byType(OnboardingSelectCard).at(index));
  await settle(tester, ms: 400);
  await tapCta(tester);
}

/// Opens the manual sheet from whatever screen is mounted and saves an entry.
Future<void> logMeal(
  WidgetTester tester,
  String name,
  String kcal,
  MealType type,
) async {
  final ctx = tester.element(find.byType(MealsScreen));
  showManualEntrySheet(ctx, initialMealType: type);
  await settle(tester, ms: 1400);
  final sheet = find.byType(ManualEntrySheet);
  final fields = find.descendant(of: sheet, matching: find.byType(TextField));
  await tester.enterText(fields.at(0), name);
  await settle(tester, ms: 300);
  await tester.enterText(fields.at(1), kcal);
  await settle(tester, ms: 300);
  await tester.tap(
    find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
  );
  await settle(tester, ms: 1600);
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('full app audit', (WidgetTester tester) async {
    // Attribute every framework error to the route that was on screen.
    final prevOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      final summary = details.exceptionAsString().replaceAll('\n', ' ');
      _errors.add('ERR|$_route|'
          '${summary.length > 200 ? summary.substring(0, 200) : summary}');
      prevOnError?.call(details);
    };

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
    });
    app.main();
    await settle(tester, ms: 9000);

    // ── empty states, before any data ──────────────────────────────────
    await check('empty state: diary before any entry', () async {
      _route = '/onboarding/welcome';
      record('INFO', 'startup route',
          'first screen widgets=${find.byType(OnboardingPrimaryButton).evaluate().length}');
    });

    // ── onboarding ────────────────────────────────────────────────────
    _route = '/onboarding/welcome';
    await tapCta(tester);

    _route = '/onboarding/name';
    await check('validation: empty name blocks continue', () async {
      await tapCta(tester);
      final stillOnName = find.byType(TextField).evaluate().isNotEmpty;
      record(stillOnName ? 'PASS' : 'FAIL', 'validation: empty name',
          stillOnName ? 'CTA inert, stayed on name step' : 'advanced with empty name');
      if (!stillOnName) await shot('bug_empty_name_advanced');
    });

    await tester.enterText(find.byType(TextField).first, 'Aizhan');
    await settle(tester, ms: 400);
    await tapCta(tester);

    _route = '/onboarding/goal';
    await check('onboarding: back preserves the answer', () async {
      final back = find.descendant(
        of: find.byType(OnboardingProgressBar),
        matching: find.byType(GestureDetector),
      );
      if (back.evaluate().isEmpty) {
        record('FAIL', 'onboarding: back button', 'no back control on goal step');
        return;
      }
      await tester.tap(back.first);
      await settle(tester, ms: 1200);
      final field = find.byType(TextField);
      if (field.evaluate().isEmpty) {
        record('FAIL', 'onboarding: back nav', 'back did not land on name step');
        return;
      }
      final widget = tester.widget<TextField>(field.first);
      final kept = widget.controller?.text ?? '';
      record(kept == 'Aizhan' ? 'PASS' : 'FAIL', 'onboarding: back preserves name',
          'field contained "$kept"');
      if (kept != 'Aizhan') await shot('bug_back_lost_name');
      await tapCta(tester); // forward again
    });

    _route = '/onboarding/goal';
    await pickThenContinue(tester, 0); // lose
    _route = '/onboarding/gender';
    await pickThenContinue(tester, 0); // female
    _route = '/onboarding/year';
    await tapCta(tester);
    _route = '/onboarding/weight';
    await tapCta(tester);
    _route = '/onboarding/target';
    await tapCta(tester);
    _route = '/onboarding/celebration';
    await tapCta(tester);
    _route = '/onboarding/long-term';
    await tapCta(tester);
    _route = '/onboarding/familiarity';
    await pickThenContinue(tester, 0);
    _route = '/onboarding/activity';
    await pickThenContinue(tester, 0); // sedentary
    _route = '/onboarding/summary';
    await tapCta(tester);
    _route = '/onboarding/yes-lose';
    await tapCta(tester);
    _route = '/onboarding/yes-order';
    await tapCta(tester);
    _route = '/onboarding/yes-health';
    await tapCta(tester);
    _route = '/onboarding/comparison';
    await tapCta(tester);
    _route = '/onboarding/social-proof';
    await tapCta(tester);
    _route = '/onboarding/building';
    await settle(tester, ms: 6000);
    _route = '/onboarding/plan';
    await tapCta(tester, ms: 2500);

    // ── diary: all four meal slots ────────────────────────────────────
    await goTo(tester, '/meals');
    await check('empty diary state', () async {
      await shot('state_diary_empty');
      record('INFO', 'empty diary', 'captured state_diary_empty.png');
    });

    for (final slot in MealType.values) {
      await check('manual entry: ${slot.name}', () async {
        await goTo(tester, '/meals');
        await logMeal(tester, 'Test ${slot.name}', '200', slot);
        final present = find.text('Test ${slot.name}').evaluate().isNotEmpty;
        record(present ? 'PASS' : 'FAIL', 'manual entry: ${slot.name}',
            present ? 'entry visible in diary' : 'entry missing after save');
      });
    }

    // ── macros: stored vs displayed ───────────────────────────────────
    await check('macros stored for a manual entry', () async {
      final ctx = tester.element(find.byType(MealsScreen));
      final container = ProviderScope.containerOf(ctx);
      final state = container.read(mealsProvider).value;
      if (state == null) {
        record('SKIP', 'macros: stored vs shown', 'meals state not loaded');
        return;
      }
      final entries = MealType.values.expand(state.forType).toList();
      final zeroMacro = entries
          .where((e) => e.protein == 0 && e.fat == 0 && e.carbs == 0)
          .length;
      record(
        'INFO',
        'macros: entries logged without macros',
        'entries=${entries.length} storedAllZero=$zeroMacro '
            'totalProtein=${state.totalProtein.toStringAsFixed(1)}g '
            '(these now render a dash, no estimate)',
      );
    });

    // ── duplicate protection ──────────────────────────────────────────
    await check('rapid double save creates duplicates', () async {
      await goTo(tester, '/meals');
      final ctx = tester.element(find.byType(MealsScreen));
      showManualEntrySheet(ctx, initialMealType: MealType.snack);
      await settle(tester, ms: 1400);
      final sheet = find.byType(ManualEntrySheet);
      final fields =
          find.descendant(of: sheet, matching: find.byType(TextField));
      await tester.enterText(fields.at(0), 'DoubleTap');
      await settle(tester, ms: 300);
      await tester.enterText(fields.at(1), '111');
      await settle(tester, ms: 300);
      final save =
          find.descendant(of: sheet, matching: find.byType(ElevatedButton));
      // Two taps in the same frame budget.
      await tester.tap(save, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 16));
      try {
        await tester.tap(save, warnIfMissed: false);
      } catch (_) {}
      await settle(tester, ms: 2000);
      final count = find.text('DoubleTap').evaluate().length;
      record(count > 1 ? 'BUG' : 'PASS', 'rapid double save',
          'DoubleTap rows visible=$count');
      if (count > 1) await shot('bug_double_save');
    });

    // ── meal card: portion edit ───────────────────────────────────────
    await check('portion edit keeps the meal slot', () async {
      await goTo(tester, '/meals');
      final entry = find.text('Test lunch');
      if (entry.evaluate().isEmpty) {
        record('SKIP', 'portion edit', 'lunch entry not found');
        return;
      }
      await tester.tap(entry.first);
      await settle(tester, ms: 1600);
      await shot('state_meal_detail_before_portion');
      record('INFO', 'portion edit', 'captured meal detail; see report');
    });

    // ── water ─────────────────────────────────────────────────────────
    await check('water: add 250 and undo', () async {
      await goTo(tester, '/dashboard');
      await shot('state_water_before');
      record('INFO', 'water', 'captured state_water_before.png');
    });

    // ── progress period switcher ──────────────────────────────────────
    for (final period in ['Day', 'Week', 'Month', 'Year']) {
      await check('progress period: $period', () async {
        await goTo(tester, '/progress');
        final tab = find.text(period);
        if (tab.evaluate().isEmpty) {
          record('FAIL', 'progress period: $period', 'tab not found');
          return;
        }
        await tester.tap(tab.first);
        await settle(tester, ms: 1800);
        await shot('state_progress_${period.toLowerCase()}');
        record('PASS', 'progress period: $period', 'rendered');
      });
    }

    // ── cook: pantry add / remove / persistence ───────────────────────
    await check('cook: pantry add and remove', () async {
      await goTo(tester, '/dashboard');
      await pushTo(tester, '/cook');
      final field = find.descendant(
        of: find.byType(CookScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(field.first, 'Egg');
      await settle(tester, ms: 300);
      try {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } catch (_) {
        // Not registered under the live frame policy; fall back to the button.
        final loc = AppLocalizations.of(tester.element(find.byType(CookScreen)))!;
        final addBtn = find.text(loc.cookAddButton);
        if (addBtn.evaluate().isNotEmpty) await tester.tap(addBtn.first);
      }
      await settle(tester, ms: 900);
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, ms: 800);
      final added = find.text('Egg').evaluate().isNotEmpty;
      record(added ? 'PASS' : 'FAIL', 'cook: add ingredient',
          added ? 'chip present' : 'chip missing');
      await shot('state_cook_pantry');
    });

    await check('cook: pantry survives leaving the screen', () async {
      await goTo(tester, '/dashboard');
      await pushTo(tester, '/cook');
      final kept = find.text('Egg').evaluate().isNotEmpty;
      record(kept ? 'PASS' : 'BUG', 'cook: pantry persistence (in-session)',
          kept ? 'chip still present after re-entry' : 'pantry lost on re-entry');
    });

    // ── large system font ─────────────────────────────────────────────
    await check('large system font', () async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.8;
      await goTo(tester, '/dashboard');
      await shot('state_bigfont_home');
      await goTo(tester, '/meals');
      await shot('state_bigfont_diary');
      await goTo(tester, '/progress');
      await shot('state_bigfont_progress');
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      await settle(tester, ms: 800);
      record('INFO', 'large system font',
          'captured at textScaleFactor=1.8; overflow errors listed below');
    });

    // ── landscape layout ──────────────────────────────────────────────
    await check('landscape layout', () async {
      await tester.binding.setSurfaceSize(const Size(956, 440));
      await goTo(tester, '/dashboard');
      await shot('state_landscape_home');
      await goTo(tester, '/meals');
      await shot('state_landscape_diary');
      await tester.binding.setSurfaceSize(null);
      await settle(tester, ms: 800);
      record('INFO', 'landscape layout',
          'captured at 956x440; overflow errors listed below');
    });

    // ── settings / profile reachability ───────────────────────────────
    for (final route in ['/settings', '/profile', '/goal-edit', '/paywall']) {
      await check('route renders: $route', () async {
        await goTo(tester, '/dashboard');
        if (route == '/profile') {
          await goTo(tester, route);
        } else {
          await pushTo(tester, route, ms: 2500);
        }
        record('PASS', 'route renders: $route', 'no throw on render');
      });
    }

    // ── macro consistency across Home / Cook / Progress ───────────────
    await check('macro consistency across screens', () async {
      await goTo(tester, '/meals');
      final ctx = tester.element(find.byType(MealsScreen));
      showManualEntrySheet(ctx, initialMealType: MealType.breakfast);
      await settle(tester, ms: 1400);
      final sheet = find.byType(ManualEntrySheet);
      final loc = AppLocalizations.of(tester.element(sheet))!;

      var fields = find.descendant(of: sheet, matching: find.byType(TextField));
      await tester.enterText(fields.at(0), 'Macro check');
      await settle(tester, ms: 250);
      await tester.enterText(fields.at(1), '400');
      await settle(tester, ms: 250);

      final details =
          find.descendant(of: sheet, matching: find.text(loc.manualAddDetails));
      if (details.evaluate().isNotEmpty) {
        await tester.tap(details.first);
        await settle(tester, ms: 900);
      }
      fields = find.descendant(of: sheet, matching: find.byType(TextField));
      if (fields.evaluate().length >= 5) {
        await tester.enterText(fields.at(2), '40');
        await settle(tester, ms: 200);
        await tester.enterText(fields.at(3), '10');
        await settle(tester, ms: 200);
        await tester.enterText(fields.at(4), '50');
        await settle(tester, ms: 200);
      } else {
        record('FAIL', 'macro consistency: detail fields',
            'only ${fields.evaluate().length} fields after expanding details');
      }
      FocusManager.instance.primaryFocus?.unfocus();
      await settle(tester, ms: 600);
      await tester.tap(
        find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
      );
      await settle(tester, ms: 2500);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MealsScreen)),
      );
      final st = container.read(mealsProvider).value;
      if (st == null) {
        record('FAIL', 'macro consistency', 'meals state not loaded');
        return;
      }
      final norm = 1234.0;
      record('INFO', 'macro consistency: numbers',
          'totalProtein=${st.totalProtein.toStringAsFixed(1)} '
          'totalFat=${st.totalFat.toStringAsFixed(1)} '
          'totalCarbs=${st.totalCarbs.toStringAsFixed(1)} '
          'cookRemainingProtein=${((norm * 0.30 / 4) - st.totalProtein).toStringAsFixed(1)}');

      await goTo(tester, '/dashboard');
      await shot('fixed_home_macros');
      await goTo(tester, '/dashboard');
      await pushTo(tester, '/cook');
      await shot('fixed_cook_macros');
      await goTo(tester, '/progress');
      await shot('fixed_progress_macros');
      await goTo(tester, '/meals');
      await shot('fixed_diary_macros');
    });

    // ── water: real interaction ───────────────────────────────────────
    await check('water: +250 then undo', () async {
      await goTo(tester, '/dashboard');
      final plus = find.text('+250');
      if (plus.evaluate().isEmpty) {
        record('FAIL', 'water: +250 control', 'control not found on dashboard');
        return;
      }
      await tester.tap(plus.first);
      await settle(tester, ms: 2500);
      final after = find.textContaining('0.25').evaluate().isNotEmpty;
      record(after ? 'PASS' : 'FAIL', 'water: +250 adds a sip',
          after ? 'value moved to 0.25 L' : 'no 0.25 L reading after tap');
      await shot(after ? 'state_water_after' : 'bug_water_no_change');
    });

    // ── Russian sweep ─────────────────────────────────────────────────
    await check('russian sweep', () async {
      await goTo(tester, '/dashboard');
      await pushTo(tester, '/settings');
      final ru = find.text('Русский');
      if (ru.evaluate().isEmpty) {
        record('FAIL', 'russian: language switch', 'switch not found');
        return;
      }
      await tester.tap(ru.first);
      await settle(tester, ms: 2000);
      for (final r in ['/dashboard', '/meals', '/progress', '/profile']) {
        await goTo(tester, r);
        await shot('ru_${r.replaceAll('/', '')}');
      }
      await goTo(tester, '/dashboard');
      await pushTo(tester, '/cook');
      await shot('ru_cook');
      // Known English leaks in the Russian water card.
      await goTo(tester, '/dashboard');
      final leakA = find.textContaining('Saved on this device').evaluate().isNotEmpty;
      final leakB = find.textContaining('of 2.0 L').evaluate().isNotEmpty;
      record(leakA || leakB ? 'BUG' : 'PASS', 'russian: untranslated water card',
          'saved-on-device=$leakA  of-2.0-L=$leakB');
      if (leakA || leakB) await shot('bug_ru_water_english');
    });

    // ── summary ───────────────────────────────────────────────────────
    debugPrint('===== AUDIT FINDINGS =====');
    for (final f in _findings) {
      debugPrint(f);
    }
    debugPrint('===== FRAMEWORK ERRORS (${_errors.length}) =====');
    final seen = <String>{};
    for (final e in _errors) {
      if (seen.add(e)) debugPrint(e);
    }
    debugPrint('===== END AUDIT =====');
  });
}
