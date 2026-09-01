// ignore_for_file: avoid_print
//
// The same walk as auth_diag_test, run against the fixed code and with the
// manual invalidations DELIBERATELY absent: nothing here tells the app that
// the account changed except the session change itself.
//
//   SALAMAT_TEST=integration_test/auth_fix_test.dart \
//   SALAMAT_SHOT_DIR=docs/auth-shots ./scripts/capture_store.sh
//
// Account B is created beforehand by scratchpad/mkacct.py — real rows in the
// live database. Session swap is setSession(refreshToken) rather than
// signInWithPassword because email confirmation is on and the project's SMTP
// is rate limited; both replace the session and change auth.uid(), which is
// the event everything downstream hangs off.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/providers/meals_provider.dart';
import 'package:salamat/providers/pantry_provider.dart';
import 'package:salamat/providers/subscription_provider.dart';
import 'package:salamat/providers/user_provider.dart';
import 'package:salamat/providers/water_provider.dart';
import 'package:salamat/providers/weight_provider.dart';
import 'package:salamat/router.dart';
import 'package:salamat/services/auth_service.dart';
import 'package:salamat/services/onboarding_flag.dart';
import 'package:salamat/services/purchases_service.dart';
import 'package:salamat/services/supabase_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

const int _shotPort = 8787;
const String _bUid = String.fromEnvironment('B_UID');
const String _bRefresh = String.fromEnvironment('B_REFRESH');

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

void dump(String tag, ProviderContainer container) {
  final u = container.read(userProvider);
  print('[$tag] session uid     = ${SupabaseService.currentUser?.id}');
  print('[$tag] profileProvider = '
      '${container.read(profileProvider).valueOrNull?['id']}');
  print('[$tag] name / norm     = "${u.name}" / ${u.calorieNorm}');
  print('[$tag] age/height/wt   = ${u.age} / ${u.height} / ${u.weight}');
  final meals = container.read(mealsProvider).valueOrNull;
  print('[$tag] meals in diary  = '
      '${meals == null ? "loading" : MealType.values.expand(meals.forType).length}');
  print('[$tag] weight logs     = '
      '${container.read(weightLogsProvider).valueOrNull?.length}');
  print('[$tag] water ml        = '
      '${container.read(waterProvider).valueOrNull?.totalMl}');
  print('[$tag] pantry          = ${container.read(pantryProvider)}');
  print('[$tag] subscription    = '
      'isPro=${container.read(subscriptionProvider).isPro}');
}

Future<void> dumpAsync(String tag) async {
  print('[$tag] onboarding flag = ${await OnboardingFlag.isCompleted()}');
  if (PurchasesService.isReady) {
    print('[$tag] RevenueCat id   = ${await Purchases.appUserID}');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('session change re-reads everything', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ru',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);
    // Start from the state a signed-out person is in: the flag was cleared by
    // the sign-out, and only a re-read of the profile can put it back.
    await OnboardingFlag.clear();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    // ---------- account A ----------
    final aUid = SupabaseService.currentUser?.id;
    print('A uid = $aUid');
    await SupabaseService.upsertUser(
      name: 'Аида',
      gender: 'female',
      age: 31,
      heightCm: 168,
      weightKg: 77.1,
      goal: 'lose',
      dailyCalories: 2100,
      targetWeightKg: 70,
      activityLevel: 'light',
      familiarity: 'intermediate',
    );
    container.invalidate(profileProvider);
    await settle(tester, ms: 2500);
    await container.read(mealsProvider.notifier).add(
          MealType.lunch,
          MealEntry(
            id: const Uuid().v4(),
            name: 'Лагман',
            grams: 300,
            kcal: 430,
            protein: 18,
            fat: 14,
            carbs: 55,
            source: 'photo',
          ),
        );
    for (var i = 0; i < 3; i++) {
      await container.read(waterProvider.notifier).add();
      await settle(tester, ms: 200);
    }
    container.read(pantryProvider.notifier).add('Курица, Рис');
    await settle(tester, ms: 2500);

    appRouter.go('/dashboard');
    await settle(tester, ms: 3000);
    dump('A', container);
    await dumpAsync('A');
    await shot('fix_1_A_dashboard');

    // ---------- the session changes, and nothing else does ----------
    print('--- setSession -> B ($_bUid). No ref.invalidate anywhere. ---');
    try {
      final res = await SupabaseService.client.auth.setSession(_bRefresh);
      print('setSession -> uid ${res.user?.id}');
    } catch (e) {
      print('setSession FAILED: $e');
    }
    // No provider is touched by hand. Only the auth event.
    appRouter.go('/dashboard');
    await settle(tester, ms: 6000);
    dump('B', container);
    await dumpAsync('B');
    await shot('fix_2_B_dashboard');

    appRouter.go('/profile');
    await settle(tester, ms: 3000);
    await shot('fix_3_B_profile');

    // Every number above has to match what the database holds for B.
    final row = await SupabaseService.getProfile();
    print('B profiles row = $row');

    // ---------- sign out ----------
    print('--- sign out ---');
    await AuthService.signOut();
    await settle(tester, ms: 4000);
    final freshUid = SupabaseService.currentUser?.id;
    print('after signOut: uid = $freshUid');
    print('after signOut: is it a new account? '
        '${freshUid != null && freshUid != _bUid && freshUid != aUid}');
    final saved = await SupabaseService.upsertUser(
      name: 'После выхода',
      gender: 'female',
      age: 31,
      heightCm: 168,
      weightKg: 77.1,
      goal: 'lose',
      dailyCalories: 2100,
    );
    print('upsertUser after signOut -> ${saved?['id']} name=${saved?['name']}');
    dump('after-signout', container);
    await dumpAsync('after-signout');

    expect(freshUid, isNotNull, reason: 'sign-out left the app with no session');
    expect(freshUid, isNot(_bUid));
    expect(saved, isNotNull, reason: 'writes go nowhere after sign-out');
  });
}
