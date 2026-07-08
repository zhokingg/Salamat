/// RevenueCat configuration.
///
/// The PUBLIC Android SDK key from the RevenueCat dashboard (Project →
/// API keys → Google Play). Public by design — safe to ship in the APK;
/// it can only be used to talk to the store on this app's behalf, never to
/// read or modify account data (that would need the secret key, which must
/// NEVER appear in the client).
///
/// Paste the key into [`_default`] below, or override per-build with
/// `--dart-define=REVENUECAT_ANDROID_KEY=goog_...`.
class RevenueCatConfig {
  RevenueCatConfig._();

  static const String _default = ''; // TODO: paste goog_... public key here

  static const String androidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: _default,
  );

  /// The entitlement identifier that marks an active Pro subscription,
  /// as configured in the RevenueCat dashboard.
  static const String proEntitlement = 'pro';

  static bool get isConfigured => androidKey.isNotEmpty;
}
