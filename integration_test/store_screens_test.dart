// App Store capture run.
//
// Walks the whole funnel with real taps, logs two meals by hand so the diary
// and progress screens have data, then captures the store frames in English
// and again in Russian after switching the language in Settings.
//
// Screenshots are NOT taken through Flutter. `IntegrationTestWidgetsFlutterBinding
// .takeScreenshot` needs `convertFlutterSurfaceToImage`, which is Android-only,
// and the iOS path does not produce the device-native 1320x2868 that App Store
// Connect requires. Instead `shot()` calls a small host server over 127.0.0.1
// (the simulator shares the host network stack), which runs
// `xcrun simctl io <udid> screenshot`, verifies the pixel size, and only then
// answers — so the test blocks until the frame is on disk and correct.
//
// Run it with: ./scripts/capture_store.sh

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Meals are logged once, in English, and stay as-is for the Russian pass —
/// user-entered food names are data, not UI copy, so they are not translated.
const String _mealA = 'Beef plov';
const String _mealB = 'Greek salad';

/// Pumps a fixed number of frames instead of `pumpAndSettle`.
///
/// The app runs shimmer, confetti and flutter_animate loops that never settle,
/// so `pumpAndSettle` would time out on most screens.
Future<void> settle(WidgetTester tester, {int ms = 1500}) async {
  for (var elapsed = 0; elapsed < ms; elapsed += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Asks the host to capture and dimension-check one frame.
Future<void> shot(String name) async {
  final client = HttpClient();
  try {
    final req = await client
        .getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200) {
      fail('screenshot "$name" rejected by host: $body');
    }
  } on SocketException catch (e) {
    fail('shot server unreachable on 127.0.0.1:$_shotPort — '
        'start it via scripts/capture_store.sh ($e)');
  } finally {
    client.close(force: true);
  }
}

/// Taps the single onboarding CTA on screen.
Future<void> tapCta(WidgetTester tester, {int ms = 1200}) async {
  expect(find.byType(OnboardingPrimaryButton), findsOneWidget);
  await tester.tap(find.byType(OnboardingPrimaryButton));
  await settle(tester, ms: ms);
}

/// Picks an option card, then continues.
Future<void> pickThenContinue(WidgetTester tester, int index) async {
  final cards = find.byType(OnboardingSelectCard);
  expect(cards, findsWidgets);
  await tester.tap(cards.at(index));
  await settle(tester, ms: 500);
  await tapCta(tester);
}

/// Fills the manual-entry sheet and saves.
Future<void> logMeal(
  WidgetTester tester,
  String name,
  String kcal,
  MealType type,
) async {
  final ctx = tester.element(find.byType(MealsScreen));
  showManualEntrySheet(ctx, initialMealType: type);
  await settle(tester, ms: 1400);

  // Scope every finder to the sheet: MealsScreen keeps its own TextField and
  // ElevatedButton mounted behind the modal barrier.
  final sheet = find.byType(ManualEntrySheet);
  expect(sheet, findsOneWidget, reason: 'manual entry sheet did not open');

  final fields = find.descendant(of: sheet, matching: find.byType(TextField));
  expect(fields, findsWidgets);
  await tester.enterText(fields.at(0), name);
  await settle(tester, ms: 400);
  await tester.enterText(fields.at(1), kcal);
  await settle(tester, ms: 400);

  final save =
      find.descendant(of: sheet, matching: find.byType(ElevatedButton));
  expect(save, findsOneWidget);
  await tester.tap(save);
  await settle(tester, ms: 1800);
  expect(find.byType(ManualEntrySheet), findsNothing,
      reason: 'sheet stayed open after saving "$name"');
}

/// Navigates by route rather than by hunting the nav strip. Route names are
/// stable and language-independent; no coordinates are involved.
Future<void> goTo(WidgetTester tester, String route, {int ms = 1800}) async {
  appRouter.go(route);
  await settle(tester, ms: ms);
}

Future<void> pushTo(WidgetTester tester, String route, {int ms = 1800}) async {
  appRouter.push(route);
  await settle(tester, ms: ms);
}

/// The pantry persists across pushes, so it is only stocked on the first pass.
bool _pantryStocked = false;

/// Stocks the pantry through the real input so "What to cook" shows a working
/// screen rather than its empty state. Ingredients are ordinary user input,
/// not injected fixtures.
Future<void> fillPantryOnce(WidgetTester tester) async {
  if (_pantryStocked) return;
  for (final item in const ['Chicken', 'Rice', 'Tomato']) {
    final field = find.descendant(
      of: find.byType(CookScreen),
      matching: find.byType(TextField),
    );
    expect(field, findsWidgets, reason: 'pantry input not found');
    await tester.enterText(field.first, item);
    await settle(tester, ms: 300);
    // The field commits on submit.
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester, ms: 700);
  }
  // Submitting raises the software keyboard, which would cover half the frame.
  // `tester.testTextInput.hide()` is not usable here: under the real-device
  // integration binding the test input is not registered and it asserts.
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  await settle(tester, ms: 2000);
  _pantryStocked = true;
}

/// Requesting suggestions is deliberately OFF.
///
/// The suggestion backend does not answer in this environment — tapping the
/// button lands on "Couldn't pick a dish / The service didn't respond", which
/// is a worse store frame than the stocked screen. Flip this to true once the
/// service is reachable to capture real dish cards instead.
const bool kRequestSuggestions = false;

/// Asks for suggestions. The label is read from the live localizations so this
/// works in both languages; if the button is absent the screen is captured as-is.
Future<void> requestSuggestions(WidgetTester tester) async {
  if (!kRequestSuggestions) return;
  final loc = AppLocalizations.of(tester.element(find.byType(CookScreen)))!;
  final button = find.text(loc.cookSuggestButton);
  if (button.evaluate().isEmpty) return;
  await tester.tap(button.first);
  // Suggestions round-trip to a backend service.
  await settle(tester, ms: 12000);
}

/// Captures the seven post-onboarding frames for one language.
Future<void> captureMainScreens(WidgetTester tester, String lang) async {
  await goTo(tester, '/dashboard');
  await shot('${lang}_01_home');

  await goTo(tester, '/meals');
  await shot('${lang}_02_diary');

  await goTo(tester, '/progress');
  await shot('${lang}_03_progress');

  // Meal card: open the entry logged earlier by its name.
  await goTo(tester, '/meals');
  final entry = find.text(_mealA);
  expect(entry, findsWidgets, reason: 'logged meal "$_mealA" not in diary');
  await tester.tap(entry.first);
  await settle(tester, ms: 1600);
  await shot('${lang}_08_meal');

  await goTo(tester, '/dashboard');
  await pushTo(tester, '/cook');
  await fillPantryOnce(tester);
  await requestSuggestions(tester);
  await shot('${lang}_05_cook');

  await goTo(tester, '/dashboard');
  await pushTo(tester, '/paywall', ms: 3000);
  await shot('${lang}_06_paywall');

  await goTo(tester, '/dashboard');
  await pushTo(tester, '/settings');
  await shot('${lang}_07_settings');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture App Store frames in English and Russian',
      (WidgetTester tester) async {
    // Fresh install: no onboarding flag, English UI.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
    });

    app.main();
    // Splash awaits Supabase init + anonymous sign-in before routing.
    await settle(tester, ms: 9000);

    // ---- onboarding ----
    await tapCta(tester); // welcome

    await tester.enterText(find.byType(TextField).first, 'Aizhan');
    await settle(tester, ms: 500);
    await tapCta(tester); // name

    await pickThenContinue(tester, 0); // goal
    await pickThenContinue(tester, 0); // gender

    await tapCta(tester); // year   (wheel default)
    await tapCta(tester); // weight (wheel defaults)
    await tapCta(tester); // target weight
    await tapCta(tester); // celebration
    await tapCta(tester); // long term

    await pickThenContinue(tester, 0); // familiarity
    await pickThenContinue(tester, 0); // activity

    await tapCta(tester); // summary
    await tapCta(tester); // yes / lose
    await tapCta(tester); // yes / order
    await tapCta(tester); // yes / health
    await tapCta(tester); // comparison
    await tapCta(tester); // social proof

    // "Building your plan" advances itself after ~4.2s.
    await settle(tester, ms: 6000);

    await shot('en_04_plan');
    await tapCta(tester, ms: 2500); // plan -> dashboard

    // ---- data so the screens are not empty ----
    await goTo(tester, '/meals');
    await logMeal(tester, _mealA, '640', MealType.lunch);
    await logMeal(tester, _mealB, '320', MealType.dinner);

    // "Added to dinner" snackbar must expire before any frame is taken,
    // otherwise it lands in the store screenshot.
    await settle(tester, ms: 6000);
    expect(find.byType(SnackBar), findsNothing,
        reason: 'a snackbar was still visible when capturing started');

    // ---- English frames ----
    await captureMainScreens(tester, 'en');

    // ---- switch to Russian in Settings ----
    await goTo(tester, '/dashboard');
    await pushTo(tester, '/settings');
    final ru = find.text('Русский');
    expect(ru, findsOneWidget, reason: 'language switch not found in Settings');
    await tester.tap(ru);
    await settle(tester, ms: 1800);
    await shot('ru_07_settings');

    // Plan screen in Russian: the funnel answers are already stored, so the
    // real plan screen re-renders from them.
    await pushTo(tester, '/onboarding/plan', ms: 2500);
    await shot('ru_04_plan');

    // ---- Russian frames ----
    await captureMainScreens(tester, 'ru');
  });
}
