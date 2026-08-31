// Full Russian walkthrough after the translation pass.
//
// Captures every translated screen and records any layout error against the
// route that was on screen, so truncation/overflow is attributable. Asserts
// nothing about product behaviour — this is evidence collection.

import 'dart:io';

import 'package:flutter/material.dart';
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
final List<String> _errors = <String>[];
String _route = '/splash';

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

Future<void> step(WidgetTester t, String name, {int ms = 1200}) async {
  _route = name;
  await shot('ru2_$name');
  await t.tap(find.byType(OnboardingPrimaryButton));
  await settle(t, ms: ms);
}

Future<void> pickStep(WidgetTester t, String name, int i) async {
  _route = name;
  await t.tap(find.byType(OnboardingSelectCard).at(i));
  await settle(t, ms: 400);
  await shot('ru2_$name');
  await t.tap(find.byType(OnboardingPrimaryButton));
  await settle(t, ms: 1200);
}

Future<void> goTo(WidgetTester t, String r, {int ms = 1800}) async {
  _route = r;
  appRouter.go(r);
  await settle(t, ms: ms);
}

Future<void> pushTo(WidgetTester t, String r, {int ms = 1800}) async {
  _route = r;
  appRouter.push(r);
  await settle(t, ms: ms);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('russian walkthrough', (WidgetTester tester) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exceptionAsString().replaceAll('\n', ' ');
      _errors.add('ERR|$_route|${s.length > 160 ? s.substring(0, 160) : s}');
      prev?.call(d);
    };

    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ru',
    });
    app.main();
    await settle(tester, ms: 9000);

    // ── onboarding, all translated steps ──
    await step(tester, '01_welcome');
    _route = '02_name';
    await tester.enterText(find.byType(TextField).first, 'Айжан');
    await settle(tester, ms: 500);
    await step(tester, '02_name');
    await pickStep(tester, '03_goal', 0);
    await pickStep(tester, '04_gender', 0);
    await step(tester, '05_year');
    await step(tester, '06_weight');
    await step(tester, '07_target');
    await step(tester, '08_celebration');
    await step(tester, '09_longterm');
    await pickStep(tester, '10_familiarity', 0);
    await pickStep(tester, '11_activity', 0);
    await step(tester, '12_summary');
    await step(tester, '13_yes_lose');
    await step(tester, '14_yes_order');
    await step(tester, '15_yes_health');
    await step(tester, '16_comparison');
    await step(tester, '17_social');
    _route = '18_building';
    await settle(tester, ms: 6000);
    await shot('ru2_19_plan');
    await tester.tap(find.byType(OnboardingPrimaryButton));
    await settle(tester, ms: 2500);

    // ── data ──
    await goTo(tester, '/meals');
    await shot('ru2_20_diary_empty');
    final ctx = tester.element(find.byType(MealsScreen));
    showManualEntrySheet(ctx, initialMealType: MealType.lunch);
    await settle(tester, ms: 1400);
    final sheet = find.byType(ManualEntrySheet);
    final f = find.descendant(of: sheet, matching: find.byType(TextField));
    await tester.enterText(f.at(0), 'Плов');
    await settle(tester, ms: 250);
    await tester.enterText(f.at(1), '640');
    await settle(tester, ms: 250);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, ms: 400);
    await shot('ru2_21_manual_entry');
    await tester.tap(
      find.descendant(of: sheet, matching: find.byType(ElevatedButton)),
    );
    await settle(tester, ms: 5500); // let the snackbar expire

    // ── main screens ──
    await goTo(tester, '/dashboard');
    await shot('ru2_22_home');
    await goTo(tester, '/meals');
    await shot('ru2_23_diary');

    // meal card
    final entry = find.text('Плов');
    if (entry.evaluate().isNotEmpty) {
      await tester.tap(entry.first);
      await settle(tester, ms: 1600);
      await shot('ru2_24_meal_detail');
    }

    // ── progress: every period (tab strip is the tight one) ──
    for (final p in const [
      ('День', '25_progress_day'),
      ('Неделя', '26_progress_week'),
      ('Месяц', '27_progress_month'),
      ('Год', '28_progress_year'),
    ]) {
      await goTo(tester, '/progress');
      final tab = find.text(p.$1);
      if (tab.evaluate().isNotEmpty) {
        await tester.tap(tab.first);
        await settle(tester, ms: 1600);
      }
      await shot('ru2_${p.$2}');
    }

    // ── cook: empty, then chips (chips are the other tight spot) ──
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/cook');
    await shot('ru2_29_cook_empty');
    final loc = AppLocalizations.of(tester.element(find.byType(CookScreen)))!;
    for (final item in const ['Курица', 'Рис', 'Помидоры', 'Морковь']) {
      final field = find.descendant(
        of: find.byType(CookScreen),
        matching: find.byType(TextField),
      );
      await tester.enterText(field.first, item);
      await settle(tester, ms: 300);
      try {
        await tester.testTextInput.receiveAction(TextInputAction.done);
      } catch (_) {
        final add = find.text(loc.cookAddButton);
        if (add.evaluate().isNotEmpty) {
          await tester.tap(add.first, warnIfMissed: false);
        }
      }
      await settle(tester, ms: 700);
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester, ms: 1000);
    await shot('ru2_30_cook_chips');

    // ── paywall / settings / profile ──
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/paywall', ms: 3000);
    await shot('ru2_31_paywall');
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/settings');
    await shot('ru2_32_settings');
    await goTo(tester, '/profile');
    await shot('ru2_33_profile');
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/goal-edit');
    await shot('ru2_34_goal_edit');

    debugPrint('===== RU WALKTHROUGH ERRORS (${_errors.length}) =====');
    for (final e in {..._errors}) {
      debugPrint(e);
    }
    debugPrint('===== END =====');
  });
}
