// The shapes an auth link can arrive in.
//
// Both of them reached a person in the wild: `?code=` from signup and
// recovery, `#access_token=…&type=email_change` from attaching an address.
// The second is the one that used to fall through to GoRouter and print
// `Route not found: …` with the tokens in it.

import 'package:flutter_test/flutter_test.dart';
import 'package:salamat/services/auth_link.dart';

void main() {
  const base = 'kg.salamat.app://login-callback';

  test('a PKCE link is recognised', () {
    final uri = Uri.parse('$base?code=93054c91-5a8f-4593-9f20-bb3facbd9fd1');
    expect(AuthLink.isCallback(uri), isTrue);
    expect(AuthLink.params(uri)['code'], '93054c91-5a8f-4593-9f20-bb3facbd9fd1');
  });

  test('an implicit email_change link is recognised, fragment and all', () {
    final uri = Uri.parse(
      '$base/#access_token=eyJhbGciOi&expires_at=1788259380&expires_in=3600'
      '&refresh_token=4ofwnmynslup&token_type=bearer&type=email_change',
    );
    expect(AuthLink.isCallback(uri), isTrue);
    final p = AuthLink.params(uri);
    expect(p['type'], 'email_change');
    expect(p['refresh_token'], '4ofwnmynslup');
    expect(p['access_token'], 'eyJhbGciOi');
  });

  test('an expired link is recognised as a callback, not as a route', () {
    final uri = Uri.parse(
      '$base?error=access_denied&error_code=otp_expired'
      '&error_description=Email+link+is+invalid+or+has+expired'
      '#error=access_denied&error_code=otp_expired',
    );
    expect(AuthLink.isCallback(uri), isTrue);
    expect(AuthLink.params(uri)['error_code'], 'otp_expired');
  });

  test('ordinary in-app routes are left alone', () {
    for (final path in const [
      '/dashboard',
      '/meals',
      '/meal/lunch/6bfe1bf0-dc18-43de-9dba-98ca0db825fe',
      '/settings',
      '/onboarding/welcome',
      '/new-password',
    ]) {
      expect(AuthLink.isCallback(Uri.parse(path)), isFalse,
          reason: '$path must not be treated as an auth link');
    }
  });

  test('each kind knows where it belongs', () {
    expect(const AuthLinkResult(AuthLinkKind.recovery).destination,
        '/new-password');
    expect(const AuthLinkResult(AuthLinkKind.emailChange).destination,
        '/settings');
    expect(const AuthLinkResult(AuthLinkKind.signup).destination, '/splash');
    expect(const AuthLinkResult(AuthLinkKind.signIn).destination, '/splash');
    expect(const AuthLinkResult(AuthLinkKind.failed).destination,
        '/auth-link-failed');
    expect(const AuthLinkResult(AuthLinkKind.failed).ok, isFalse);
  });
}
