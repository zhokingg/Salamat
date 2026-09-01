import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// Why an auth call did not work, in terms the UI can act on.
enum AuthFailure {
  /// Wrong address or password.
  badCredentials,

  /// Somebody already registered with that address.
  emailTaken,

  /// The address is not one the server will accept.
  invalidEmail,

  /// Password below the project's minimum.
  weakPassword,

  /// Too many attempts, or Supabase's mail quota is spent.
  rateLimited,

  /// No connection, or the service did not answer.
  offline,
}

/// What happened when an email was attached to an anonymous account.
enum LinkOutcome {
  /// Attached immediately. The account is now reachable by that address.
  linked,

  /// Supabase sent a confirmation mail; the address is pending until the link
  /// in it is opened. The session and all its data are untouched either way.
  confirmationSent,
}

/// Sign-in, and turning a throwaway account into one you can come back to.
///
/// THE PROBLEM THIS SOLVES
///   Everyone starts anonymous — the app opens straight into onboarding with
///   no registration wall, and that stays true. But an anonymous account has
///   no address, so there is no way back into it: reinstall the app and the
///   food log, the weight history and the subscription state are all still in
///   the database and permanently unreachable. It also leaves a dead account
///   behind every time.
///
/// WHY EMAIL + PASSWORD AND NOT A MAGIC LINK
///   Measured, not assumed. Attaching an address to a live anonymous account
///   on this project comes back:
///       PUT /auth/v1/user -> 429 "email rate limit exceeded"
///   which means two things: confirmation mail IS enabled, and the project is
///   still on Supabase's built-in SMTP, whose quota is a couple of messages an
///   hour.
///
///   A magic link needs a working mail path on EVERY sign-in. A password needs
///   one exactly once, when the address is first attached; after that
///   [signIn] never touches email at all. With mail delivery this fragile,
///   that is the difference between a door that sometimes opens and a door
///   that always does.
///
///   It also avoids deep links. A magic link has to come back into the app
///   through a URL scheme, which means iOS URL types and Supabase redirect
///   configuration — and it breaks whenever the mail is opened on a different
///   device from the one running the app.
class AuthService {
  AuthService._();

  static User? get _user => SupabaseService.currentUser;

  /// True while the account has no address attached — the default state.
  static bool get isAnonymous {
    final u = _user;
    if (u == null) return true;
    // `isAnonymous` is the server's own flag. The email check is a belt for
    // sessions minted before the flag existed.
    return u.isAnonymous || (u.email == null || u.email!.isEmpty);
  }

  /// The attached address, or null while the account is anonymous.
  static String? get email {
    final e = _user?.email;
    return (e == null || e.isEmpty) ? null : e;
  }

  /// An address that has been submitted but not yet confirmed.
  static String? get pendingEmail {
    final e = _user?.newEmail;
    return (e == null || e.isEmpty) ? null : e;
  }

  /// Attaches [address] and [password] to the CURRENT anonymous account.
  ///
  /// The user id does not change, so every row already written — meals,
  /// weights, scan history, `profiles.is_pro` — stays attached to the same
  /// account. This is an update, never a new sign-up.
  static Future<(LinkOutcome?, AuthFailure?)> linkEmail({
    required String address,
    required String password,
  }) async {
    if (!SupabaseService.isReady) return (null, AuthFailure.offline);
    try {
      final res = await SupabaseService.client.auth.updateUser(
        UserAttributes(email: address.trim(), password: password),
      );
      final u = res.user;
      // Attached straight away when the project does not confirm addresses;
      // otherwise it sits in `new_email` until the mail is opened.
      final done = u?.email != null &&
          u!.email!.toLowerCase() == address.trim().toLowerCase();
      return (done ? LinkOutcome.linked : LinkOutcome.confirmationSent, null);
    } on AuthException catch (e) {
      return (null, _classify(e));
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] linkEmail failed: $e');
      return (null, AuthFailure.offline);
    }
  }

  /// Signs into an account that already has an address.
  ///
  /// This REPLACES the current anonymous session. Anything logged on the
  /// anonymous account beforehand belongs to that account and does not travel
  /// — which is exactly why the app offers to attach an address before it
  /// offers to sign in.
  static Future<AuthFailure?> signIn({
    required String address,
    required String password,
  }) async {
    if (!SupabaseService.isReady) return AuthFailure.offline;
    try {
      await SupabaseService.client.auth.signInWithPassword(
        email: address.trim(),
        password: password,
      );
      return null;
    } on AuthException catch (e) {
      return _classify(e);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] signIn failed: $e');
      return AuthFailure.offline;
    }
  }

  /// Ends the session for real.
  ///
  /// The old "log out" only cleared a local flag and left the session in
  /// place, so the app came back as the same account with onboarding reset —
  /// which quietly overwrote the profile. This signs out; [SupabaseService]
  /// mints a fresh anonymous account on the next launch.
  static Future<void> signOut() async {
    if (!SupabaseService.isReady) return;
    try {
      await SupabaseService.client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] signOut failed: $e');
    }
  }

  static AuthFailure _classify(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (kDebugMode) debugPrint('[Auth] ${e.statusCode} $code ${e.message}');
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        e.statusCode == '429' ||
        msg.contains('rate limit')) {
      return AuthFailure.rateLimited;
    }
    if (code == 'email_exists' ||
        code == 'user_already_exists' ||
        msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return AuthFailure.emailTaken;
    }
    if (code == 'email_address_invalid' || msg.contains('invalid')) {
      // `invalid_credentials` also contains "invalid"; check it first.
      if (code == 'invalid_credentials' || msg.contains('credentials')) {
        return AuthFailure.badCredentials;
      }
      return AuthFailure.invalidEmail;
    }
    if (code == 'weak_password' || msg.contains('password should be')) {
      return AuthFailure.weakPassword;
    }
    if (code == 'invalid_credentials' || msg.contains('credentials')) {
      return AuthFailure.badCredentials;
    }
    return AuthFailure.offline;
  }

  /// Shortest password the UI will submit. Supabase's own floor is 6; asking
  /// for a little more costs the user nothing and is the only protection this
  /// account has.
  static const int kMinPasswordLength = 8;

  /// Cheap shape check so an obvious typo is caught before a round trip.
  static bool looksLikeEmail(String s) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(s.trim());
}
