import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'selected_date_provider.dart';
import 'session_provider.dart';

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

/// A meal that was typed in but did not reach the server.
///
/// Carried on the state rather than thrown, because every call site fires
/// [MealsNotifier.add] and forgets it: the sheet closes, the camera pops, and
/// there is nobody left holding the future to catch anything.
class MealWriteFailure {
  const MealWriteFailure({required this.dish, required this.at});

  final String dish;

  /// Distinguishes two failures of the same dish, so the second one is shown
  /// too instead of looking like a state that never changed.
  final DateTime at;
}

class MealsState {
  const MealsState({this.entries = const {}, this.writeFailure});

  final Map<MealType, List<MealEntry>> entries;

  /// Set when the last write was rolled back. Read once by the listener that
  /// shows the message; nothing else depends on it.
  final MealWriteFailure? writeFailure;

  List<MealEntry> forType(MealType type) => entries[type] ?? const [];

  int totalKcal(MealType type) =>
      forType(type).fold(0, (sum, e) => sum + e.kcal);

  int get totalKcalAll =>
      MealType.values.fold(0, (sum, t) => sum + totalKcal(t));

  Iterable<MealEntry> get _all => MealType.values.expand((t) => forType(t));

  /// Entries whose macros are actually known. The day's macro totals are
  /// sums over these only: an entry logged with calories alone is not "0 g
  /// protein", it is unknown, and must not pull a total toward zero.
  Iterable<MealEntry> get _withMacros => _all.where((e) => e.hasMacros);

  /// False when no entry of the day has a macro breakdown — the totals are
  /// then not "0 g" but unknown, and the macro bars render a dash.
  bool get hasAnyMacros => _withMacros.isNotEmpty;

  double _macroSum(double Function(MealEntry) pick) =>
      _withMacros.fold(0.0, (sum, e) => sum + pick(e));

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

  /// Removes one entry by id, wherever it is.
  MealsState copyWithRemoved(MealType type, String id) {
    final next = Map<MealType, List<MealEntry>>.from(entries);
    next[type] =
        (next[type] ?? const []).where((e) => e.id != id).toList();
    return MealsState(entries: next, writeFailure: writeFailure);
  }

  MealsState withFailure(MealWriteFailure? failure) =>
      MealsState(entries: entries, writeFailure: failure);
}

/// The meals of whichever day the home screen is showing, persisted in
/// Supabase. Defaults to today — see [selectedDateProvider].
///
/// `build` waits for [bootstrapProvider] (Supabase init + anonymous sign-in)
/// before loading, so reads/writes always run against a real `auth.uid()`.
class MealsNotifier extends AsyncNotifier<MealsState> {
  /// Days already loaded this session, by local midnight. Moving back to a
  /// day the person has already looked at is served from here with no
  /// request; every write keeps its day's entry current, so the cache is
  /// never behind what the server has. Keyed by account via [_cacheUid]:
  /// a sign-in or sign-out empties it, so one account never sees another's
  /// days. Lives on the notifier, which Riverpod keeps across rebuilds.
  final Map<DateTime, MealsState> _cache = {};
  String? _cacheUid;

  @override
  Future<MealsState> build() async {
    // Watched BEFORE the first await, so the dependency is registered
    // synchronously and picking another day rebuilds this provider.
    final day = ref.watch(selectedDateProvider);
    // Gate on bootstrap: never touch the network before the session exists.
    final uid = await awaitSession(ref);
    if (uid != _cacheUid) {
      _cache.clear();
      _cacheUid = uid;
    }
    final cached = _cache[day];
    if (cached != null) return cached;
    final rows = await SupabaseService.getFoodLogsForDay(day);
    return _cache[day] = _fromRows(rows);
  }

  /// Publishes [next] as the state and as [day]'s cached copy. [day] is the
  /// day the operation started on, captured by the caller — the person may
  /// have moved to another day while a write was in flight.
  void _set(DateTime day, MealsState next) {
    state = AsyncData(next);
    _cache[day] = next;
  }

  /// Timestamp to write for a new entry on the selected day.
  ///
  /// Null on today, so the row keeps the column default and records the real
  /// moment. On a past day there is no real moment to record, so the entry is
  /// stamped at local noon — safely inside the day whichever way the UTC
  /// offset (or a DST shift) falls.
  DateTime? _stampForSelectedDay() {
    final day = ref.read(selectedDateProvider);
    if (isToday(day)) return null;
    return DateTime(day.year, day.month, day.day, 12);
  }

  /// Adds a meal. The UI updates optimistically, then the row is persisted.
  /// Signature is unchanged so existing call sites (camera, portion sheet)
  /// keep working — they fire-and-forget this future.
  Future<bool> add(MealType type, MealEntry entry) async {
    final day = ref.read(selectedDateProvider);
    final current = state.valueOrNull ?? const MealsState();
    _set(day, current.copyWithAdded(type, entry).withFailure(null));
    try {
      await SupabaseService.logFood(
        id: entry.id,
        foodName: entry.name,
        calories: entry.kcal,
        proteinG: entry.protein,
        carbsG: entry.carbs,
        fatG: entry.fat,
        portionG: entry.grams,
        mealType: type.name,
        eatenAt: _stampForSelectedDay(),
      );
      ref.read(mealsRevisionProvider.notifier).bump();
      return true;
    } catch (e) {
      // The write failed, so the optimistic entry is a lie: it would sit in
      // the day's diary, count towards the ring, and be gone after the next
      // reload with no explanation. Take it back out and say so.
      if (kDebugMode) debugPrint('logFood failed, rolling back: $e');
      final now = state.valueOrNull ?? const MealsState();
      _set(
        day,
        now.copyWithRemoved(type, entry.id).withFailure(
              MealWriteFailure(dish: entry.name, at: DateTime.now()),
            ),
      );
      return false;
    }
  }

  /// Drops one entry, optimistically then on the server.
  Future<void> remove(MealType type, String id) async {
    final day = ref.read(selectedDateProvider);
    final current = state.valueOrNull ?? const MealsState();
    final next = Map<MealType, List<MealEntry>>.from(current.entries);
    next[type] = (next[type] ?? const [])
        .where((e) => e.id != id)
        .toList(growable: false);
    _set(day, MealsState(entries: next));
    if (await SupabaseService.deleteFoodLog(id)) {
      ref.read(mealsRevisionProvider.notifier).bump();
    }
  }

  /// Rescales one entry in place. Keeps the row id and `eaten_at`.
  Future<void> updateEntry(MealType type, MealEntry entry) async {
    final day = ref.read(selectedDateProvider);
    final current = state.valueOrNull ?? const MealsState();
    final next = Map<MealType, List<MealEntry>>.from(current.entries);
    next[type] = [
      for (final e in next[type] ?? const <MealEntry>[])
        if (e.id == entry.id) entry else e,
    ];
    _set(day, MealsState(entries: next));
    final ok = await SupabaseService.updateFoodLog(
      id: entry.id,
      portionG: entry.grams,
      calories: entry.kcal,
      proteinG: entry.protein,
      carbsG: entry.carbs,
      fatG: entry.fat,
    );
    if (ok) ref.read(mealsRevisionProvider.notifier).bump();
  }

  /// Re-reads the selected day's meals from Supabase — pull-to-refresh, or
  /// after returning to a screen. Bypasses the cache and replaces its entry.
  ///
  /// The current content stays on screen while the request runs: the caller
  /// shows its own progress (the RefreshIndicator), and dropping to a
  /// loading state here would be the empty-state flash the day switch no
  /// longer has. On failure the old content is kept too; the error is logged.
  Future<void> reload() async {
    final day = ref.read(selectedDateProvider);
    try {
      final rows = await SupabaseService.getFoodLogsForDay(day);
      _set(day, _fromRows(rows));
    } catch (e) {
      if (kDebugMode) debugPrint('meals reload failed: $e');
    }
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

/// Bumped after every write to `meals` that reached the server — add, remove,
/// update — on whichever day it landed.
///
/// For anything derived from more than one day (streak, history). Those used
/// to watch [mealsProvider] itself, which also rebuilds when the home screen
/// moves to another day — a re-read that changes nothing and re-fetches
/// everything. Watching this instead means "the data changed", not "the view
/// changed".
final mealsRevisionProvider =
    NotifierProvider<MealsRevisionNotifier, int>(MealsRevisionNotifier.new);

class MealsRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}
