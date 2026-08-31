// Screenshots of every screen whose copy describes the scan model, after the
// wording was corrected to "three scans for the lifetime of the account,
// unlimited on Pro". Evidence only — asserts nothing.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/router.dart';
import 'package:salamat/screens/dashboard/dashboard_screen.dart';
import 'package:salamat/screens/manual_entry/photo_limit_sheet.dart';

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
    testWidgets('scan-model copy ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
      });
      app.main();
      await settle(tester, ms: 9000);

      // welcomeFreeLine lives on the first onboarding screen.
      appRouter.go('/onboarding/welcome');
      await settle(tester, ms: 2000);
      await shot('copy_${lang}_01_welcome');

      appRouter.go('/dashboard');
      await settle(tester, ms: 2500);

      // The limit sheet: paywallSubtitle sits under the title.
      showPhotoLimitSheet(tester.element(find.byType(DashboardScreen)));
      await settle(tester, ms: 2000);
      await shot('copy_${lang}_02_limit_sheet');
      appRouter.go('/dashboard');
      await settle(tester, ms: 1500);

      // The paywall: paywallFeature1Title in the benefit list.
      appRouter.push('/paywall');
      await settle(tester, ms: 3500);
      await shot('copy_${lang}_03_paywall');
    });
  }
}
