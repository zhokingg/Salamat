// What the RevenueCat SDK actually returns on this device.
//
// ignore_for_file: avoid_print
//
// Diagnostic, not an assertion: it boots the app so `PurchasesService.init`
// runs for real, then asks for the offerings and prints everything it gets,
// including the raw PlatformException when there is one. Nothing is stubbed
// and nothing is asserted about the result — an empty offering is a finding,
// not a failure.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:salamat/config/revenuecat.dart';
import 'package:salamat/main.dart' as app;
import 'package:salamat/services/purchases_service.dart';
import 'package:salamat/services/supabase_service.dart';

Future<void> settle(WidgetTester t, {int ms = 1400}) async {
  for (var e = 0; e < ms; e += 100) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('revenuecat offerings', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app_locale': 'en',
      'onboarding_completed': true,
    });
    app.main();
    await settle(tester, ms: 12000);

    print('=== CONFIG ===');
    print('platformKey        : ${RevenueCatConfig.platformKey}');
    print('isConfigured       : ${RevenueCatConfig.isConfigured}');
    print('proEntitlement     : ${RevenueCatConfig.proEntitlement}');
    print('PurchasesService.isReady: ${PurchasesService.isReady}');
    print('supabase uid       : ${SupabaseService.currentUser?.id}');

    if (!PurchasesService.isReady) {
      print('SDK never configured — stopping here.');
      return;
    }

    print('=== APP USER ID (what the webhook matches on) ===');
    try {
      print('Purchases.appUserID: ${await Purchases.appUserID}');
      print('isAnonymous        : ${await Purchases.isAnonymous}');
    } catch (e) {
      print('appUserID threw: $e');
    }

    print('=== getOfferings() ===');
    try {
      final offerings = await Purchases.getOfferings();
      print('all offering keys  : ${offerings.all.keys.toList()}');
      print('current            : ${offerings.current?.identifier}');
      for (final entry in offerings.all.entries) {
        final o = entry.value;
        print('  offering "${entry.key}": '
            '${o.availablePackages.length} available package(s)');
        for (final p in o.availablePackages) {
          final sp = p.storeProduct;
          print('    package ${p.identifier} -> ${sp.identifier} '
              '"${sp.title}" ${sp.priceString} (${sp.currencyCode})');
        }
        print('    monthly=${o.monthly?.identifier} '
            'annual=${o.annual?.identifier}');
      }
    } catch (e, st) {
      print('getOfferings THREW: $e');
      print(st);
    }

    print('=== getProducts() by identifier ===');
    try {
      final products = await Purchases.getProducts(
        ['kg.salamat.app.monthly', 'kg.salamat.app.annual'],
      );
      print('returned ${products.length} product(s)');
      for (final p in products) {
        print('  ${p.identifier} "${p.title}" ${p.priceString}');
      }
    } catch (e) {
      print('getProducts THREW: $e');
    }

    print('=== getCustomerInfo() ===');
    try {
      final info = await Purchases.getCustomerInfo();
      print('originalAppUserId  : ${info.originalAppUserId}');
      print('active entitlements: ${info.entitlements.active.keys.toList()}');
      print('hasPro             : ${PurchasesService.hasPro(info)}');
    } catch (e) {
      print('getCustomerInfo THREW: $e');
    }
  });
}
