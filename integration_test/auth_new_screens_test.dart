// ignore_for_file: avoid_print
//
// The screens added while fixing docs/auth-report.md, in both languages.
// Everything is reached by tapping so the routes are proved along with the
// layout.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/services/supabase_service.dart';

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

    testWidgets('new account screens ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // A fresh account per language, so the "you already have entries" card
      // is off for the first pass and on for the second.
      try {
        await SupabaseService.client.auth.signOut();
        await SupabaseService.client.auth.signInAnonymously();
      } catch (e) {
        print('session reset failed: $e');
      }
      await settle(tester, ms: 2500);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      // 1. Welcome — now offers both "I have an account" and "create one".
      appRouter.go('/onboarding/welcome');
      await settle(tester, ms: 3000);
      await shot('new_${lang}_1_welcome');

      // 2. Registration, on an empty account: no warning, because there is
      //    nothing on this phone to lose.
      final createLink =
          find.text(ru ? 'Создать аккаунт' : 'Create an account');
      expect(createLink, findsWidgets);
      await tester.tap(createLink.last);
      await settle(tester, ms: 2500);
      await shot('new_${lang}_2_register_empty');
      appRouter.go('/onboarding/welcome');
      await settle(tester, ms: 1500);

      // 3. Registration again, with a filled-in account: leads with attaching
      //    the email to THIS account instead.
      container.read(userProvider.notifier)
        ..setName(name: ru ? 'Аида' : 'Aida', lastName: '')
        ..setBody(height: 168, weight: 77.1)
        ..setCalorieNorm(2100);
      await settle(tester, ms: 800);
      appRouter.push('/register');
      await settle(tester, ms: 2500);
      await shot('new_${lang}_3_register_keepdata');
      appRouter.go('/onboarding/welcome');
      await settle(tester, ms: 1500);

      // 4. Sign in — now with a way out of a forgotten password and a way to
      //    an account that does not exist yet.
      appRouter.push('/sign-in');
      await settle(tester, ms: 2500);
      await shot('new_${lang}_4_signin');

      // 5. Password reset, reached from that link.
      final forgot = find.text(ru ? 'Забыли пароль?' : 'Forgot your password?');
      expect(forgot, findsOneWidget);
      await tester.tap(forgot);
      await settle(tester, ms: 2500);
      await shot('new_${lang}_5_forgot');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1500);

      // 6. Settings — the account section, with the way into another account.
      appRouter.push('/settings');
      await settle(tester, ms: 2500);
      final row = find.text(
        ru ? 'Войти в существующий аккаунт' : 'Sign in to an existing account',
      );
      await tester.scrollUntilVisible(
        row,
        240,
        scrollable: find.byType(Scrollable).first,
        maxScrolls: 20,
      );
      await settle(tester, ms: 800);
      await shot('new_${lang}_6_settings');

      // 7. Change password, from the same section.
      appRouter.push('/new-password');
      await settle(tester, ms: 2500);
      await shot('new_${lang}_7_new_password');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1200);
    });
  }
}
