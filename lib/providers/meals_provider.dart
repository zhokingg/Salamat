import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'bootstrap_provider.dart';

/// Meal slot. Display labels come from AppLocalizations via the extension
/// below — the enum itself only carries the emoji (purely visual, locale-agnostic).
enum MealType {
  breakfast('🌅'),
  lunch('☀️'),
  dinner('🌙'),
  snack('🥪');

  const MealType(this.emoji);

  final String emoji;
}

extension MealTypeLoc on MealType {
  String label(AppLocalizations loc) => switch (this) {
        MealType.breakfast => loc.mealBreakfast,
        MealType.lunch => loc.mealLunch,
        MealType.dinner => loc.mealDinner,
        MealType.snack => loc.mealSnack,
      };

  String labelLower(AppLocalizations loc) => switch (this) {
        MealType.breakfast => loc.mealBreakfastLower,
        MealType.lunch => loc.mealLunchLower,
        MealType.dinner => loc.mealDinnerLower,
        MealType.snack => loc.mealSnackLower,
      };
}

class MealEntry {
  const MealEntry({
    required this.id,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final String id;
  final String name;
  final double grams;
  final int kcal;
  final double protein;
  final double fat;
  final double carbs;
}

class MealsState {
  const MealsState({this.entries = const {}});

  final Map<MealType, List<MealEntry>> entries;

  List<MealEntry> forType(MealType type) => entries[type] ?? const [];

  int totalKcal(MealType type) =>
      forType(type).fold(0, (sum, e) => sum + e.kcal);

  int get totalKcalAll =>
      MealType.values.fold(0, (sum, t) => sum + totalKcal(t));

  double _macroSum(double Function(MealEntry) pick) => MealType.values
      .expand((t) => forType(t))
      .fold(0.0, (sum, e) => sum + pick(e));

  double get totalProtein => _macroSum((e) => e.protein);
  double get totalFat => _macroSum((e) => e.fat);
  double get totalCarbs => _macroSum((e) => e.carbs);

  MealsState copyWithAdded(MealType type, MealEntry entry) {
    final next = Map<MealType, List<MealEntry>>.from(entries);
    final list = List<MealEntry>.from(next[type] ?? const []);
    list.add(entry);
    next[type] = list;
    return MealsState(entries: next);
  }
}

/// Today's meals, persisted in Supabase.
///
/// `build` waits for [bootstrapProvider] (Supabase init + anonymous sign-in)
/// before loading, so reads/writes always run against a real `auth.uid()`.
class MealsNotifier extends AsyncNotifier<MealsState> {
  @override
  Future<MealsState> build() async {
    // Gate on bootstrap: never touch the network before the session exists.
    await ref.watch(bootstrapProvider.future);
    final rows = await SupabaseService.getTodayFoodLogs();
    return _fromRows(rows);
  }

  /// Adds a meal. The UI updates optimistically, then the row is persisted.
  /// Signature is unchanged so existing call sites (camera, portion sheet)
  /// keep working — they fire-and-forget this future.
  Future<void> add(MealType type, MealEntry entry) async {
    final current = state.valueOrNull ?? const MealsState();
    state = AsyncData(current.copyWithAdded(type, entry));
    await SupabaseService.logFood(
      foodName: entry.name,
      calories: entry.kcal,
      proteinG: entry.protein,
      carbsG: entry.carbs,
      fatG: entry.fat,
      portionG: entry.grams,
      mealType: type.name,
    );
  }

  /// Re-reads today's meals from Supabase (e.g. after returning to a screen).
  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final rows = await SupabaseService.getTodayFoodLogs();
      return _fromRows(rows);
    });
  }

  static MealsState _fromRows(List<Map<String, dynamic>> rows) {
    final entries = <MealType, List<MealEntry>>{};
    for (final row in rows) {
      final type = _typeFromDb(row['meal_type']);
      if (type == null) continue;
      (entries[type] ??= <MealEntry>[]).add(
        MealEntry(
          id: row['id']?.toString() ?? '',
          name: row['name']?.toString() ?? '',
          grams: _toDouble(row['grams']),
          kcal: _toInt(row['kcal']),
          protein: _toDouble(row['protein']),
          fat: _toDouble(row['fat']),
          carbs: _toDouble(row['carbs']),
        ),
      );
    }
    return MealsState(entries: entries);
  }

  static MealType? _typeFromDb(Object? raw) => switch (raw?.toString()) {
        'breakfast' => MealType.breakfast,
        'lunch' => MealType.lunch,
        'dinner' => MealType.dinner,
        'snack' => MealType.snack,
        _ => null,
      };

  static double _toDouble(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0;
  }

  static int _toInt(Object? v) {
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

final mealsProvider =
    AsyncNotifierProvider<MealsNotifier, MealsState>(MealsNotifier.new);
