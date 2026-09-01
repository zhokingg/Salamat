// ignore_for_file: avoid_print
//
// What a link can put on screen, in both languages.
//
// The live runs prove the three good paths (signup, recovery, email_change)
// end to end through Safari. These are the three states that are awkward to
// provoke with a real mailbox: an unknown address, a spent link, and the
// confirmation message — pinned here so they cannot regress quietly.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';
import 'package:salamat/services/auth_link.dart';

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

  for (final lang in const ['ru', 'en']) {
    final ru = lang == 'ru';

    testWidgets('link states ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // 1. An address the router does not know. This is what used to render
      //    `Route not found: kg.salamat.app://login-callback/#access_token=…`.
      appRouter.go('/no-such-place');
      await settle(tester, ms: 2500);
      expect(
        find.text(ru ? 'Ссылка не открылась' : "That link didn't open"),
        findsOneWidget,
      );
      expect(find.textContaining('Route not found'), findsNothing);
      await shot('link_${lang}_1_unknown_route');

      // 2. A link that carries an error — expired, or already used. The URL is
      //    the real one GoTrue hands back for a spent recovery token.
      appRouter.go(
        'kg.salamat.app://login-callback?error=access_denied'
        '&error_code=otp_expired'
        '&error_description=Email+link+is+invalid+or+has+expired',
      );
      await settle(tester, ms: 3500);
      expect(
        find.text(ru
            ? 'Возможно, истёк срок или ею уже воспользовались. Запроси письмо заново и открой самое свежее.'
            : 'It may have expired, or it may already have been used. Ask for a new email and open the newest one.'),
        findsOneWidget,
      );
      await shot('link_${lang}_2_expired');

      // 3. The message an email_change link leaves behind.
      appRouter.go('/settings');
      await settle(tester, ms: 2000);
      authLinkNotice.value = const AuthLinkResult(
        AuthLinkKind.emailChange,
        email: 'salamat-ec-fed647@mailinator.com',
      );
      await settle(tester, ms: 2000);
      expect(
        find.textContaining(ru ? 'Почта подтверждена' : 'Email confirmed'),
        findsOneWidget,
      );
      await shot('link_${lang}_3_email_confirmed');
    });
  }
}
