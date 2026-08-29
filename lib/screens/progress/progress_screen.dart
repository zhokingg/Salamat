import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/history_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/weight_provider.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart' show SalamatCard, SalamatEyebrow;

/// Progress, rebuilt to the prototype's analytics screen.
///
/// Everything here is derived from rows that already exist in `meals` and
/// `weight_logs` — [historyProvider] widens the existing `eaten_at` query
/// instead of adding columns. Nothing is estimated: where a number cannot be
/// computed the card shows an empty state.
///
/// The prototype's Eaten / Burned / Net row is deliberately absent: "Burned"
/// needs activity data the app does not collect, and deriving it from a
/// formula would put an invented number on screen.
class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final range = ref.watch(historyRangeProvider);
    final async = ref.watch(historyProvider);
    final user = ref.watch(userProvider);

    return ListView(
      padding: const EdgeInsets.only(
        top: 56,
        bottom: SalamatDarkDims.navHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: Text(
            loc.progressTitle,
            style: SalamatDarkType.h2.copyWith(color: c.text),
          ),
        ),
        const SizedBox(height: SalamatDarkDims.gap20),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: _RangeSwitcher(
            selected: range,
            onSelect: (r) => ref.read(historyRangeProvider.notifier).set(r),
          ),
        ),
        const SizedBox(height: SalamatDarkDims.gap20),
        ...switch (async) {
          AsyncLoading() => [
              const Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: SalamatDarkDims.screenPadH,
                ),
                child: _HistorySkeleton(),
              ),
            ],
          AsyncError() => [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SalamatDarkDims.screenPadH,
                ),
                child: SalamatCard(
                  child: Text(
                    loc.progressHistoryEmpty,
                    style: SalamatDarkType.captionL.copyWith(color: c.text3),
                  ),
                ),
              ),
            ],
          AsyncValue(:final value?) => _cards(context, loc, value, user),
          _ => const <Widget>[],
        },
      ],
    );
  }

  List<Widget> _cards(
    BuildContext context,
    AppLocalizations loc,
    HistoryStats stats,
    UserState user,
  ) {
    const pad = EdgeInsets.symmetric(
      horizontal: SalamatDarkDims.screenPadH,
    );
    final logs = ref.watch(weightLogsProvider).valueOrNull ?? const [];
    return [
      Padding(padding: pad, child: _TrendCard(stats: stats)),
      const SizedBox(height: SalamatDarkDims.gap16),
      Padding(padding: pad, child: _WeightCard(user: user, logs: logs)),
      const SizedBox(height: SalamatDarkDims.gap16),
      Padding(padding: pad, child: _ScoreCards(stats: stats)),
      const SizedBox(height: SalamatDarkDims.gap20),
      Padding(padding: pad, child: _ConsistencyMap(stats: stats)),
      if (user.targetWeight != null && user.weight != null) ...[
        const SizedBox(height: SalamatDarkDims.gap20),
        Padding(padding: pad, child: _Milestones(user: user)),
      ],
    ];
  }
}

/// Segmented range control: `padding: 4`, radius 16 on `--surface-2`, the
/// active pill on `--surface` with `--shadow-1`.
class _RangeSwitcher extends StatelessWidget {
  const _RangeSwitcher({required this.selected, required this.onSelect});

  final HistoryRange selected;
  final ValueChanged<HistoryRange> onSelect;

  String _label(AppLocalizations loc, HistoryRange r) => switch (r) {
        HistoryRange.day => loc.progressRangeDay,
        HistoryRange.week => loc.progressRangeWeek,
        HistoryRange.month => loc.progressRangeMonth,
        HistoryRange.year => loc.progressRangeYear,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(SalamatDarkDims.gap4),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rField),
      ),
      child: Row(
        children: [
          for (final r in HistoryRange.values) ...[
            if (r != HistoryRange.values.first)
              const SizedBox(width: SalamatDarkDims.gap4),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelect(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: r == selected ? c.surface : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rIcon36),
                    boxShadow: r == selected ? c.shadow1 : null,
                  ),
                  child: Text(
                    _label(loc, r),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: SalamatDarkType.caption.copyWith(
                      color: r == selected ? c.text : c.text3,
                      fontWeight: SalamatDarkType.medium,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Calorie trend: one bar per bucket, height relative to the tallest bucket,
/// a `--line-2` goal line with its label, `--warn` for over-target days and
/// `--primary` for the newest bucket.
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.stats});

  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final buckets = stats.chartBuckets;
    final peak = buckets.fold<int>(0, (a, b) => math.max(a, b.kcal));
    final goal = stats.bucketGoal;
    final scale = math.max(peak, goal).toDouble();
    final anyData = peak > 0;

    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  loc.progressCalorieTrend,
                  style: SalamatDarkType.captionL.copyWith(
                    color: c.text,
                    fontWeight: SalamatDarkType.semi,
                    height: null,
                  ),
                ),
              ),
              if (anyData)
                Text(
                  loc.progressDailyAvg(stats.dailyAverageKcal),
                  style: SalamatDarkType.captionXs.copyWith(color: c.text3),
                ),
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap16),
          if (!anyData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  loc.progressNoRangeData,
                  textAlign: TextAlign.center,
                  style: SalamatDarkType.caption.copyWith(color: c.text3),
                ),
              ),
            )
          else
            SizedBox(
              height: SalamatDarkDims.chartHeight,
              child: LayoutBuilder(
                builder: (context, box) {
                  final plot = box.maxHeight - 26;
                  final goalY = scale <= 0 ? 0.0 : plot * (goal / scale);
                  return Stack(
                    children: [
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 26 + goalY,
                        child: Container(height: 1, color: c.line2),
                      ),
                      Positioned(
                        right: 0,
                        // Sits above the line, but flips below it when the
                        // line is near the top of the plot, so the label is
                        // never clipped out of the chart box.
                        bottom: goalY > plot - 16
                            ? 26 + goalY - 14
                            : 26 + goalY + 3,
                        child: Text(
                          loc.progressGoalLine(goal),
                          style: SalamatDarkType.eyebrowS.copyWith(
                            color: c.text3,
                            fontSize: 9.5,
                            letterSpacing: 0.04 * 9.5,
                          ),
                        ),
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < buckets.length; i++) ...[
                            if (i > 0) const SizedBox(width: 3),
                            Expanded(
                              child: _Bar(
                                bucket: buckets[i],
                                isLast: i == buckets.length - 1,
                                goal: goal,
                                scale: scale,
                                plot: plot,
                                label: _bucketLabel(context, buckets[i]),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  String _bucketLabel(BuildContext context, DayTotals b) {
    final tag = Localizations.localeOf(context).toString();
    return switch (stats.range) {
      // A single day gets no axis label — the card title carries the context.
      HistoryRange.day => '',
      HistoryRange.week => _weekdayShort(context, b.date),
      // 30 bars cannot all be labelled; every fifth day carries the date.
      HistoryRange.month => b.date.day % 5 == 0 ? '${b.date.day}' : '',
      HistoryRange.year => _monthShort(tag, b.date),
    };
  }

  static String _weekdayShort(BuildContext context, DateTime d) =>
      MaterialLocalizations.of(context).narrowWeekdays[d.weekday % 7];

  static String _monthShort(String localeTag, DateTime d) =>
      DateTime(d.year, d.month).month.toString();
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.bucket,
    required this.isLast,
    required this.goal,
    required this.scale,
    required this.plot,
    required this.label,
  });

  final DayTotals bucket;
  final bool isLast;
  final int goal;
  final double scale;
  final double plot;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final over = bucket.kcal > goal;
    final h = scale <= 0 ? 0.0 : (plot * (bucket.kcal / scale));
    final color = !bucket.logged
        ? c.surface3
        : over
            ? c.warn
            : isLast
                ? c.primary
                : c.primary.withValues(alpha: 0.28);
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: math.max(bucket.logged ? 4 : 3, h)),
          duration: const Duration(milliseconds: 500),
          curve: SalamatDarkDims.ease,
          builder: (_, v, __) => Container(
            width: double.infinity,
            height: v,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rBar),
            ),
          ),
        ),
        SizedBox(
          height: 26,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: SalamatDarkDims.gap6),
              child: Text(
                label,
                maxLines: 1,
                style: SalamatDarkType.eyebrowS.copyWith(
                  color: isLast ? c.text : c.text3,
                  fontSize: 10.5,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Weight card: current weight against the goal plus the logged trend line.
/// Draws only real weigh-ins; with fewer than two points the line is omitted.
class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.user, required this.logs});

  final UserState user;
  final List<WeightLog> logs;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    // weightLogsProvider is ordered oldest -> newest.
    final current = logs.isNotEmpty ? logs.last.kg : user.weight;
    final goal = user.targetWeight;
    if (current == null) {
      return SalamatCard(
        radius: SalamatDarkDims.rHero,
        child: Text(
          loc.dashboardWeightFirstLog,
          style: SalamatDarkType.captionL.copyWith(color: c.text3),
        ),
      );
    }
    final delta =
        logs.length >= 2 ? logs.last.kg - logs.first.kg : null;
    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  loc.dashboardWeightTitle,
                  style: SalamatDarkType.captionL.copyWith(
                    color: c.text,
                    fontWeight: SalamatDarkType.semi,
                    height: null,
                  ),
                ),
              ),
              if (delta != null)
                Text(
                  loc.dashboardWeightSinceStart(delta.toStringAsFixed(1)),
                  style: SalamatDarkType.captionXs.copyWith(
                    color: delta <= 0 ? c.primaryInk : c.warn,
                    fontWeight: SalamatDarkType.semi,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                current.toStringAsFixed(1),
                style: SalamatDarkType.numXl.copyWith(color: c.text),
              ),
              const SizedBox(width: SalamatDarkDims.gap10),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  goal == null
                      ? loc.profileKgShort
                      : '${loc.profileKgShort} · '
                          '${loc.planTarget.toLowerCase()} '
                          '${goal.toStringAsFixed(0)}',
                  style: SalamatDarkType.caption.copyWith(color: c.text3),
                ),
              ),
            ],
          ),
          if (logs.length >= 2) ...[
            const SizedBox(height: SalamatDarkDims.gap14),
            SizedBox(
              height: SalamatDarkDims.weightChartHeight,
              width: double.infinity,
              child: CustomPaint(
                painter: _WeightLinePainter(
                  values: logs.map((e) => e.kg).toList(),
                  goal: goal,
                  line: c.primary,
                  guide: c.line2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightLinePainter extends CustomPainter {
  _WeightLinePainter({
    required this.values,
    required this.goal,
    required this.line,
    required this.guide,
  });

  final List<double> values;
  final double? goal;
  final Color line;
  final Color guide;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final lo = values.reduce(math.min);
    final hi = values.reduce(math.max);
    final span = (hi - lo).abs() < 0.5 ? 1.0 : hi - lo;
    double y(double v) => size.height - ((v - lo) / span) * (size.height - 8) - 4;
    final dx = size.width / (values.length - 1);

    // Goal guide: dashed, only when it falls inside the plotted band.
    final g = goal;
    if (g != null && g >= lo - span && g <= hi + span) {
      final gp = Paint()
        ..color = guide
        ..strokeWidth = 1.5;
      final gy = y(g).clamp(0.0, size.height);
      for (var x = 0.0; x < size.width; x += 11) {
        canvas.drawLine(Offset(x, gy), Offset(x + 4, gy), gp);
      }
    }

    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx * i, y(values[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(size.width, y(values.last)),
      4,
      Paint()..color = line,
    );
  }

  @override
  bool shouldRepaint(covariant _WeightLinePainter old) =>
      old.values != values || old.goal != goal;
}

/// Two score cards: protein adherence and the logging streak.
class _ScoreCards extends StatelessWidget {
  const _ScoreCards({required this.stats});

  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final score = stats.proteinScore;
    // IntrinsicHeight gives `stretch` a finite height to fill. A bare
    // stretch-Row inside a ListView asks its children for infinite height and
    // takes the rest of the list down with it.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ScoreCard(
              label: loc.progressProteinScore,
              color: c.primary,
              value: score == null ? loc.valueDash : '$score',
              sub: loc.progressProteinScoreSub(
                stats.proteinDaysOnTarget,
                stats.loggedDayCount,
              ),
            ),
          ),
          const SizedBox(width: SalamatDarkDims.gap12),
          Expanded(
            child: _ScoreCard(
              label: loc.progressConsistencyLabel,
              color: c.secondary,
              value: '${stats.streak}',
              sub: loc.progressConsistencySub,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SalamatCard(
      padding: const EdgeInsets.all(SalamatDarkDims.padCardTight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SalamatEyebrow(label, color: color),
          const SizedBox(height: SalamatDarkDims.gap8),
          Text(value, style: SalamatDarkType.numM.copyWith(color: c.text)),
          const SizedBox(height: SalamatDarkDims.gap8),
          Text(
            sub,
            style: SalamatDarkType.micro.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}

/// Consistency heat map: one cell per day in the range, intensity by how close
/// the day came to the calorie norm. Untouched days stay `--surface-3`.
class _ConsistencyMap extends StatelessWidget {
  const _ConsistencyMap({required this.stats});

  final HistoryStats stats;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    // The prototype draws a 28-cell grid at 10.5 % width; the range decides
    // how many days we actually have to show.
    final days = stats.days.length > 28
        ? stats.days.sublist(stats.days.length - 28)
        : stats.days;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SalamatEyebrow(loc.progressConsistencyLabel),
        const SizedBox(height: SalamatDarkDims.gap10),
        LayoutBuilder(
          builder: (context, box) {
            const perRow = 9;
            final cell = (box.maxWidth - (perRow - 1) * 4) / perRow;
            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final d in days)
                  Container(
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: _cellColor(c, d),
                      borderRadius:
                          BorderRadius.circular(SalamatDarkDims.rCell),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Color _cellColor(SalamatColorsDark c, DayTotals d) {
    if (!d.logged) return c.surface3;
    final ratio = stats.calorieNorm == 0 ? 0.0 : d.kcal / stats.calorieNorm;
    if (ratio > 1.1) return c.warn;
    if (ratio >= 0.8) return c.primary;
    return c.primarySoft;
  }
}

/// Weekly milestones: the projected weight path at a steady 0.5 kg a week,
/// the same rate the plan screen already commits to. Shown only when both the
/// current and the target weight exist.
class _Milestones extends StatelessWidget {
  const _Milestones({required this.user});

  final UserState user;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final from = user.weight!;
    final to = user.targetWeight!;
    final losing = to < from;
    final step = losing ? -0.5 : 0.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SalamatEyebrow(loc.progressWeeklyMilestones),
        const SizedBox(height: SalamatDarkDims.gap10),
        Row(
          children: [
            for (var w = 1; w <= 4; w++) ...[
              if (w > 1) const SizedBox(width: SalamatDarkDims.gap8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: SalamatDarkDims.gap12,
                    horizontal: SalamatDarkDims.gap4,
                  ),
                  decoration: BoxDecoration(
                    color: w == 1 ? c.primarySoft : c.surface2,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rField),
                  ),
                  child: Column(
                    children: [
                      Text(
                        loc.progressMilestoneWeek(w),
                        style: SalamatDarkType.eyebrowS.copyWith(
                          color: c.text3,
                          fontSize: 10.5,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: SalamatDarkDims.gap5),
                      Text(
                        _clamp(from + step * w, from, to).toStringAsFixed(1),
                        style: SalamatDarkType.bodyM.copyWith(
                          color: w == 1 ? c.primary : c.text,
                          fontWeight: SalamatDarkType.semi,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Never project past the goal.
  static double _clamp(double v, double from, double to) =>
      to < from ? math.max(v, to) : math.min(v, to);
}

/// Shimmer placeholder matching the card rhythm above.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        for (final h in [180.0, 150.0, 90.0]) ...[
          Container(
            height: h,
            decoration: BoxDecoration(
              color: c.skeletonBase,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rHero),
            ),
          ),
          const SizedBox(height: SalamatDarkDims.gap16),
        ],
      ],
    );
  }
}
