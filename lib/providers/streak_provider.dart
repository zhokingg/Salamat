import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/supabase_service.dart';
import 'meals_provider.dart';
import 'selected_date_provider.dart';
import 'session_provider.dart';

/// Consecutive local calendar days with at least one logged meal, counting
/// back from today — or from yesterday when nothing is logged yet today, so
/// the number does not drop to 0 at breakfast time and come back at lunch.
///
/// [eatenAt] are the instants meals were eaten, in any zone; each is bucketed
/// into the local day it falls in via [toLocal] (injectable for tests, since
/// the test host's zone is not Bishkek). A day is "logged" when at least one
/// instant falls in it; nothing else — not the calorie target, not a
/// complete set of slots — is required.
///
/// Returns 0 when neither today nor yesterday has a meal.
int computeStreak(
  Iterable<DateTime> eatenAt, {
  required DateTime now,
  DateTime Function(DateTime) toLocal = _toLocal,
}) {
  final logged = <DateTime>{
    for (final at in eatenAt) startOfDay(toLocal(at)),
  };
  if (logged.isEmpty) return 0;

  var day = startOfDay(toLocal(now));
  if (!logged.contains(day)) {
    day = day.subtract(const Duration(days: 1));
    if (!logged.contains(day)) return 0;
  }

  var n = 0;
  while (logged.contains(day)) {
    n++;
    // Calendar arithmetic, not Duration: a DST shift would make
    // `subtract(Duration(days: 1))` land at 23:00 of the same day.
    day = DateTime(day.year, day.month, day.day - 1);
  }
  return n;
}

DateTime _toLocal(DateTime d) => d.toLocal();

/// The streak shown on Home, Profile and Progress.
///
/// Derived from `meals` rows every time, never stored: a stored counter has
/// to be maintained from every write path and drifts the first time one is
/// missed (which is how the previous "streak" was a constant 1). Recomputed
/// when the provider is first read after app start and whenever
/// [mealsRevisionProvider] changes — i.e. after every meal write — and NOT
/// when the home screen moves to another day: the selected day has no bearing
/// on the streak.
///
/// The query is timestamps only (see [SupabaseService.getMealTimestampsSince])
/// over a window that starts at [kStreakInitialWindowDays] and widens only
/// while the streak reaches the window's edge, so a typical user costs a few
/// hundred bytes and a year-long streak is still counted in full.
final streakProvider = FutureProvider<int>((ref) async {
  await awaitSession(ref);
  ref.watch(mealsRevisionProvider);

  final now = DateTime.now();
  var windowDays = kStreakInitialWindowDays;
  while (true) {
    final since = DateTime(now.year, now.month, now.day - (windowDays - 1));
    final stamps = await SupabaseService.getMealTimestampsSince(since);
    final streak = computeStreak(stamps, now: now);
    // The streak can only be longer than what we fetched if it runs all the
    // way to the oldest day in the window (today or yesterday may be
    // unlogged, hence `- 1`).
    final reachesEdge = streak >= windowDays - 1;
    if (!reachesEdge || windowDays >= kStreakMaxWindowDays) return streak;
    windowDays *= 4;
  }
});

/// 90 days covers everyone but the very dedicated with one round trip.
const int kStreakInitialWindowDays = 90;

/// Ten years. A streak longer than this is reported as this.
const int kStreakMaxWindowDays = 3650;
