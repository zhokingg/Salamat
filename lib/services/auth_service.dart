import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import 'supabase_service.dart';

/// Why an auth call did not work, in terms the UI can act on.
enum AuthFailure {
  /// Wrong address or password.
  badCredentials,

  /// Somebody already registered with that address.
  emailTaken,

  /// The address exists and the password is right, but the confirmation link
  /// in the welcome mail has not been opened yet.
  ///
  /// This used to fall through to [offline], so the one error people actually
  /// hit — the confirmation mail with a broken link — told them to check their
  /// internet connection.
  emailNotConfirmed,

  /// The address is not one the server will accept.
  invalidEmail,

  /// Password below the project's minimum.
  weakPassword,

  /// Too many attempts, or Supabase's mail quota is spent.
  rateLimited,

  /// No connection, or the service did not answer in time.
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
      final res = await SupabaseService.client.auth
          .updateUser(
            UserAttributes(email: address.trim(), password: password),
            emailRedirectTo: SupabaseConfig.authRedirect,
          )
          .timeout(_kTimeout);
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
      await SupabaseService.client.auth
          .signInWithPassword(email: address.trim(), password: password)
          .timeout(_kTimeout);
      return null;
    } on AuthException catch (e) {
      return _classify(e);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] signIn failed: $e');
      return AuthFailure.offline;
    }
  }

  /// Creates a BRAND NEW account for [address].
  ///
  /// Deliberately not the same call as [linkEmail]. Registering abandons the
  /// anonymous account the person is sitting in — its diary, weight history
  /// and subscription stay behind on an account nobody can reach again — so
  /// the screen that calls this has to offer [linkEmail] first when there is
  /// anything to lose. See [RegisterScreen].
  ///
  /// With email confirmation on (this project: `mailer_autoconfirm: false`)
  /// Supabase returns a user with no session, and the address is unusable
  /// until the link in the mail is opened; that is [LinkOutcome.confirmationSent].
  static Future<(LinkOutcome?, AuthFailure?)> signUp({
    required String address,
    required String password,
  }) async {
    if (!SupabaseService.isReady) return (null, AuthFailure.offline);
    try {
      final res = await SupabaseService.client.auth
          .signUp(
            email: address.trim(),
            password: password,
            emailRedirectTo: SupabaseConfig.authRedirect,
          )
          .timeout(_kTimeout);
      // A session means the project confirms nothing and the account is live
      // immediately; otherwise it is pending until the mail is opened.
      return (
        res.session != null ? LinkOutcome.linked : LinkOutcome.confirmationSent,
        null,
      );
    } on AuthException catch (e) {
      return (null, _classify(e));
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] signUp failed: $e');
      return (null, AuthFailure.offline);
    }
  }

  /// Sends the "set a new password" mail.
  ///
  /// Nothing changes until the link is opened, so this is safe to call for an
  /// address that may not exist — and it reports success either way, on
  /// purpose: telling a stranger which addresses have accounts is a way of
  /// enumerating your users.
  static Future<AuthFailure?> sendPasswordReset(String address) async {
    if (!SupabaseService.isReady) return AuthFailure.offline;
    try {
      await SupabaseService.client.auth
          .resetPasswordForEmail(
            address.trim(),
            redirectTo: SupabaseConfig.authRedirect,
          )
          .timeout(_kTimeout);
      return null;
    } on AuthException catch (e) {
      final failure = _classify(e);
      // Do not leak "no such account" — but a spent mail quota is the user's
      // problem to wait out and must be said plainly.
      return failure == AuthFailure.rateLimited ? failure : null;
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] sendPasswordReset failed: $e');
      return AuthFailure.offline;
    }
  }

  /// Sets a new password on the CURRENT session.
  ///
  /// Two ways to get here: the recovery link put a session in place, or the
  /// person is already signed in and is changing their password from settings.
  /// Both are the same call.
  static Future<AuthFailure?> updatePassword(String password) async {
    if (!SupabaseService.isReady) return AuthFailure.offline;
    try {
      await SupabaseService.client.auth
          .updateUser(UserAttributes(password: password))
          .timeout(_kTimeout);
      return null;
    } on AuthException catch (e) {
      return _classify(e);
    } catch (e) {
      if (kDebugMode) debugPrint('[Auth] updatePassword failed: $e');
      return AuthFailure.offline;
    }
  }

  /// Ends the session for real.
  ///
  /// The old "log out" only cleared a local flag and left the session in
  /// place, so the app came back as the same account with onboarding reset —
  /// which quietly overwrote the profile. Then it signed out and left the app
  /// with no session at all until the next launch, which was worse: writes
  /// went nowhere, silently. Now a new anonymous account is minted on the
  /// spot, exactly as on a first launch, so the app is usable the moment the
  /// dialog closes.
  static Future<void> signOut() async {
    await SupabaseService.signOutAndStartFresh();
  }

  /// Maps a GoTrue error onto something the UI can say. Exposed for tests:
  /// the mail path cannot be exercised from a test run (the project's SMTP is
  /// rate limited), so the mapping is checked against the exact error objects
  /// GoTrue returns instead.
  @visibleForTesting
  static AuthFailure classify(AuthException e) => _classify(e);

  static AuthFailure _classify(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (kDebugMode) debugPrint('[Auth] ${e.statusCode} $code ${e.message}');
    // Checked before the `invalid`/`credentials` branches below: GoTrue
    // returns this from the same endpoint as a wrong password, and the two
    // need opposite advice — "try again" versus "open the link we sent you".
    if (code == 'email_not_confirmed' ||
        msg.contains('not confirmed') ||
        msg.contains('email not confirmed')) {
      return AuthFailure.emailNotConfirmed;
    }
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

  /// How long any single auth call may take before it is treated as a dead
  /// network.
  ///
  /// None of these calls had one. Every screen sets `_busy = true` and
  /// disables its button before awaiting, so a request that never returns —
  /// captive wifi, a hung DNS lookup, a phone that has just lost signal — left
  /// the person staring at a dead button with no way to retry short of killing
  /// the app. Ten seconds is what [SupabaseService.init] already uses for the
  /// same reason.
  static const Duration _kTimeout = Duration(seconds: 10);

  /// Shortest password the UI will submit. Supabase's own floor is 6; asking
  /// for a little more costs the user nothing and is the only protection this
  /// account has.
  static const int kMinPasswordLength = 8;

  /// Cheap shape check so an obvious typo is caught before a round trip.
  ///
  /// Deliberately loose — the server is the authority on what it will accept,
  /// and a regex that tries to be RFC-correct rejects real addresses. This
  /// only has to catch the mistakes people actually make while typing.
  ///
  /// The domain is matched label by label rather than as one blob, which is
  /// what the previous pattern got wrong: `aida@example..com` sailed through
  /// it (the trailing `[^@\s]+` happily matched `.com`) and the person found
  /// out only after a round trip, from a server error. An empty label now
  /// fails, so a doubled dot — the commonest slip after a missing `@` — is
  /// caught here.
  static bool looksLikeEmail(String s) =>
      _kEmail.hasMatch(s.trim());

  /// local@label(.label)+ — every label non-empty, at least one dot, and a
  /// last label of two characters or more.
  static final RegExp _kEmail = RegExp(
    r'^[^@\s]+@[^@\s.]+(\.[^@\s.]+)*\.[^@\s.]{2,}$',
  );
}
