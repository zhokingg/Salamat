// The paywall's goal line, in the state where it has numbers to show.
//
// A fresh simulator account has no target weight, so the paywall falls back to
// the generic line. This seeds a real goal through the provider so the
// pace variant renders, and captures both languages.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/user_provider.dart';
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
    testWidgets('paywall goal line ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      // 78 kg now, 70 kg wanted -> 8 kg over 16 weeks -> 0.5 kg a week.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(userProvider.notifier)
        ..setGoal(Goal.lose)
        ..setBody(height: 170, weight: 78)
        ..setTargetWeight(70);
      await settle(tester, ms: 500);

      appRouter.go('/dashboard');
      await settle(tester, ms: 1500);
      appRouter.push('/paywall');
      await settle(tester, ms: 7000);
      await shot('paywall_${lang}_goalline');
    });
  }
}
