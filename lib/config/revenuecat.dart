import 'dart:io';

/// RevenueCat configuration.
///
/// These are the PUBLIC SDK keys from the RevenueCat dashboard (Project →
/// API keys). Public by design — safe to ship in the binary; they can only
/// talk to the store on this app's behalf, never read or modify account data
/// (that would need the secret key, which must NEVER appear in the client).
///
/// Override per-build with `--dart-define=REVENUECAT_ANDROID_KEY=goog_...`
/// or `--dart-define=REVENUECAT_IOS_KEY=appl_...`.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String _defaultAndroid = 'goog_MjXDCzsmgjILoXATHgzTkXLsCmX';
  static const String _defaultIos = 'appl_MjiHUNTkXnazLWYJtCwXSEmxdeu';

  static const String androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: _defaultAndroid,
  );

  static const String iosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: _defaultIos,
  );

  /// The key for the platform the app is running on, or null where RevenueCat
  /// has no SDK (desktop, web) — those builds simply run without purchases.
  static String? get platformKey {
    if (Platform.isIOS || Platform.isMacOS) {
      return iosKey.isEmpty ? null : iosKey;
    }
    if (Platform.isAndroid) {
      return androidKey.isEmpty ? null : androidKey;
    }
    return null;
  }

  /// The entitlement identifier that marks an active Pro subscription,
  /// as configured in the RevenueCat dashboard.
  static const String proEntitlement = 'pro';

  static bool get isConfigured => platformKey != null;
}
