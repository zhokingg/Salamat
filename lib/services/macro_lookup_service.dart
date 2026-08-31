import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';

/// Macro breakdown for one dish, in grams for the serving that was logged.
@immutable
class Macros {
  const Macros({required this.protein, required this.fat, required this.carbs});

  final double protein;
  final double fat;
  final double carbs;
}

/// Grams per kcal, so one lookup answers the same dish at any portion.
///
/// Caching the ratio rather than the absolute grams is what makes "плов"
/// free the second time it is logged, even when the calorie figure differs.
@immutable
class _MacroRatio {
  const _MacroRatio(this.p, this.f, this.c);

  final double p;
  final double f;
  final double c;

  Macros scale(int kcal) =>
      Macros(protein: p * kcal, fat: f * kcal, carbs: c * kcal);

  Map<String, double> toJson() => {'p': p, 'f': f, 'c': c};

  static _MacroRatio? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final p = (raw['p'] as num?)?.toDouble();
    final f = (raw['f'] as num?)?.toDouble();
    final c = (raw['c'] as num?)?.toDouble();
    if (p == null || f == null || c == null) return null;
    return _MacroRatio(p, f, c);
  }
}

/// Looks up protein/fat/carbs for a dish the user logged by hand.
///
/// Manual logging stays free: this never touches the photo quota — see
/// `PhotoRecognitionService.incrementUsage`, which only the camera calls.
///
/// Backed by the `suggest-meal` Edge Function in its `mode: 'macros'` branch.
/// Every result is cached by dish name (normalised, case-insensitive) both in
/// memory for the session and in SharedPreferences across launches, so a dish
/// someone logs regularly costs exactly one call, ever. No new tables.
///
/// When the function is unreachable this returns null and the caller leaves
/// the entry without macros — the UI then renders a dash. It never invents a
/// number and never writes zeros as if they were measured.
class MacroLookupService {
  MacroLookupService._();

  static const String _kFunctionName = 'suggest-meal';
  static const String _kCacheKey = 'macro_cache_v1';
  static const Duration _kTimeout = Duration(seconds: 20);

  /// Oldest entries are dropped past this; a food diary's working set of
  /// dish names is small, and the cache is a convenience, not a store.
  static const int _kMaxCached = 300;

  static final Map<String, _MacroRatio> _session = <String, _MacroRatio>{};
  static bool _diskLoaded = false;

  /// Token usage of the most recent live call, for cost reporting.
  static ({int? input, int? output})? lastUsage;

  static String _key(String dish) => dish.trim().toLowerCase();

  static Future<void> _loadDisk() async {
    if (_diskLoaded) return;
    _diskLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCacheKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      decoded.forEach((k, v) {
        final ratio = _MacroRatio.fromJson(v);
        if (ratio != null) _session[k.toString()] = ratio;
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[MacroLookup] cache read failed: $e');
    }
  }

  static Future<void> _saveDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var entries = _session.entries.toList();
      if (entries.length > _kMaxCached) {
        entries = entries.sublist(entries.length - _kMaxCached);
      }
      await prefs.setString(
        _kCacheKey,
        jsonEncode({for (final e in entries) e.key: e.value.toJson()}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[MacroLookup] cache write failed: $e');
    }
  }

  /// True when [dish] can be answered without a network call.
  static Future<bool> isCached(String dish) async {
    await _loadDisk();
    return _session.containsKey(_key(dish));
  }

  /// Macros for [kcal] worth of [dish], or null when they cannot be obtained.
  static Future<Macros?> lookup({
    required String dish,
    required int kcal,
    required String lang,
  }) async {
    final name = dish.trim();
    if (name.isEmpty || kcal <= 0) return null;

    await _loadDisk();
    final cached = _session[_key(name)];
    if (cached != null) return cached.scale(kcal);

    if (!SupabaseService.isReady || !SupabaseService.isSignedIn) return null;

    try {
      final res = await SupabaseService.client.functions
          .invoke(
            _kFunctionName,
            body: {
              'mode': 'macros',
              'dish': name,
              'kcal': kcal,
              'lang': lang,
            },
          )
          .timeout(_kTimeout);

      if (res.status != 200) {
        if (kDebugMode) {
          debugPrint('[MacroLookup] status ${res.status}: ${res.data}');
        }
        return null;
      }
      final data = res.data;
      if (data is! Map) return null;

      final usage = data['_usage'];
      if (usage is Map) {
        lastUsage = (
          input: (usage['input_tokens'] as num?)?.round(),
          output: (usage['output_tokens'] as num?)?.round(),
        );
      }

      final m = data['macros'];
      if (m is! Map) return null;
      final p = (m['protein_g'] as num?)?.toDouble();
      final f = (m['fat_g'] as num?)?.toDouble();
      final c = (m['carbs_g'] as num?)?.toDouble();
      if (p == null || f == null || c == null) return null;
      if (p < 0 || f < 0 || c < 0) return null;
      // All three zero is indistinguishable from "unknown" downstream, so it
      // is treated as a failed lookup rather than written as a real answer.
      if (p == 0 && f == 0 && c == 0) return null;

      final ratio = _MacroRatio(p / kcal, f / kcal, c / kcal);
      _session[_key(name)] = ratio;
      unawaited(_saveDisk());
      return Macros(protein: p, fat: f, carbs: c);
    } catch (e) {
      if (kDebugMode) debugPrint('[MacroLookup] lookup failed: $e');
      return null;
    }
  }
}
