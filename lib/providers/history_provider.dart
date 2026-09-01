import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'session_provider.dart';
import 'meals_provider.dart';
import 'user_provider.dart';

/// Ranges the Progress screen can show, matching the prototype's segmented
/// control (`Day` / `Week` / `Month` / `Year`).
enum HistoryRange { day, week, month, year }

extension HistoryRangeX on HistoryRange {
  /// How many calendar days the range covers, today included.
  int get days => switch (this) {
        HistoryRange.day => 1,
        HistoryRange.week => 7,
        HistoryRange.month => 30,
        HistoryRange.year => 365,
      };

  /// Buckets the trend chart draws. A year is bucketed by month so the chart
  /// never tries to plot 365 bars.
  int get buckets => switch (this) {
        HistoryRange.day => 1,
        HistoryRange.week => 7,
        HistoryRange.month => 30,
        HistoryRange.year => 12,
      };
}

/// One calendar day of logged food, reduced from `meals` rows.
class DayTotals {
  const DayTotals({
    required this.date,
    this.kcal = 0,
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
    this.entries = 0,
  });

  /// Local midnight of the day this bucket covers.
  final DateTime date;
  final int kcal;
  final double protein;
  final double fat;
  final double carbs;

  /// Number of logged dishes — drives "did the user log at all" checks.
  final int entries;

  bool get logged => entries > 0;

  DayTotals plus(MealEntry e) => DayTotals(
        date: date,
        kcal: kcal + e.kcal,
        protein: protein + e.protein,
        fat: fat + e.fat,
        carbs: carbs + e.carbs,
        entries: entries + 1,
      );
}

/// Everything the Progress screen derives, computed once per range.
///
/// All of it comes from rows that already exist in `meals`; nothing here
/// invents a number. Where a value cannot be derived it is simply absent.
class HistoryStats {
  const HistoryStats({
    required this.range,
    required this.days,
    required this.calorieNorm,
  });

  final HistoryRange range;

  /// Oldest first, one entry per calendar day in the range, gaps filled with
  /// empty [DayTotals] so charts and the heat map keep a stable grid.
  final List<DayTotals> days;

  final int calorieNorm;

  Iterable<DayTotals> get logged => days.where((d) => d.logged);

  int get loggedDayCount => logged.length;

  int get totalKcal => days.fold(0, (a, d) => a + d.kcal);

  /// Mean over days that actually have entries — averaging in untouched days
  /// would understate intake.
  int get dailyAverageKcal {
    final n = loggedDayCount;
    return n == 0 ? 0 : (totalKcal / n).round();
  }

  /// Consecutive logged days counting back from today.
  int get streak {
    var n = 0;
    for (final d in days.reversed) {
      if (!d.logged) break;
      n++;
    }
    return n;
  }

  /// Protein target used for scoring: the same 30 % display split the rest of
  /// the app uses for macro bars.
  double get proteinTarget => calorieNorm * 0.30 / 4;

  /// Share of logged days that reached at least 80 % of the protein target,
  /// as a 0..100 score. Null when nothing is logged yet.
  int? get proteinScore {
    final n = loggedDayCount;
    if (n == 0) return null;
    final target = proteinTarget * 0.8;
    final hit = logged.where((d) => d.protein >= target).length;
    return (hit / n * 100).round();
  }

  /// Days that hit the protein target, over the number of logged days.
  int get proteinDaysOnTarget =>
      logged.where((d) => d.protein >= proteinTarget * 0.8).length;

  /// Chart buckets, oldest first. Day/week/month are one bucket per day;
  /// a year is grouped by calendar month.
  List<DayTotals> get chartBuckets {
    if (range != HistoryRange.year) return days;
    final byMonth = <String, DayTotals>{};
    for (final d in days) {
      final key = '${d.date.year}-${d.date.month}';
      final base = byMonth[key] ??
          DayTotals(date: DateTime(d.date.year, d.date.month));
      byMonth[key] = DayTotals(
        date: base.date,
        kcal: base.kcal + d.kcal,
        protein: base.protein + d.protein,
        fat: base.fat + d.fat,
        carbs: base.carbs + d.carbs,
        entries: base.entries + d.entries,
      );
    }
    final out = byMonth.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return out;
  }

  /// Per-bucket mean, used as the chart's goal reference for a year view where
  /// a daily norm makes no sense.
  int get bucketGoal => range == HistoryRange.year
      ? calorieNorm * 30
      : calorieNorm;
}

/// The range the user has selected on Progress.
final historyRangeProvider =
    NotifierProvider<HistoryRangeNotifier, HistoryRange>(
  HistoryRangeNotifier.new,
);

class HistoryRangeNotifier extends Notifier<HistoryRange> {
  @override
  HistoryRange build() => HistoryRange.week;

  void set(HistoryRange r) => state = r;
}

/// Food history for the selected range, bucketed by local calendar day.
final historyProvider = FutureProvider<HistoryStats>((ref) async {
  await awaitSession(ref);
  final range = ref.watch(historyRangeProvider);

  // Re-read whenever today's diary changes so a fresh log shows up here too.
  ref.watch(mealsProvider);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final since = today.subtract(Duration(days: range.days - 1));

  final rows = await SupabaseService.getFoodLogsSince(since);

  // Pre-fill the whole grid so untouched days render as gaps, not as absences.
  final grid = <DateTime, DayTotals>{};
  for (var i = 0; i < range.days; i++) {
    final d = today.subtract(Duration(days: range.days - 1 - i));
    grid[d] = DayTotals(date: d);
  }

  for (final row in rows) {
    final at = DateTime.tryParse(row['eaten_at']?.toString() ?? '')?.toLocal();
    if (at == null) continue;
    final key = DateTime(at.year, at.month, at.day);
    final bucket = grid[key];
    if (bucket == null) continue;
    grid[key] = bucket.plus(
      MealEntry(
        id: row['id']?.toString() ?? '',
        name: row['name']?.toString() ?? '',
        grams: _d(row['grams']),
        kcal: _i(row['kcal']),
        protein: _d(row['protein']),
        fat: _d(row['fat']),
        carbs: _d(row['carbs']),
        eatenAt: at,
      ),
    );
  }

  final days = grid.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return HistoryStats(
    range: range,
    days: days,
    // Watched, so editing the goal recomputes every derived score.
    calorieNorm: ref.watch(userProvider).calorieNorm ?? 2000,
  );
});

double _d(Object? v) => v is num ? v.toDouble() : 0;
int _i(Object? v) => v is num ? v.toInt() : 0;
