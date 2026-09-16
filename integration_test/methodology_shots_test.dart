// ignore_for_file: avoid_print
//
// The "How this is calculated" card, expanded, in the three places it lives,
// in both languages. For the App Store review reply (guideline 1.4.1).
//
//   SALAMAT_TEST=integration_test/methodology_shots_test.dart \
//   SALAMAT_SHOT_DIR=docs/review-shots ./scripts/capture_store.sh
//
// No account data is needed: the card explains formulas, and the numbers it
// sits under come straight from `userProvider`. Each language gets its own
// `testWidgets` with the locale fixed in prefs before the app starts, so the
// whole screen is in one language — never captured mid-switch.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/l10n/app_localizations.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/widgets/methodology_card.dart';

const int _shotPort = 8787;

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Fails the run if the shot server rejects the frame (wrong size, missing).
Future<void> shot(String name) async {
  final c = HttpClient();
  try {
    final req = await c
        .getUrl(Uri.parse('http://127.0.0.1:$_shotPort/shot?name=$name'));
    final res = await req.close();
    final body = await res.transform(const SystemEncoding().decoder).join();
    if (res.statusCode != 200) fail('screenshot $name rejected: $body');
  } on SocketException catch (e) {
    fail('screenshot $name: shot server unreachable ($e)');
  } finally {
    c.close(force: true);
  }
}

/// Opens the card and brings its whole expanded body into view.
Future<void> openCard(WidgetTester tester, AppLocalizations loc) async {
  final card = find.byType(MethodologyCard);
  expect(card, findsOneWidget, reason: 'the methodology card is not on screen');
  await tester.scrollUntilVisible(card, 200,
      scrollable: find.byType(Scrollable).first, maxScrolls: 30);
  await settle(tester, ms: 600);
  // Collapsed header shows the standards; the tap opens the text + sources.
  expect(find.text(loc.methodTitle), findsOneWidget);
  await tester.tap(find.text(loc.methodTitle), warnIfMissed: false);
  await settle(tester, ms: 900);
  // The closing line is the last thing in the card — scrolling to it puts the
  // sources, which sit just above, on screen too.
  final tail = find.text(loc.methodNotAdvice);
  expect(tail, findsOneWidget, reason: 'the card did not expand');
  await tester.scrollUntilVisible(tail, 200,
      scrollable: find.byType(Scrollable).first, maxScrolls: 30);
  await settle(tester, ms: 800);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final lang in const ['ru', 'en']) {
    final ru = lang == 'ru';

    testWidgets('methodology card ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      // The same person as the store frames, so the numbers above the card
      // are the ones the reviewer will see elsewhere.
      container.read(userProvider.notifier)
        ..setName(name: ru ? 'Аида' : 'Aida', lastName: '')
        ..setGender(Gender.female)
        ..setGoal(Goal.lose)
        ..setAge(31)
        ..setBody(height: 168, weight: 77.1)
        ..setTargetWeight(70)
        ..setActivityLevel(ActivityLevel.light)
        ..setFamiliarity(Familiarity.intermediate)
        ..setCalorieNorm(2100);
      await settle(tester, ms: 800);

      final loc = AppLocalizations.of(
        tester.element(find.byType(Scaffold).first),
      )!;

      // 1. Plan ready — the calorie target, with the card under it.
      appRouter.go('/onboarding/plan');
      await settle(tester, ms: 3500);
      await openCard(tester, loc);
      await shot('method_${lang}_1_plan_kcal');

      // 2. Summary — the BMI scale, with the card under it.
      appRouter.go('/onboarding/summary');
      await settle(tester, ms: 3000);
      await openCard(tester, loc);
      await shot('method_${lang}_2_summary_bmi');

      // 3. Profile — both blocks, under "My data".
      appRouter.go('/profile');
      await settle(tester, ms: 3000);
      await openCard(tester, loc);
      await shot('method_${lang}_3_profile');

      // Every source row is a real link, not decorative text.
      final links = find.descendant(
        of: find.byType(MethodologyCard),
        matching: find.byType(InkWell),
      );
      print('[$lang] tappable rows in the profile card: '
          '${links.evaluate().length} (header + sources)');
      expect(links.evaluate().length, greaterThanOrEqualTo(10),
          reason: 'expected 9 source links plus the header');
    });
  }
}
