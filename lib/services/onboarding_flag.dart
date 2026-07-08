import 'package:shared_preferences/shared_preferences.dart';

/// Local "onboarding completed" flag.
///
/// Set BEFORE any network write when the user finishes onboarding, so a dead
/// network (or a slow/failed profile sync) can never bounce a returning user
/// back into onboarding. The splash gate checks this flag first; the Supabase
/// profile is synced in the background and only ever *adds* data on top.
///
/// Cleared on logout and on account deletion.
class OnboardingFlag {
  OnboardingFlag._();

  static const _key = 'onboarding_completed';

  static Future<void> setCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
