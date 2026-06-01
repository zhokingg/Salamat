/// Public legal-document URLs.
///
/// Replace these placeholders with the real hosted URLs before shipping.
/// Both must be reachable on the open internet — Google Play requires the
/// Privacy Policy URL to be entered on the store listing AND to be linked
/// from inside the app.
///
/// When the URLs change here they automatically update everywhere the app
/// links to them: the Profile settings rows and the paywall fine print.
class LegalUrls {
  LegalUrls._();

  // TODO(launch): replace with real hosted URLs.
  static const String privacyPolicy = 'https://salamat.fit/privacy';
  static const String termsOfService = 'https://salamat.fit/terms';

  /// True if the URLs above still look like the placeholders shipped with
  /// the template. Used by callers that want to skip opening a broken URL.
  static bool get isPlaceholder =>
      privacyPolicy.contains('salamat.fit') &&
      termsOfService.contains('salamat.fit');
}
