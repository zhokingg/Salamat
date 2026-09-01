import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

/// What an auth link turned out to be.
enum AuthLinkKind {
  /// A new account confirming its address.
  signup,

  /// A password reset. The session that comes back is only good for setting a
  /// new password.
  recovery,

  /// An address attached to an existing account, now confirmed.
  emailChange,

  /// Something else Supabase can send (magic link, invite). Treated as a plain
  /// sign-in.
  signIn,

  /// The link carried an error, or could not be used.
  failed,
}

@immutable
class AuthLinkResult {
  const AuthLinkResult(this.kind, {this.email, this.reason});

  final AuthLinkKind kind;

  /// The address the link belongs to, when the session tells us.
  final String? email;

  /// Server-side wording for a failure, for the log — never shown as-is.
  final String? reason;

  bool get ok => kind != AuthLinkKind.failed;

  /// Where the app should be after this link.
  String get destination => switch (kind) {
        AuthLinkKind.recovery => '/new-password',
        AuthLinkKind.emailChange => '/settings',
        AuthLinkKind.failed => '/auth-link-failed',
        _ => '/splash',
      };
}

/// Something worth telling the person about, raised by [AuthLink.handle] and
/// shown once by the notice listener at the app root.
///
/// A plain [ValueNotifier] rather than a provider: this is set from GoRouter's
/// `redirect`, which has no comfortable `WidgetRef`, and it carries one
/// transient message rather than any state worth rebuilding on.
final ValueNotifier<AuthLinkResult?> authLinkNotice =
    ValueNotifier<AuthLinkResult?>(null);

/// Everything the app knows about links arriving from Supabase auth emails.
///
/// WHY THIS EXISTS. Two different shapes come back, and the SDK only handles
/// one of them:
///
///   * `?code=…` — PKCE. Sent when the app asked for the mail through
///     `signUp` or `resetPasswordForEmail`, both of which attach a code
///     challenge (gotrue_client.dart:221 and :618). `supabase_flutter` picks
///     these up on its own.
///
///   * `#access_token=…&refresh_token=…&type=email_change` — implicit.
///     `updateUser` builds its request with headers, body, jwt and redirectTo
///     and NO code challenge (gotrue_client.dart:757-773), so GoTrue has
///     nothing to tie a code to and returns the tokens in the fragment
///     instead. `supabase_flutter` ignores it — its callback test requires
///     `?code=` while the flow type is pkce — and `getSessionFromUrl` throws
///     `AuthPKCEGrantCodeExchangeError` on it for the same reason
///     (gotrue_client.dart:863-871).
///
/// So the email-change link fell through to Flutter's own deep-link handling,
/// reached GoRouter as a location nobody had registered, and the person got
/// `Route not found: kg.salamat.app://login-callback/#access_token=…`.
class AuthLink {
  AuthLink._();

  /// The last URI handled, so the same link arriving twice — the SDK's
  /// app_links subscription and Flutter's route information both deliver it —
  /// is not exchanged twice.
  static String? _lastHandled;
  static AuthLinkResult? _lastResult;

  /// Query and fragment together.
  ///
  /// Implicit responses put everything after `#`, PKCE puts it in the query,
  /// and an error can arrive in either. Reading both means the rest of this
  /// file does not care which.
  static Map<String, String> params(Uri uri) {
    final out = <String, String>{...uri.queryParameters};
    if (uri.fragment.isNotEmpty) {
      out.addAll(Uri.splitQueryString(uri.fragment));
    }
    return out;
  }

  /// True when this URI is something Supabase sent us, whatever its shape.
  static bool isCallback(Uri uri) {
    final p = params(uri);
    return p.containsKey('code') ||
        p.containsKey('access_token') ||
        p.containsKey('error') ||
        p.containsKey('error_description');
  }

  /// Installs the session the link carries and says what kind of link it was.
  ///
  /// Never throws: a link is something a person clicked, and every way it can
  /// fail has to end in a sentence rather than an exception.
  static Future<AuthLinkResult> handle(Uri uri) async {
    final key = uri.toString();
    if (key == _lastHandled && _lastResult != null) return _lastResult!;
    _lastHandled = key;
    final result = await _handle(uri);
    _lastResult = result;
    if (kDebugMode) {
      debugPrint('[AuthLink] ${result.kind.name}'
          '${result.reason == null ? '' : ' — ${result.reason}'}');
    }
    return result;
  }

  static Future<AuthLinkResult> _handle(Uri uri) async {
    if (!SupabaseService.isReady) {
      return const AuthLinkResult(AuthLinkKind.failed, reason: 'not ready');
    }
    final p = params(uri);

    // Expired, already used, or refused. GoTrue puts the same pair in both the
    // query and the fragment; either one is enough.
    final error = p['error_description'] ?? p['error'];
    if (error != null) {
      return AuthLinkResult(AuthLinkKind.failed, reason: error);
    }

    final auth = SupabaseService.client.auth;
    final declaredType = p['type'];

    try {
      if (p['code'] != null) {
        // PKCE. The type is not in the URL — it was stored next to the code
        // verifier — so listen for the event the exchange raises instead.
        AuthChangeEvent? event;
        final sub = auth.onAuthStateChange.listen((s) => event ??= s.event);
        try {
          await auth.getSessionFromUrl(uri);
        } finally {
          await sub.cancel();
        }
        return AuthLinkResult(
          event == AuthChangeEvent.passwordRecovery
              ? AuthLinkKind.recovery
              : _kindFrom(declaredType),
          email: SupabaseService.currentUser?.email,
        );
      }

      final refreshToken = p['refresh_token'];
      if (refreshToken != null) {
        // Implicit. `getSessionFromUrl` refuses to read the fragment while the
        // client is in PKCE mode, so install the session from the refresh
        // token directly — it round-trips through /token, which returns a
        // freshly minted user, so the new address is on it.
        await auth.setSession(refreshToken);
        return AuthLinkResult(
          _kindFrom(declaredType),
          email: SupabaseService.currentUser?.email,
        );
      }
    } on AuthException catch (e) {
      // The SDK's own app_links subscription may have got there first and
      // spent the verifier. A session being present means it worked.
      final alreadyExchanged = SupabaseService.currentUser != null &&
          e.message.toLowerCase().contains('code verifier');
      if (alreadyExchanged) {
        return AuthLinkResult(
          _kindFrom(declaredType),
          email: SupabaseService.currentUser?.email,
        );
      }
      return AuthLinkResult(AuthLinkKind.failed, reason: e.message);
    } catch (e) {
      return AuthLinkResult(AuthLinkKind.failed, reason: '$e');
    }

    return const AuthLinkResult(AuthLinkKind.failed,
        reason: 'no code and no tokens in the link');
  }

  static AuthLinkKind _kindFrom(String? type) => switch (type) {
        'signup' => AuthLinkKind.signup,
        'recovery' => AuthLinkKind.recovery,
        'email_change' => AuthLinkKind.emailChange,
        _ => AuthLinkKind.signIn,
      };
}
