// Coach entry after moving it out of the tab bar.
//
// Three frames per language: Home with the card in the feed, the four-tab nav
// with the camera back in the middle, and where a free account lands when it
// taps the card — the existing paywall, not the chat and not an error.

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';

const int _shotPort = 8787;

/// Fixed-frame pumping. `pumpAndSettle` never returns on this app: the
/// dashboard has a shimmer skeleton and confetti that never stop animating.
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
    testWidgets('coach card ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);

      // Scroll the feed so the card and the nav strip are in one frame.
      final list = find.byType(ListView).first;
      await tester.drag(list, const Offset(0, -260));
      await settle(tester, ms: 1200);
      await shot('coachcard_${lang}_01_home');

      // The card must actually be on screen before it is tapped — a hit test
      // against an off-screen widget would pass silently. The titles are the
      // literal `coachCardTitle` values, checked against the ARB by eye rather
      // than read through AppLocalizations, which is not resolvable from the
      // MaterialApp element itself.
      final title = lang == 'ru' ? 'Спроси коуча' : 'Ask the coach';
      final card = find.text(title);
      expect(card, findsOneWidget);

      await tester.tap(card);
      await settle(tester, ms: 3500);
      await shot('coachcard_${lang}_02_paywall');
    });
  }
}
