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
    // auth.uid() so RLS-scoped rows (meals, weight, scan counters) and the
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

  /// Ends the current session and immediately starts a new anonymous one.
  ///
  /// Signing out on its own left the app with NO session for the rest of the
  /// process: [init] is guarded by `_initialized` and will not run again, so
  /// `auth.uid()` stayed null, every RLS-scoped write silently wrote nowhere
  /// (`upsertUser` returns null when there is no uid) and the person saw no
  /// error at all. Sign-out has to hand the app a working account the same way
  /// a first launch does.
  ///
  /// Returns the new anonymous uid, or null if the fresh sign-in failed — in
  /// which case the app is offline and there is nothing better to be done than
  /// let the next launch retry.
  static Future<String?> signOutAndStartFresh() async {
    if (!isReady) return null;
    try {
      await client.auth.signOut();
    } catch (e) {
      if (kDebugMode) debugPrint('signOut error: $e');
    }
    try {
      final res = await client.auth
          .signInAnonymously()
          .timeout(const Duration(seconds: 10));
      return res.user?.id;
    } catch (e) {
      if (kDebugMode) debugPrint('post-signOut signInAnonymously failed: $e');
      return null;
    }
  }

  // -------- profile --------

  static Future<Map<String, dynamic>?> upsertUser({
    required String name,
    required String gender,
    required int age,
    required double heightCm,
    required double weightKg,
    required String goal,
    required int dailyCalories,
    double? targetWeightKg,
    String? activityLevel,
    String? familiarity,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) return null;
    final core = <String, dynamic>{
      'id': uid,
      'name': name,
      'gender': gender,
      'age': age,
      'height': heightCm,
      'weight': weightKg,
      'goal': goal,
      'calorie_norm': dailyCalories,
    };
    // Added by migration 0010. Sent when the caller has them; if the migration
    // has not been applied yet PostgREST answers PGRST204 ("Could not find the
    // 'target_weight' column"), and the write is retried without them rather
    // than losing the whole profile over three optional fields.
    final extended = <String, dynamic>{
      ...core,
      if (targetWeightKg != null) 'target_weight': targetWeightKg,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (familiarity != null) 'familiarity': familiarity,
    };
    try {
      return await client
          .from('profiles')
          .upsert(extended)
          .select()
          .single();
    } catch (e) {
      if (extended.length > core.length && _isMissingColumn(e)) {
        if (kDebugMode) {
          debugPrint('upsertUser: migration 0010 not applied, '
              'writing without the goal columns');
        }
        try {
          return await client.from('profiles').upsert(core).select().single();
        } catch (e2) {
          if (kDebugMode) debugPrint('upsertUser error: $e2');
          return null;
        }
      }
      if (kDebugMode) debugPrint('upsertUser error: $e');
      return null;
    }
  }

  /// PostgREST's "this column is not in my schema cache" — i.e. the migration
  /// that adds it has not been run.
  static bool _isMissingColumn(Object e) {
    if (e is PostgrestException) {
      return e.code == 'PGRST204' ||
          e.message.contains('Could not find the');
    }
    return false;
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
  /// `delete-account` Edge Function. Deleting the auth user cascades to
  /// profiles, meals, weight_logs, water_logs, scan_events, coach_events and
  /// recognition_usage. On success the old session is cleared and a fresh
  /// anonymous session is created so the app stays usable as a brand-new user.
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
      await signOutAndStartFresh();
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteAccount error: $e');
      return false;
    }
  }

  // -------- meals (food logs) --------

  /// Writes one meal row.
  ///
  /// THROWS on failure, on purpose. It used to catch everything and log to the
  /// debug console, which meant a rejected write — a bad uuid, RLS, no network
  /// — left the entry sitting in the diary looking saved and gone by the next
  /// launch. [MealsNotifier.add] is what turns the throw into a rollback and a
  /// message; nothing else calls this.
  static Future<void> logFood({
    /// Client-generated row id. Passed through so the local entry and the DB
    /// row share one identity: without it Postgres minted its own uuid and
    /// every later `updateFoodLog(id: entry.id)` matched zero rows, so edits
    /// to an entry created this session (portion changes, the macro backfill)
    /// updated local state and silently never reached the database.
    required String id,
    required String foodName,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
    required double portionG,
    required String mealType,
  }) async {
    final uid = currentUser?.id;
    if (uid == null) throw StateError('logFood: no session');
    await client.from('meals').insert({
      'id': id,
      'user_id': uid,
      'name': foodName,
      'meal_type': mealType,
      'grams': portionG,
      'kcal': calories,
      'protein': proteinG,
      'fat': fatG,
      'carbs': carbsG,
    });
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

  /// Food logs from [since] (inclusive, local time) up to now.
  ///
  /// Same `meals` table and columns as [getTodayFoodLogs] — only the lower
  /// bound differs, so multi-day analytics need no schema change. Returns an
  /// empty list rather than throwing: analytics are a read-only view and a
  /// transient failure should degrade to "no data", not break the screen.
  static Future<List<Map<String, dynamic>>> getFoodLogsSince(
    DateTime since,
  ) async {
    if (!isSignedIn) return [];
    try {
      final rows = await client
          .from('meals')
          .select()
          .gte('eaten_at', since.toUtc().toIso8601String())
          .order('eaten_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('getFoodLogsSince error: $e');
      return [];
    }
  }

  /// Rewrites the nutrition of one existing row.
  ///
  /// An update rather than delete-and-insert so `eaten_at` and the row id
  /// survive — re-inserting would move the meal to "now" and break the day it
  /// belongs to. The `meals_all_own` policy is `for all`, so this needs no
  /// schema or policy change.
  static Future<bool> updateFoodLog({
    required String id,
    required double portionG,
    required int calories,
    required double proteinG,
    required double carbsG,
    required double fatG,
  }) async {
    if (!isSignedIn) return false;
    try {
      await client.from('meals').update({
        'grams': portionG,
        'kcal': calories,
        'protein': proteinG,
        'carbs': carbsG,
        'fat': fatG,
      }).eq('id', id);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('updateFoodLog error: $e');
      return false;
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

  // -------- water --------

  /// Today's water rows, oldest first.
  ///
  /// Returns null — distinct from an empty list — when the table is not there
  /// yet or the read fails, so the caller can tell "no water logged" apart
  /// from "cannot persist water at all" and fall back accordingly.
  /// `water_logs` ships in migration 0004.
  static Future<List<Map<String, dynamic>>?> getTodayWater() async {
    if (!isSignedIn) return null;
    try {
      final now = DateTime.now();
      final startLocal = DateTime(now.year, now.month, now.day);
      final rows = await client
          .from('water_logs')
          .select()
          .gte('logged_at', startLocal.toUtc().toIso8601String())
          .order('logged_at', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      if (kDebugMode) debugPrint('getTodayWater unavailable: $e');
      return null;
    }
  }

  /// Logs one portion. False when the row could not be written — most likely
  /// because migration 0004 has not been applied.
  static Future<bool> logWater(int amountMl) async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      await client.from('water_logs').insert({
        'user_id': uid,
        'amount_ml': amountMl,
      });
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('logWater unavailable: $e');
      return false;
    }
  }

  /// Deletes today's most recent water row.
  static Future<bool> deleteLatestWater() async {
    final uid = currentUser?.id;
    if (uid == null) return false;
    try {
      final rows = await client
          .from('water_logs')
          .select('id')
          .eq('user_id', uid)
          .order('logged_at', ascending: false)
          .limit(1);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return false;
      await client.from('water_logs').delete().eq('id', list.first['id']);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('deleteLatestWater unavailable: $e');
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
