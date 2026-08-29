import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

/// An inclusive min–max band.
///
/// Every nutrition number coming out of `suggest-meal` is a band, never a
/// point: the model is guessing portion size, fat content and cooking method
/// from a free-text ingredient list, and a single number would present that
/// guess as a measurement.
@immutable
class NutrientRange {
  const NutrientRange(this.min, this.max);

  final int min;
  final int max;

  /// What goes into the diary when the user picks the dish. The midpoint is
  /// the only defensible single value to derive from a band.
  int get mid => ((min + max) / 2).round();

  int get spread => max - min;

  static NutrientRange? fromJson(Object? v) {
    if (v is! Map) return null;
    final lo = (v['min'] as num?)?.round();
    final hi = (v['max'] as num?)?.round();
    if (lo == null && hi == null) return null;
    final a = lo ?? hi!;
    final b = hi ?? lo!;
    return NutrientRange(a <= b ? a : b, a <= b ? b : a);
  }
}

/// How a suggestion sits against what is left of the day.
///
/// Three-valued on purpose. With a band, "does it fit" genuinely has a maybe:
/// collapsing that into yes/no would throw away the uncertainty the band
/// exists to carry.
enum BudgetFit {
  /// Even the top of the band stays inside the remainder.
  fits,

  /// The band straddles the remainder — it depends how the portion lands.
  borderline,

  /// Even the bottom of the band goes over.
  over,
}

@immutable
class SuggestionIngredient {
  const SuggestionIngredient({required this.name, required this.amount});

  final String name;

  /// Free-form, as the model phrased it: "120 г", "2 шт".
  final String amount;
}

@immutable
class MealSuggestion {
  const MealSuggestion({
    required this.name,
    required this.kcal,
    this.protein,
    this.fat,
    this.carbs,
    this.timeMinutes,
    this.ingredients = const [],
    this.steps = const [],
  });

  final String name;
  final NutrientRange kcal;
  final NutrientRange? protein;
  final NutrientRange? fat;
  final NutrientRange? carbs;
  final int? timeMinutes;
  final List<SuggestionIngredient> ingredients;
  final List<String> steps;

  /// Verdict against the calorie remainder. Macros are shown but do not
  /// decide the badge — calories are the budget the user is tracking.
  BudgetFit fitFor(int remainingKcal) {
    if (kcal.max <= remainingKcal) return BudgetFit.fits;
    if (kcal.min <= remainingKcal) return BudgetFit.borderline;
    return BudgetFit.over;
  }

  static MealSuggestion? fromJson(Map<String, dynamic> j) {
    final name = (j['name'] as String?)?.trim();
    final kcal = NutrientRange.fromJson(j['kcal']);
    if (name == null || name.isEmpty || kcal == null) return null;
    return MealSuggestion(
      name: name,
      kcal: kcal,
      protein: NutrientRange.fromJson(j['protein_g']),
      fat: NutrientRange.fromJson(j['fat_g']),
      carbs: NutrientRange.fromJson(j['carbs_g']),
      timeMinutes: (j['time_minutes'] as num?)?.round(),
      ingredients: [
        for (final i in (j['ingredients'] as List?) ?? const [])
          if (i is Map && (i['name'] as String?)?.trim().isNotEmpty == true)
            SuggestionIngredient(
              name: (i['name'] as String).trim(),
              amount: (i['amount'] as String?)?.trim() ?? '',
            ),
      ],
      steps: [
        for (final s in (j['steps'] as List?) ?? const [])
          if (s is String && s.trim().isNotEmpty) s.trim(),
      ],
    );
  }
}

/// What the caller needs to know when a request fails, so the screen can say
/// something specific instead of a generic error.
enum SuggestionFailure { notConfigured, network, server, empty }

class SuggestionException implements Exception {
  const SuggestionException(this.kind);
  final SuggestionFailure kind;
}

/// Calls the `suggest-meal` Edge Function.
///
/// Mirrors [PhotoRecognitionService]: the Anthropic key stays server-side, the
/// client only ever talks to Supabase.
class MealSuggestionService {
  MealSuggestionService._();

  static const String _kFunctionName = 'suggest-meal';

  /// Last token usage reported by the function, for the cost readout. Null
  /// until a call succeeds against a deployed function that returns `_usage`.
  static ({int? input, int? output})? lastUsage;

  static Future<List<MealSuggestion>> suggest({
    required List<String> ingredients,
    required int remainingKcal,
    double? remainingProtein,
    double? remainingFat,
    double? remainingCarbs,
    String? goal,
    required String lang,
  }) async {
    if (!SupabaseService.isReady) {
      throw const SuggestionException(SuggestionFailure.notConfigured);
    }
    try {
      final res = await SupabaseService.client.functions.invoke(
        _kFunctionName,
        body: {
          'ingredients': ingredients,
          'remaining': {
            'kcal': remainingKcal,
            if (remainingProtein != null) 'protein_g': remainingProtein,
            if (remainingFat != null) 'fat_g': remainingFat,
            if (remainingCarbs != null) 'carbs_g': remainingCarbs,
          },
          if (goal != null) 'goal': goal,
          'lang': lang,
        },
      );
      if (res.status != 200) {
        if (kDebugMode) {
          debugPrint('suggestMeal status ${res.status}: ${res.data}');
        }
        throw const SuggestionException(SuggestionFailure.server);
      }
      final data = res.data;
      final map = data is Map<String, dynamic>
          ? data
          : throw const SuggestionException(SuggestionFailure.server);

      final usage = map['_usage'];
      if (usage is Map) {
        lastUsage = (
          input: (usage['input_tokens'] as num?)?.round(),
          output: (usage['output_tokens'] as num?)?.round(),
        );
      }

      final out = <MealSuggestion>[];
      for (final s in (map['suggestions'] as List?) ?? const []) {
        if (s is Map<String, dynamic>) {
          final parsed = MealSuggestion.fromJson(s);
          if (parsed != null) out.add(parsed);
        }
      }
      if (out.isEmpty) {
        throw const SuggestionException(SuggestionFailure.empty);
      }
      return out;
    } on SuggestionException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('suggestMeal error: $e');
      throw const SuggestionException(SuggestionFailure.network);
    }
  }
}
