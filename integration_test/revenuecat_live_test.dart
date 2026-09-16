// ignore_for_file: avoid_print
//
// RevenueCat smoke test against the live SDK on a simulator.
//
//   fvm flutter test integration_test/revenuecat_live_test.dart -d <udid>
//
// Written for the purchases_flutter 8 -> 10 bump (forced by Xcode 27: the
// RevenueCat 5.32 pod no longer compiles under Swift 6.4). It checks the four
// things the app relies on, in the order they happen at runtime:
//
//   1. configure() succeeds and the SDK reports itself configured;
//   2. appUserID is the Supabase uid — the id `revenuecat-webhook` matches
//      purchases to a profile row by, so this is the one that must not drift;
//   3. switching accounts (sign out -> fresh anonymous session) walks the
//      session binding: logOut on the null uid, logIn on the new one, and
//      appUserID follows;
//   4. getOfferings / getCustomerInfo / restorePurchases answer without a
//      configuration error. Prices are NOT expected: the products are still
//      awaiting Apple's approval, so the current offering may be empty.
//      Anything StoreKit-shaped from restorePurchases on a simulator is
//      reported as-is rather than asserted away.
//
// Nothing here buys anything.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/main.dart' as app;
import 'package:salamat/providers/bootstrap_provider.dart';
import 'package:salamat/services/purchases_service.dart';
import 'package:salamat/services/supabase_service.dart';

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

String short(String? id) => id == null ? 'null' : '${id.substring(0, 8)}…';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('RevenueCat 10.x: configure, uid binding, account switch, calls',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'ru',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 9000);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    await container.read(bootstrapProvider.future);
    await settle(tester, ms: 2000);

    // 1. Configured.
    expect(PurchasesService.isReady, isTrue,
        reason: 'PurchasesService.init() did not configure the SDK');
    expect(await Purchases.isConfigured, isTrue,
        reason: 'Purchases.isConfigured is false after init()');
    print('[RC] configured: yes');

    // 2. appUserID == Supabase uid.
    final uid1 = SupabaseService.currentUser?.id;
    expect(uid1, isNotNull, reason: 'no Supabase session after bootstrap');
    final rc1 = await Purchases.appUserID;
    print('[RC] supabase uid ${short(uid1)}  appUserID ${short(rc1)}');
    expect(rc1, uid1, reason: 'RevenueCat appUserID is not the Supabase uid');
    expect(await Purchases.isAnonymous, isFalse,
        reason: 'SDK thinks the user is RevenueCat-anonymous');

    // 4a. Customer info for that id.
    final info1 = await Purchases.getCustomerInfo();
    print('[RC] customerInfo.originalAppUserId ${short(info1.originalAppUserId)}'
        ' active entitlements ${info1.entitlements.active.keys.toList()}'
        ' hasPro=${PurchasesService.hasPro(info1)}');
    expect(info1.originalAppUserId, uid1);

    // 4b. Offerings — must answer; may be empty until Apple approves.
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      print('[RC] offerings: all=${offerings.all.keys.toList()} '
          'current=${current?.identifier} '
          'packages=${current?.availablePackages.map((p) => '${p.identifier}:${p.storeProduct.priceString}').toList()}');
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      print('[RC] getOfferings PlatformException code=$code '
          'message=${e.message} details=${e.details}');
      expect(code, isNot(PurchasesErrorCode.configurationError),
          reason: 'getOfferings: configuration error');
      expect(code, isNot(PurchasesErrorCode.invalidCredentialsError),
          reason: 'getOfferings: invalid API key');
    }

    // 4c. Restore — no purchases exist; the call itself must not be a
    // configuration/credentials error. StoreKit quirks on a simulator are
    // printed, not asserted.
    try {
      final restored = await Purchases.restorePurchases();
      print('[RC] restorePurchases ok: originalAppUserId '
          '${short(restored.originalAppUserId)} '
          'active=${restored.entitlements.active.keys.toList()} '
          'allPurchased=${restored.allPurchasedProductIdentifiers}');
      expect(restored.originalAppUserId, uid1);
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      print('[RC] restorePurchases PlatformException code=$code '
          'message=${e.message} details=${e.details}');
      expect(code, isNot(PurchasesErrorCode.configurationError));
      expect(code, isNot(PurchasesErrorCode.invalidCredentialsError));
    }

    // 3. Account switch: sign out, fresh anonymous session. The session
    // binding sees uid -> null (logOut) then null -> uid2 (logIn).
    final uid2 = await SupabaseService.signOutAndStartFresh();
    expect(uid2, isNotNull, reason: 'signOutAndStartFresh gave no session');
    expect(uid2, isNot(uid1), reason: 'sign-out did not change the uid');
    await settle(tester, ms: 4000);

    final rc2 = await Purchases.appUserID;
    print('[RC] after switch: supabase uid ${short(uid2)}  '
        'appUserID ${short(rc2)}');
    expect(rc2, uid2,
        reason: 'appUserID did not follow the new Supabase uid (logIn path)');
    expect(rc2, isNot(rc1));
    expect(await Purchases.isAnonymous, isFalse);

    final info2 = await Purchases.getCustomerInfo();
    print('[RC] customerInfo after switch: originalAppUserId '
        '${short(info2.originalAppUserId)}');
    expect(info2.originalAppUserId, uid2);

    // Explicit logOut/logIn round trip on the SDK itself, so the two calls
    // the binding relies on are exercised directly and not only via events.
    final loggedOut = await Purchases.logOut();
    print('[RC] logOut -> anonymous ${short(loggedOut.originalAppUserId)} '
        'isAnonymous=${await Purchases.isAnonymous}');
    expect(await Purchases.isAnonymous, isTrue);
    final back = await Purchases.logIn(uid2!);
    print('[RC] logIn -> ${short(back.customerInfo.originalAppUserId)} '
        'created=${back.created}');
    expect(await Purchases.appUserID, uid2);
  });
}
