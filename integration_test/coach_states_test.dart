// Coach screen states, in both languages.
//
// `coach` is deployed and migration 0008 is applied, so the gate answers for
// real. A fresh simulator account is anonymous and not Pro, which makes
// `notSubscribed` the state this file can reach on its own. The subscriber
// states need an account with `is_pro = true` — see coach_pro_test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';

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
    testWidgets('coach states ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // Home. The coach reaches the user through a card in this feed now,
      // not a tab — see coach_card_test.dart.
      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);
      await shot('coach_${lang}_01_home');

      // Entry from the profile screen.
      appRouter.go('/profile');
      await settle(tester, ms: 2000);
      await shot('coach_${lang}_02_profile_entry');

      // The screen itself.
      appRouter.go('/coach');
      await settle(tester, ms: 4000);
      await shot('coach_${lang}_03_notsubscribed');
    });
  }
}
