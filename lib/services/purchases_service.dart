import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/revenuecat.dart';
import 'supabase_service.dart';

/// Thin wrapper around the RevenueCat SDK.
///
/// Configured once at bootstrap, AFTER the Supabase anonymous session
/// exists: the Supabase user id becomes the RevenueCat app user id, so a
/// subscription survives reinstalls and stays linked to the same account
/// the meals/profile live under.
class PurchasesService {
  PurchasesService._();

  static bool _configured = false;

  static bool get isReady => _configured;

  static Future<void> init() async {
    if (_configured) return;
    if (!RevenueCatConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint('[PurchasesService] RevenueCat key not set — IAP disabled');
      }
      return;
    }
    // Android-only for now; the iOS key can join when that build ships.
    if (!Platform.isAndroid) return;
    try {
      final config = PurchasesConfiguration(RevenueCatConfig.androidKey)
        ..appUserID = SupabaseService.currentUser?.id;
      await Purchases.configure(config);
      _configured = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[PurchasesService] configure failed: $e');
    }
  }

  /// True when the given customer info carries an active Pro entitlement.
  static bool hasPro(CustomerInfo info) =>
      info.entitlements.active.containsKey(RevenueCatConfig.proEntitlement);
}
