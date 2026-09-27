import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import '../services/user_prefs.dart';
import 'selected_date_provider.dart';
import 'session_provider.dart';

/// One tap of the water button.
const int kWaterSipMl = 250;

/// Daily goal used to fill the pips. Not a stored preference — `profiles`
/// gains `water_goal_ml` in migration 0004, which is not applied yet, so the
/// UI uses this constant until that column exists.
const int kWaterGoalMl = 2000;

/// How many pips the row draws.
const int kWaterPips = 8;

/// Water intake for the day the home screen is showing.
///
/// `water_logs` arrives with migration 0004, which has NOT been applied. Until
/// it is, every write fails with a missing-table error; rather than showing a
/// broken button, the day's total is kept on the device and [synced] reports
/// false so the UI can say so. Once the migration lands the same code path
/// starts persisting server-side with no further change.
class WaterState {
  const WaterState({
    this.entries = const [],
    this.synced = true,
    this.loading = true,
  });

  /// Millilitres logged on the selected day, oldest first. Kept as a list
  /// rather than a sum so the last sip can be taken back.
  final List<int> entries;

  /// False when the server rejected the write and the value is device-only.
  final bool synced;

  final bool loading;

  int get totalMl => entries.fold(0, (a, b) => a + b);

  double get fraction =>
      kWaterGoalMl == 0 ? 0 : (totalMl / kWaterGoalMl).clamp(0.0, 1.0);

  /// Pips filled, rounded down so a partially-filled pip never reads as full.
  int get filledPips => (fraction * kWaterPips).floor();

  bool get canUndo => entries.isNotEmpty;

  WaterState copyWith({
    List<int>? entries,
    bool? synced,
    bool? loading,
  }) =>
      WaterState(
        entries: entries ?? this.entries,
        synced: synced ?? this.synced,
        loading: loading ?? this.loading,
      );
}

class WaterNotifier extends AsyncNotifier<WaterState> {
  /// Per account — see [userScopedKey]. The old shared key meant the fallback
  /// copy followed the device, not the person.
  static String get _kPrefsKey => userScopedKey('water_local_today');

  @override
  Future<WaterState> build() async {
    // Watched before the first await so switching the day rebuilds this.
    final day = ref.watch(selectedDateProvider);
    await awaitSession(ref);
    final rows = await SupabaseService.getWaterForDay(day);
    if (rows != null) {
      return WaterState(
        entries: [
          for (final r in rows)
            if ((r['amount_ml'] as num?) != null)
              (r['amount_ml'] as num).round(),
        ],
        synced: true,
        loading: false,
      );
    }
    // Table absent (migration pending) or read failed — fall back to the
    // device copy for that day.
    return WaterState(
      entries: await _loadLocal(day),
      synced: false,
      loading: false,
    );
  }

  /// The local fallback keeps one bucket PER DAY, so a past day shows its own
  /// total and yesterday's entries never leak into today's.
  ///
  /// The old single-bucket shape was not history: it stored one day's list
  /// under a day stamp and threw it away as soon as the stamp did not match.
  /// Buckets are pruned to [_kLocalDaysKept] days so the blob cannot grow
  /// without bound.
  static const int _kLocalDaysKept = 30;

  Future<Map<String, dynamic>> _readLocalMap() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      // Migrate the old {'day': ..., 'ml': [...]} shape into a day-keyed map.
      if (decoded['ml'] is List && decoded['day'] is String) {
        return {decoded['day'] as String: decoded['ml']};
      }
      return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return {};
    }
  }

  Future<List<int>> _loadLocal(DateTime day) async {
    final map = await _readLocalMap();
    final list = map[_dayKey(day)];
    if (list is! List) return const [];
    return [
      for (final v in list)
        if (v is num) v.round(),
    ];
  }

  Future<void> _saveLocal(DateTime day, List<int> entries) async {
    try {
      final map = await _readLocalMap();
      map[_dayKey(day)] = entries;
      final keys = map.keys.toList()..sort();
      while (keys.length > _kLocalDaysKept) {
        map.remove(keys.removeAt(0));
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrefsKey, jsonEncode(map));
    } catch (e) {
      if (kDebugMode) debugPrint('water local save failed: $e');
    }
  }

  /// Sortable, so pruning by "oldest first" is a plain string sort.
  static String _dayKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Local noon on a past day — inside the day whichever way the UTC offset
  /// falls. Null on today, so the row keeps the real moment.
  DateTime? _stampForSelectedDay(DateTime day) =>
      isToday(day) ? null : DateTime(day.year, day.month, day.day, 12);

  /// Logs one sip against the selected day. Updates the UI first, then tries
  /// the server.
  Future<void> add([int ml = kWaterSipMl]) async {
    final day = ref.read(selectedDateProvider);
    final current = state.valueOrNull ?? const WaterState();
    final next = [...current.entries, ml];
    state = AsyncData(current.copyWith(entries: next, loading: false));

    final ok = await SupabaseService.logWater(
      ml,
      loggedAt: _stampForSelectedDay(day),
    );
    if (!ok) await _saveLocal(day, next);
    final after = state.valueOrNull ?? const WaterState();
    state = AsyncData(after.copyWith(synced: ok));
  }

  /// Takes back the most recent sip.
  ///
  /// Server-side this deletes the newest row rather than a row we are holding
  /// an id for, because the local fallback has no ids at all and both paths
  /// have to behave the same.
  Future<void> undo() async {
    final day = ref.read(selectedDateProvider);
    final current = state.valueOrNull ?? const WaterState();
    if (current.entries.isEmpty) return;
    final next = current.entries.sublist(0, current.entries.length - 1);
    state = AsyncData(current.copyWith(entries: next));

    final ok = await SupabaseService.deleteLatestWater(day: day);
    if (!ok) await _saveLocal(day, next);
    final after = state.valueOrNull ?? const WaterState();
    state = AsyncData(after.copyWith(synced: ok));
  }
}

final waterProvider =
    AsyncNotifierProvider<WaterNotifier, WaterState>(WaterNotifier.new);
