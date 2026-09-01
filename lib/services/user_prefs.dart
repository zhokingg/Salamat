import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Device storage that belongs to one account.
///
/// The device-local caches used to sit under fixed keys — `water_local_today`,
/// `pantry_items` — which meant they outlived the account that wrote them:
/// sign out, sign in as somebody else, and yesterday's water and the previous
/// person's shopping list were still on screen. Suffixing the uid makes each
/// account's copy its own.
///
/// Signed out there is no uid, so the key falls back to `:none`. Nothing
/// should be writing then anyway — [SupabaseService.signOutAndStartFresh]
/// mints a new anonymous session immediately — but a wrong-looking key beats
/// silently sharing one.
String userScopedKey(String base) {
  final uid = SupabaseService.currentUser?.id;
  return '$base:${uid ?? 'none'}';
}

/// Moves a value written under the old, account-less key onto this account's
/// key, once.
///
/// Without this the first launch after the fix looks like data loss to whoever
/// is currently signed in — their pantry list would simply be gone. The legacy
/// key is removed after the move, so the value cannot be adopted a second time
/// by a different account.
Future<void> adoptLegacyKey(SharedPreferences prefs, String legacy,
    String scoped) async {
  try {
    if (prefs.containsKey(scoped) || !prefs.containsKey(legacy)) return;
    final value = prefs.getString(legacy);
    if (value != null) await prefs.setString(scoped, value);
    await prefs.remove(legacy);
  } catch (_) {
    // Best effort: failing to migrate costs one list, failing loudly costs
    // the screen.
  }
}
