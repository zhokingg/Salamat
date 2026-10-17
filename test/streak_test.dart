// The streak is a count of consecutive LOCAL calendar days with a meal.
//
// Pure function, no network. Zone handling is checked with an injected
// UTC→local conversion rather than the host's zone, because the host is not
// in Bishkek and the two dangerous cases are in opposite directions:
//   * UTC+6 (Bishkek): 01:00 local is 19:00Z the previous day — bucketing by
//     UTC would move the meal back a day;
//   * UTC−5: 23:30 local is 04:30Z the next day — bucketing by UTC would move
//     it forward a day.

import 'package:flutter_test/flutter_test.dart';

import 'package:salamat/providers/streak_provider.dart';

DateTime d(int day, [int hour = 12, int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

final DateTime now = d(17, 20); // 17 Oct 2026, 20:00 local

/// Local instants, identity conversion.
int streakOf(Iterable<DateTime> at) =>
    computeStreak(at, now: now, toLocal: (x) => x);

void main() {
  group('computeStreak', () {
    test('four days in a row ending today → 4', () {
      expect(streakOf([d(14), d(15), d(16), d(17)]), 4);
    });

    test('several meals on one day count once', () {
      expect(streakOf([d(16, 8), d(16, 13), d(16, 20), d(17, 9)]), 2);
    });

    test('a gap cuts the streak: 14, 15, (16 missing), 17 → 1', () {
      expect(streakOf([d(14), d(15), d(17)]), 1);
    });

    test('three days with a gap before them: 12, 13, 15, 16, 17 → 3', () {
      expect(streakOf([d(12), d(13), d(15), d(16), d(17)]), 3);
    });

    test('nothing yet today: the run ending yesterday still counts', () {
      expect(streakOf([d(14), d(15), d(16)]), 3);
    });

    test('nothing today or yesterday → 0', () {
      expect(streakOf([d(13), d(14), d(15)]), 0);
    });

    test('no meals at all → 0', () {
      expect(streakOf(const []), 0);
    });

    test('does not require anything beyond one meal (no target check)', () {
      // One tiny meal a day for four days is a four-day streak.
      expect(streakOf([d(14, 23, 59), d(15, 0, 1), d(16), d(17)]), 4);
    });

    test('order of the input does not matter', () {
      expect(streakOf([d(17), d(15), d(16), d(14)]), 4);
    });
  });

  group('local day boundaries, not UTC', () {
    // Bishkek: UTC+6. A meal at 01:00 local on the 17th is 19:00Z on the 16th.
    DateTime bishkek(DateTime utc) => utc.add(const Duration(hours: 6));

    test('UTC+6: a 01:00 local meal belongs to the local day', () {
      final meals = [
        DateTime.utc(2026, 10, 15, 19, 0), // 16 Oct 01:00 Bishkek
        DateTime.utc(2026, 10, 17, 6, 0), // 17 Oct 12:00 Bishkek
      ];
      final nowUtc = DateTime.utc(2026, 10, 17, 14, 0); // 17 Oct 20:00 Bishkek
      expect(computeStreak(meals, now: nowUtc, toLocal: bishkek), 2);
      expect(
        computeStreak(meals, now: nowUtc, toLocal: (x) => x),
        1,
        reason: 'bucketed by UTC the first meal lands on the 15th and the '
            '16th is empty — the streak breaks. This is what the fix removes.',
      );
    });

    // A zone west of Greenwich, where the late-evening case bites.
    DateTime west(DateTime utc) => utc.subtract(const Duration(hours: 5));

    test('UTC−5: a 23:30 local meal counts for the local day, not the next',
        () {
      final meals = [
        DateTime.utc(2026, 10, 17, 4, 30), // 16 Oct 23:30 local (UTC−5)
        DateTime.utc(2026, 10, 18, 4, 30), // 17 Oct 23:30 local
      ];
      final nowUtc = DateTime.utc(2026, 10, 18, 4, 45); // 17 Oct 23:45 local
      expect(computeStreak(meals, now: nowUtc, toLocal: west), 2);
    });

    test('a meal just after local midnight starts the new day', () {
      expect(streakOf([d(16, 23, 50), d(17, 0, 10)]), 2);
    });
  });

  group('countLoggedDays (days in the app)', () {
    int daysOf(Iterable<DateTime> at) =>
        countLoggedDays(at, toLocal: (x) => x);

    test('distinct days, gaps do not matter: 1, 2, 9, 17 → 4', () {
      expect(daysOf([d(1), d(2), d(9), d(17)]), 4);
      // The same instants are a streak of 1 — the two numbers differ.
      expect(streakOf([d(1), d(2), d(9), d(17)]), 1);
    });

    test('several meals on one day count once', () {
      expect(daysOf([d(5, 8), d(5, 13), d(5, 20)]), 1);
    });

    test('today need not be logged', () {
      expect(daysOf([d(3), d(4)]), 2);
    });

    test('no meals → 0', () {
      expect(daysOf(const []), 0);
    });

    test('bucketed by local day, not UTC', () {
      DateTime bishkek(DateTime utc) => utc.add(const Duration(hours: 6));
      final meals = [
        DateTime.utc(2026, 10, 15, 19, 0), // 16 Oct 01:00 Bishkek
        DateTime.utc(2026, 10, 16, 6, 0), // 16 Oct 12:00 Bishkek
      ];
      expect(countLoggedDays(meals, toLocal: bishkek), 1);
      expect(countLoggedDays(meals, toLocal: (x) => x), 2,
          reason: 'by UTC these are two different days');
    });
  });
}
