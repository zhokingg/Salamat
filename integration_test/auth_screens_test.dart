// The new account screens, in both languages.
//
// Everything is reached by tapping, not by constructing widgets: the point is
// that these are on real paths a person can walk.

import 'dart:io';

import 'package:flutter/material.dart';
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
    testWidgets('auth screens ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // 1. Welcome — new hero, and the quiet link under the primary button.
      appRouter.go('/onboarding/welcome');
      await settle(tester, ms: 3000);
      await shot('auth_${lang}_1_welcome');

      // 2. Sign in, reached by tapping that link.
      final haveAccount = find.text(
        lang == 'ru' ? 'Уже есть аккаунт?' : 'Already have an account?',
      );
      expect(haveAccount, findsOneWidget);
      await tester.tap(haveAccount);
      await settle(tester, ms: 2500);
      await shot('auth_${lang}_2_signin');

      // 3. Attach-email sheet, from the warning on the sign-in screen.
      final attachInstead = find.text(
        lang == 'ru' ? 'Лучше привязать почту' : 'Attach an email instead',
      );
      expect(attachInstead, findsOneWidget);
      await tester.tap(attachInstead);
      await settle(tester, ms: 2000);
      await shot('auth_${lang}_3_attach_sheet');
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await settle(tester, ms: 1200);

      // 4. Settings, with the permanent account row.
      appRouter.go('/dashboard');
      await settle(tester, ms: 1500);
      appRouter.push('/settings');
      await settle(tester, ms: 2500);
      await shot('auth_${lang}_4_settings');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);

      // 5. The sign-out warning on an account with no email.
      appRouter.go('/profile');
      await settle(tester, ms: 2500);
      // The row is below the fold; scroll to it or the tap lands on nothing.
      final signOut = find.text(lang == 'ru' ? 'Выйти' : 'Sign out');
      await tester.scrollUntilVisible(
        signOut,
        260,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await settle(tester, ms: 800);
      expect(signOut, findsOneWidget);
      await tester.tap(signOut, warnIfMissed: true);
      await settle(tester, ms: 2000);
      await shot('auth_${lang}_5_signout_warning');
    });
  }
}
