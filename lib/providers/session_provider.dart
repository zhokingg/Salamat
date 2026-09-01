import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/purchases_service.dart';
import '../services/supabase_service.dart';
import 'bootstrap_provider.dart';

/// Every auth event Supabase emits, once bootstrap has produced a client.
///
/// `SupabaseService.authChanges` existed before this and nothing listened to
/// it, which is the whole reason signing in left the app showing the previous
/// account: the session changed and no provider heard about it.
final authEventProvider = StreamProvider<AuthState>((ref) async* {
  await ref.watch(bootstrapProvider.future);
  yield* SupabaseService.authChanges;
});

/// Who is signed in, in the terms the UI cares about.
///
/// The uid alone is not enough. Attaching an email to an anonymous account
/// does not change the uid — the whole point of it is that it does not — so a
/// screen keyed on the uid never heard about it: the settings row went on
/// saying "Почта не привязана" under a sheet that had just said the
/// confirmation mail was on its way. `updateUser` does emit `userUpdated` and
/// does refresh the stored user; it was the provider that collapsed the change
/// to an unchanged String.
///
/// Value equality is what makes this safe to watch: a token refresh fires an
/// event every hour and produces an identical record, so nobody is woken.
@immutable
class SessionIdentity {
  const SessionIdentity({
    this.uid,
    this.email,
    this.pendingEmail,
    this.isAnonymous = true,
  });

  factory SessionIdentity.of(User? u) {
    if (u == null) return const SessionIdentity();
    String? clean(String? v) => (v == null || v.isEmpty) ? null : v;
    final email = clean(u.email);
    return SessionIdentity(
      uid: u.id,
      email: email,
      pendingEmail: clean(u.newEmail),
      isAnonymous: u.isAnonymous || email == null,
    );
  }

  final String? uid;
  final String? email;

  /// Submitted but not yet confirmed.
  final String? pendingEmail;

  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      other is SessionIdentity &&
      other.uid == uid &&
      other.email == email &&
      other.pendingEmail == pendingEmail &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(uid, email, pendingEmail, isAnonymous);

  @override
  String toString() => 'SessionIdentity(uid: $uid, email: $email, '
      'pending: $pendingEmail, anonymous: $isAnonymous)';
}

/// The current account, rebuilt on every auth event.
///
/// Watch this from anything that SHOWS who is signed in.
final currentUserProvider = Provider<SessionIdentity>((ref) {
  // Rebuild on every auth event; read the user from the client rather than
  // from the event, so the very first read — before any event has been
  // emitted — is still correct.
  ref.watch(authEventProvider);
  return SessionIdentity.of(SupabaseService.currentUser);
});

/// The uid of whoever is signed in right now, or null when nobody is.
///
/// THIS IS THE KEY THAT PER-USER STATE HANGS FROM. Any provider holding
/// something that belongs to one account — the profile, the diary, weight,
/// water, the subscription — watches this. When the uid changes, Riverpod
/// rebuilds all of them; when it does not, `Provider` compares the returned
/// String and notifies nobody.
///
/// Deliberately narrower than [currentUserProvider]: attaching an email is not
/// a reason to re-read the diary, because it is the same account's diary.
///
/// The point is that it is impossible to forget. Adding a per-user provider
/// means awaiting bootstrap anyway, and [awaitSession] does both at once — so
/// a new provider is wired into session changes by construction rather than
/// by remembering to add a line to a list of `ref.invalidate` calls somewhere
/// in a screen.
final currentUidProvider =
    Provider<String?>((ref) => ref.watch(currentUserProvider).uid);

/// What a per-user provider awaits in its `build`: startup has finished, and
/// this provider is now bound to the current session.
///
/// Returns the uid so callers can branch on "nobody is signed in" without
/// reaching for the service.
Future<String?> awaitSession(Ref ref) async {
  await ref.watch(bootstrapProvider.future);
  return ref.watch(currentUidProvider);
}

/// The two things that must happen on every session change, kept alive for
/// the whole run of the app by a single `ref.watch` in [SalamatApp].
///
/// WHY IT HAS TO BE WATCHED FROM THE ROOT. `profileProvider` is what hydrates
/// [userProvider] — the name, the calorie norm, the body figures. Nothing on
/// the dashboard watches it directly, and an unlistened provider in Riverpod
/// is not kept: it was disposed after the splash screen left, so rebuilding it
/// on a uid change achieved nothing, because nobody was there to rebuild it
/// for. Watching it here gives it a listener for the lifetime of the app, and
/// the uid dependency does the rest.
///
/// The value is always null, so this never rebuilds [SalamatApp]: `Provider`
/// only notifies when the value changes, and null is null.
final sessionBindingProvider = Provider<void>((ref) {
  // Keeps the profile loaded, and re-loaded whenever the account changes.
  ref.watch(profileProvider);
  // Keeps RevenueCat's `app_user_id` equal to the Supabase uid. Sign-in,
  // sign-out and email attachment all pass through here because they all pass
  // through [currentUidProvider]. Sign-out lands on the fresh anonymous uid
  // rather than on `logOut`, which keeps the invariant the webhook depends on:
  // app_user_id IS the Supabase uid, always.
  final uid = ref.watch(currentUidProvider);
  PurchasesService.switchUser(uid);
});
