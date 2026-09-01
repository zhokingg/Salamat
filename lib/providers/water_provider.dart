import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/supabase_service.dart';
import '../services/user_prefs.dart';
import 'session_provider.dart';

/// One tap of the water button.
const int kWaterSipMl = 250;

/// Daily goal used to fill the pips. Not a stored preference — `profiles`
/// gains `water_goal_ml` in migration 0004, which is not applied yet, so the
/// UI uses this constant until that column exists.
const int kWaterGoalMl = 2000;

/// How many pips the row draws.
const int kWaterPips = 8;

/// Today's water intake.
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

  /// Millilitres logged today, oldest first. Kept as a list rather than a sum
  /// so the last sip can be taken back.
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
    await awaitSession(ref);
    final rows = await SupabaseService.getTodayWater();
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
    // device copy for today.
    return WaterState(
      entries: await _loadLocal(),
      synced: false,
      loading: false,
    );
  }

  /// Local copy is scoped to a single calendar day: a stored entry from
  /// yesterday must not leak into today's total.
  Future<List<int>> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kPrefsKey);
      if (raw == null) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];
      if (decoded['day'] != _todayKey()) return const [];
      return [
        for (final v in (decoded['ml'] as List? ?? const []))
          if (v is num) v.round(),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _saveLocal(List<int> entries) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsKey,
        jsonEncode({'day': _todayKey(), 'ml': entries}),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('water local save failed: $e');
    }
  }

  static String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Logs one sip. Updates the UI first, then tries the server.
  Future<void> add([int ml = kWaterSipMl]) async {
    final current = state.valueOrNull ?? const WaterState();
    final next = [...current.entries, ml];
    state = AsyncData(current.copyWith(entries: next, loading: false));

    final ok = await SupabaseService.logWater(ml);
    if (!ok) await _saveLocal(next);
    final after = state.valueOrNull ?? const WaterState();
    state = AsyncData(after.copyWith(synced: ok));
  }

  /// Takes back the most recent sip.
  ///
  /// Server-side this deletes the newest row rather than a row we are holding
  /// an id for, because the local fallback has no ids at all and both paths
  /// have to behave the same.
  Future<void> undo() async {
    final current = state.valueOrNull ?? const WaterState();
    if (current.entries.isEmpty) return;
    final next = current.entries.sublist(0, current.entries.length - 1);
    state = AsyncData(current.copyWith(entries: next));

    final ok = await SupabaseService.deleteLatestWater();
    if (!ok) await _saveLocal(next);
    final after = state.valueOrNull ?? const WaterState();
    state = AsyncData(after.copyWith(synced: ok));
  }
}

final waterProvider =
    AsyncNotifierProvider<WaterNotifier, WaterState>(WaterNotifier.new);
