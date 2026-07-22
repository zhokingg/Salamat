import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

/// Wraps the global Supabase singleton.
///
/// Call [init] once from `main()` before `runApp`.
/// After that, access the client via [SupabaseService.client].
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    if (!SupabaseConfig.isConfigured) {
      if (kDebugMode) {
        debugPrint(
          '[SupabaseService] SUPABASE_URL / SUPABASE_ANON_KEY not set — '
          'running in offline mode. Pass them via --dart-define to enable sync.',
        );
      }
      return;
    }

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      debug: kDebugMode,
    ).timeout(const Duration(seconds: 10));

    // Guarantee every user has a session. Anonymous sign-in gives a stable
    // auth.uid() so RLS-scoped rows (meals, weight, photo usage) and the
    // recognize-food Edge Function all work without forcing account creation.
    // A persisted session is restored by Supabase.initialize, so we only sign
    // in when there is genuinely no user yet.
    if (Supabase.instance.client.auth.currentUser == null) {
      try {
        await Supabase.instance.client.auth
            .signInAnonymously()
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        if (kDebugMode) debugPrint('[SupabaseService] signInAnonymously: $e');
      }
    }

    _initialized = true;
  }

  static SupabaseClient get client => Supabase.instance.client;

  static bool get isReady => _initialized;

  static User? get currentUser => isReady ? client.auth.currentUser : null;

  static bool get isSignedIn => currentUser != null;

  static Stream<AuthState> get authChanges =>
      isReady ? client.auth.onAuthStateChange : const Stream.empty();

  // -------- profile --------

  static Future<Map<String, dynamic>?> upsertUser({
    required String name,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String goal,
    required int dailyCalories,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      return await client.from('profiles').upsert({
        'id': uid,
        'name': name,
        'gender': gender,
        'age': age,
        'height': heightCm,
        'weight': weightKg,
        'goal': goal,
        'calorie_norm': dailyCalories,
      }).select().single();
    } catch (e) {
      if (kDebugMode) debugPrint('upsertUser error: $e');
      return null;
    }
  }

  /// Reads the current user's profile row, or null if there's no user, no row,
  /// or the read failed. The `handle_new_user` trigger inserts an empty row at
  /// anonymous sign-in, so callers must verify `name`/`calorie_norm` are
  /// populated before treating the profile as "onboarded".
  static Future<Map<String, dynamic>?> getProfile() async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    try {
      return await client
          .from('profiles')
          .select()
          .eq('id', uid)
          .maybeSingle();
    } catch (e) {
      if (kDebugMode) debugPrint('getProfile error: $e');
      return null;
    }
  }

  /// Permanently deletes the current user's account and all their data via the
  /// `delete-account` Edge Function (cascade removes profile, meals, weight,
  /// photo usage). On success the old session is cleared and a fresh anonymous
  /// session is created so the app stays usable as a brand-new user.
  ///
  /// Returns true if the account was deleted.
  static Future<bool> deleteAccount() async {
    if (!isReady || !isSignedIn) return false;
    try {
      final res = await client.functions.invoke('delete-account');
      if (res.status != 200) {
        if (kDebugMode) {
          debugPrint('deleteAccount status ${res.status}: ${res.data}');
        }
        return false;
      }
      // Clear the now-deleted user's session, then start clean.
      await client.auth.signOut();
      await client.auth.signInAnonymously();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteAccount error: $e');
      return false;
    }
  }

  // -------- meals (food logs) --------

  static Future<void> logFood({
    required String foodName,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double portionG,
    required String mealType,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await client.from('meals').insert({
        'user_id': uid,
        'name': foodName,
        'meal_type': mealType,
        'grams': portionG,
        'kcal': calories,
        'protein': proteinG,
        'fat': fatG,
        'carbs': carbsG,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('logFood error: $e');
    }
  }

  /// Throws on network/backend failure so callers (mealsProvider) can surface
  /// a real error state instead of silently rendering an empty diary.
  static Future<List<Map<String, dynamic>>> getTodayFoodLogs() async {
    if (!isSignedIn) return [];
    try {
      final now = DateTime.now();
      final startLocal = DateTime(now.year, now.month, now.day);
      final rows = await client
          .from('meals')
          .select()
          .gte('eaten_at', startLocal.toUtc().toIso8601String())
          .order('eaten_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('getTodayFoodLogs error: $e');
      rethrow;
    }
  }

  static Future<bool> deleteFoodLog(String id) async {
    if (!isSignedIn) return false;
    try {
      await client.from('meals').delete().eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteFoodLog error: $e');
      return false;
    }
  }

  // -------- weight --------

  static Future<void> logWeight(double weightKg) async {
    final uid = currentUser?.id;
    if (uid == null) return;
    try {
      await client.from('weight_logs').insert({
        'user_id': uid,
        'weight_kg': weightKg,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('logWeight error: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getWeightHistory({
    int? limit,
  }) async {
    if (!isSignedIn) return [];
    try {
      final base = client
          .from('weight_logs')
          .select()
          .order('logged_at', ascending: false);
      final rows = limit != null ? await base.limit(limit) : await base;
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('getWeightHistory error: $e');
      return [];
    }
  }
}
