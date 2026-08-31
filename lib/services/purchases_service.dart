import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat.dart';
import 'supabase_service.dart';

/// Thin wrapper around the RevenueCat SDK.
///
/// Configured once at bootstrap, AFTER the Supabase anonymous session
/// exists: the Supabase user id becomes the RevenueCat app user id, so a
/// subscription survives reinstalls, stays linked to the same account the
/// meals/profile live under, and — critically — is the id
/// `revenuecat-webhook` uses to find the buyer's profile row.
class PurchasesService {
  PurchasesService._();

  static bool _configured = false;

  static bool get isReady => _configured;

  static Future<void> init() async {
    if (_configured) return;

    // Null on platforms RevenueCat has no SDK for (desktop, web) — those
    // builds run without purchases rather than crashing on configure.
    final key = RevenueCatConfig.platformKey;
    if (key == null) {
      if (kDebugMode) {
        debugPrint(
          '[PurchasesService] no RevenueCat key for ${Platform.operatingSystem}'
          ' — IAP disabled',
        );
      }
      return;
    }

    try {
      // The webhook finds the buyer by `app_user_id`, so this MUST be the
      // Supabase uid on every platform. Bootstrap runs SupabaseService.init()
      // first precisely so the session exists by the time we get here; if it
      // somehow does not, RevenueCat mints an anonymous id and the webhook can
      // never match the purchase to a profile.
      final uid = SupabaseService.currentUser?.id;
      if (kDebugMode && uid == null) {
        debugPrint(
          '[PurchasesService] WARNING: no Supabase session yet — RevenueCat '
          'will use an anonymous app user id and the webhook cannot match it',
        );
      }
      if (kDebugMode) {
        // Full SDK logs, debug builds only. This is how offering and product
        // failures become readable instead of a bare "offerings error".
        await Purchases.setLogLevel(LogLevel.debug);
      }
      final config = PurchasesConfiguration(key)..appUserID = uid;
      await Purchases.configure(config);
      _configured = true;
      if (kDebugMode) {
        debugPrint(
          '[PurchasesService] configured on ${Platform.operatingSystem} '
          'as appUserID=$uid',
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[PurchasesService] configure failed: $e');
    }
  }

  /// True when the given customer info carries an active Pro entitlement.
  static bool hasPro(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatConfig.proEntitlement);
}
