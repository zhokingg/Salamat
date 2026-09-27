import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Midnight, local time, of the day [d] falls in.
DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Today at midnight, local time.
DateTime today() => startOfDay(DateTime.now());

/// Which day the home screen is showing.
///
/// Every per-day provider (diary, water, weight) reads this, so switching the
/// day is one state change rather than a fan-out of manual invalidations.
/// Always a local midnight, and never in the future: [select] clamps, so no
/// caller has to remember the rule.
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => today();

  /// Moves to [d]. Days after today are clamped to today — there is nothing
  /// to show for tomorrow and nothing may be logged into it.
  void select(DateTime d) {
    final day = startOfDay(d);
    final max = today();
    state = day.isAfter(max) ? max : day;
  }

  void goToToday() => state = today();
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(SelectedDateNotifier.new);

/// True when [d] is the current calendar day, local time.
bool isToday(DateTime d) => startOfDay(d) == today();
