// The error mapping, against the exact objects GoTrue produces.
//
// Diagnostic/regression: the mail path itself cannot be exercised here — the
// project's built-in SMTP is rate limited to a couple of messages an hour, so
// no confirmable account can be created from a test run. What CAN be pinned
// down is that each error code lands on the right sentence, which is where
// the reported bug was: `email_not_confirmed` fell through to "check your
// internet connection".

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:salamat/services/auth_service.dart';

AuthException err(String code, String message, [String status = '400']) =>
    AuthException(message, statusCode: status, code: code);

void main() {
  test('every GoTrue error the auth screens can hit is classified', () {
    final cases = <(AuthException, AuthFailure, String)>[
      (
        err('email_not_confirmed', 'Email not confirmed'),
        AuthFailure.emailNotConfirmed,
        'the confirmation link has not been opened',
      ),
      (
        // Same endpoint, same status, opposite advice.
        err('invalid_credentials', 'Invalid login credentials'),
        AuthFailure.badCredentials,
        'wrong address or password',
      ),
      (
        err('email_exists', 'Email address already registered by another user'),
        AuthFailure.emailTaken,
        'the address is taken',
      ),
      (
        err('over_email_send_rate_limit', 'email rate limit exceeded', '429'),
        AuthFailure.rateLimited,
        'the mail quota is spent',
      ),
      (
        err('email_address_invalid', 'Email address "x" is invalid'),
        AuthFailure.invalidEmail,
        'not an address the server accepts',
      ),
      (
        err('weak_password', 'Password should be at least 6 characters', '422'),
        AuthFailure.weakPassword,
        'password too short',
      ),
    ];

    for (final (e, expected, why) in cases) {
      expect(
        AuthService.classify(e),
        expected,
        reason: '${e.code} should read as "$why"',
      );
    }
  });

  test('the address check accepts real addresses and rejects typos', () {
    const accept = [
      'aida@example.com',
      'aida+diet@example.com',
      'aida.n@mail.example.co.uk',
      'a@b.io',
      ' aida@example.com ', // trimmed before matching, and before sending
      'аида@пример.рф',
    ];
    const reject = [
      '',
      'aidaexample.com', // no @
      'aida@examplecom', // no dot
      'aida @example.com', // space inside
      'aida@@example.com', // two @
      'aida@example..com', // the one that used to get through
      'aida@.com', // empty first label
      'aida@example.', // empty last label
      'aida@example.c', // single-character TLD
    ];
    for (final a in accept) {
      expect(AuthService.looksLikeEmail(a), isTrue, reason: 'should accept "\$a"');
    }
    for (final a in reject) {
      expect(AuthService.looksLikeEmail(a), isFalse, reason: 'should reject "\$a"');
    }
  });

  test('email_not_confirmed is recognised by message alone', () {
    // Older GoTrue builds send no `code`. The message check is the fallback,
    // and it must not be swallowed by the `invalid`/`credentials` branches.
    expect(
      AuthService.classify(AuthException('Email not confirmed',
          statusCode: '400')),
      AuthFailure.emailNotConfirmed,
    );
  });
}
