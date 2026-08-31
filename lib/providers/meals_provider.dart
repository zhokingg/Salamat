import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/macro_lookup_service.dart';
import '../services/supabase_service.dart';
import 'bootstrap_provider.dart';

/// Meal slot. Display labels come from AppLocalizations via the extension
/// below — visuals (icons) live in the UI layer.
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;


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
    this.source = '',
    this.eatenAt,
  });

  final String id;
  final String name;
  final double grams;
  final int kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// How the entry was created: 'photo' | 'manual'. Client-side only for
  /// now — persisting it needs a `source` column migration in `meals`
  /// (Supabase intentionally untouched); rows loaded from the DB carry ''.
  final String source;

  /// When the entry was eaten — display only, populated from the DB row;
  /// entries created this session carry null until reloaded.
  final DateTime? eatenAt;

  /// Same entry with a macro breakdown filled in. Used only by the
  /// background lookup; id, grams, kcal and `eatenAt` are untouched.
  MealEntry withMacros({
    required double protein,
    required double fat,
    required double carbs,
  }) =>
      MealEntry(
        id: id,
        name: name,
        grams: grams,
        kcal: kcal,
        protein: protein,
        fat: fat,
        carbs: carbs,
        source: source,
        eatenAt: eatenAt,
      );

  /// Whether this entry carries a real macro breakdown.
  ///
  /// There is no longer any kcal-split estimate: a row either has macros that
  /// were entered or looked up, or it has none and every screen renders a dash.
  /// Rows written before the lookup existed carry 0/0/0 and read as unknown.
  bool get hasMacros => protein > 0 || fat > 0 || carbs > 0;
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
      id: entry.id,
      foodName: entry.name,
      calories: entry.kcal,
      proteinG: entry.protein,
      carbsG: entry.carbs,
      fatG: entry.fat,
      portionG: entry.grams,
      mealType: type.name,
    );
  }

  /// Adds a meal and, when no macros were typed in, fills them in afterwards
  /// from [MacroLookupService].
  ///
  /// The save is never blocked on the lookup: [add] completes (and the sheet
  /// closes) first, the entry appears immediately, and the macros land later
  /// via [updateEntry], which keeps the row id and `eaten_at`. If the lookup
  /// fails the entry simply stays without macros and the UI shows a dash —
  /// nothing is invented and no zeros are written as if measured.
  ///
  /// Manual logging remains free; this path never touches the photo quota.
  Future<void> addWithMacroBackfill(
    MealType type,
    MealEntry entry,
    String lang,
  ) async {
    await add(type, entry);
    if (entry.hasMacros) return;

    final macros = await MacroLookupService.lookup(
      dish: entry.name,
      kcal: entry.kcal,
      lang: lang,
    );
    if (macros == null) return;

    // The row may have been deleted or edited while the lookup was in flight.
    final current = state.valueOrNull;
    if (current == null) return;
    final live = current
        .forType(type)
        .where((e) => e.id == entry.id)
        .cast<MealEntry?>()
        .firstWhere((e) => true, orElse: () => null);
    if (live == null || live.hasMacros) return;

    await updateEntry(
      type,
      live.withMacros(
        protein: macros.protein,
        fat: macros.fat,
        carbs: macros.carbs,
      ),
    );
  }

  /// Drops one entry, optimistically then on the server.
  Future<void> remove(MealType type, String id) async {
    final current = state.valueOrNull ?? const MealsState();
    final next = Map<MealType, List<MealEntry>>.from(current.entries);
    next[type] = (next[type] ?? const [])
        .where((e) => e.id != id)
        .toList(growable: false);
    state = AsyncData(MealsState(entries: next));
    await SupabaseService.deleteFoodLog(id);
  }

  /// Rescales one entry in place. Keeps the row id and `eaten_at`.
  Future<void> updateEntry(MealType type, MealEntry entry) async {
    final current = state.valueOrNull ?? const MealsState();
    final next = Map<MealType, List<MealEntry>>.from(current.entries);
    next[type] = [
      for (final e in next[type] ?? const <MealEntry>[])
        if (e.id == entry.id) entry else e,
    ];
    state = AsyncData(MealsState(entries: next));
    await SupabaseService.updateFoodLog(
      id: entry.id,
      portionG: entry.grams,
      calories: entry.kcal,
      proteinG: entry.protein,
      carbsG: entry.carbs,
      fatG: entry.fat,
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
          eatenAt:
              DateTime.tryParse(row['eaten_at']?.toString() ?? '')?.toLocal(),
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
