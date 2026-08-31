// Screens changed by the on-device feedback pass.
//
// The scan indicator is rendered directly rather than driven through the
// camera: the simulator has no camera, so `CameraScreen` shows its unavailable
// stub there and the overlay never appears. This is the same `ScanProgress`
// widget the camera builds, in the same three states, over a dark backdrop
// standing in for the viewfinder.

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
import 'package:salamat/widgets/scan_progress.dart';

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
    testWidgets('scan indicator ($lang)', (WidgetTester tester) async {
      for (final stage in ScanStage.values.where((s) => s != ScanStage.idle)) {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(lang),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            debugShowCheckedModeBanner: false,
            // A Material ancestor, or every Text renders with the debug
            // "no Material" yellow underline instead of the real style.
            home: Material(
              color: const Color(0xFF101314),
              child: ScanProgress(stage: stage),
            ),
          ),
        );
        await settle(tester, ms: 900);
        await shot('fix_scanstage_${stage.name}_$lang');
      }
    });

    testWidgets('summary bmi + tabs ($lang)', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app_locale': lang,
        'onboarding_completed': true,
      });
      app.main();
      await settle(tester, ms: 9000);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );
      container.read(userProvider.notifier)
        ..setName(name: 'Aina', lastName: '')
        ..setGender(Gender.female)
        ..setGoal(Goal.lose)
        ..setAge(31)
        // 24.4 BMI — the value from the device recording.
        ..setBody(height: 170, weight: 70.5)
        ..setTargetWeight(65)
        ..setActivityLevel(ActivityLevel.light)
        ..setFamiliarity(Familiarity.intermediate);
      await settle(tester, ms: 500);

      appRouter.go('/onboarding/summary');
      await settle(tester, ms: 3000);
      await shot('fix_summary_bmi_$lang');

      // A weight that lands in the top band, to check the wording there is
      // still a reference rather than a verdict.
      container.read(userProvider.notifier).setBody(height: 170, weight: 95);
      await settle(tester, ms: 1200);
      await shot('fix_summary_bmi_high_$lang');

      // Tabs: home, away, back. The ring must not replay on the return.
      appRouter.go('/dashboard');
      await settle(tester, ms: 3000);
      await shot('fix_tabs_1_home_$lang');
      appRouter.go('/progress');
      await settle(tester, ms: 2000);
      await shot('fix_tabs_2_progress_$lang');
      appRouter.go('/dashboard');
      // Deliberately short: if the entrance animation were replaying, the ring
      // would still be mid-count here.
      await settle(tester, ms: 400);
      await shot('fix_tabs_3_back_$lang');
    });
  }
}
