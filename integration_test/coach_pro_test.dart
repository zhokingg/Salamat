// Coach states that need a subscriber, in both languages.
//
// A fresh simulator run signs in anonymously and is never Pro, so those states
// are unreachable by default. This test seeds the persisted Supabase session
// instead, under the key `supabase_flutter` restores from — the app then comes
// up signed in as an account that already has `is_pro = true`, and the gate
// answers for real. Nothing here fakes the gate.
//
//   flutter test integration_test/coach_pro_test.dart -d <udid> \
//     --dart-define=SALAMAT_SESSION="$(cat session.json)"
//
// SALAMAT_STATE selects which state to capture: `chat` sends one real message,
// `limit` expects the account's month to be spent already.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';

const int _shotPort = 8787;

/// Where supabase_flutter persists the session:
/// `sb-<project-host-first-label>-auth-token`.
const String _sessionKey = 'sb-cpqidxmqydleadbinaon-auth-token';

const String _session = String.fromEnvironment('SALAMAT_SESSION');
const String _state = String.fromEnvironment('SALAMAT_STATE', defaultValue: 'chat');

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
    testWidgets('coach $_state ($lang)', (WidgetTester tester) async {
      expect(_session.isNotEmpty, isTrue,
          reason: 'pass the session with --dart-define=SALAMAT_SESSION=...');

      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
        _sessionKey: _session,
      });
      app.main();
      await settle(tester, ms: 9000);

      appRouter.go('/coach');
      await settle(tester, ms: 4000);

      if (_state == 'chat') {
        // One real question, through the real gate. This spends a message.
        final field = find.byType(TextField);
        expect(field, findsOneWidget);
        await tester.enterText(
          field,
          lang == 'ru'
              ? 'Что приготовить на ужин, если осталось 600 ккал?'
              : 'What should I cook for dinner with 600 kcal left?',
        );
        await settle(tester, ms: 600);
        await shot('coachpro_${lang}_01_empty');

        await tester.testTextInput.receiveAction(TextInputAction.send);
        // The model answers in 3-6 s; wait past that rather than racing it.
        await settle(tester, ms: 22000);
        // Drop the keyboard so it does not cover the reply. `testTextInput`
        // deregisters once the field loses focus, so unfocus rather than
        // calling hide(), which asserts when nothing is registered.
        tester.binding.focusManager.primaryFocus?.unfocus();
        await settle(tester, ms: 1500);
        await shot('coachpro_${lang}_02_reply');
      } else {
        await shot('coachpro_${lang}_03_limit');
      }
    });
  }
}
