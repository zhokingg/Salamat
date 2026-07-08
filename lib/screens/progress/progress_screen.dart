import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../theme/colors.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import '../../theme/dimensions.dart';

const Color _kProteinColor = SalamatColors.g2;
const Color _kFatColor = SalamatColors.warn;
const Color _kCarbsColor = Color(0xFF7BB3E8);

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _HistoryDay {
  const _HistoryDay(this.label, this.date, this.kcal);
  final String label;
  final String date;
  final int kcal;
}

class _ProgressScreenState extends ConsumerState<ProgressScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1)
        .chain(CurveTween(curve: Curves.easeInOut))
        .animate(_pulseCtrl);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final meals = ref.watch(mealsProvider).valueOrNull ?? const MealsState();

    final norm = user.calorieNorm ?? 2000;
    final consumed = meals.totalKcalAll;
    final proteinConsumed = meals.totalProtein;
    final fatConsumed = meals.totalFat;
    final carbsConsumed = meals.totalCarbs;

    final proteinNorm = norm * 0.3 / 4;
    final fatNorm = norm * 0.3 / 9;
    final carbsNorm = norm * 0.4 / 4;

    // Real history. Meals are tracked for the current session only (no
    // multi-day persistence yet), so the only day we can show truthfully is
    // today — and only once the user has actually logged something. A new
    // user sees an empty state and a streak of 0. Past days will populate
    // here once a persisted history feed exists.
    final loggedToday = consumed > 0;
    final streak = loggedToday ? 1 : 0;
    final history = <_HistoryDay>[
      if (loggedToday)
        _HistoryDay(
          loc.progressDayToday,
          MaterialLocalizations.of(context).formatShortMonthDay(DateTime.now()),
          consumed,
        ),
    ];
    final maxKcal = history.map((d) => d.kcal).fold<int>(
          1,
          (a, b) => a > b ? a : b,
        );

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDims.tabBarHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Text(
            loc.progressTitle,
            style: GoogleFonts.manrope(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: SalamatColors.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StreakCard(streak: streak, pulse: _pulse),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Text(
            loc.progressToday,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SalamatColors.i3,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StatsGrid(
            consumed: consumed,
            norm: norm,
            protein: proteinConsumed,
            proteinNorm: proteinNorm,
            fat: fatConsumed,
            fatNorm: fatNorm,
            carbs: carbsConsumed,
            carbsNorm: carbsNorm,
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Text(
            loc.progressHistory,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SalamatColors.i3,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: SalamatColors.surf,
              borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
              border: Border.all(color: SalamatColors.line),
            ),
            child: history.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 20,
                    ),
                    child: Text(
                      loc.progressHistoryEmpty,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: SalamatColors.i3,
                        height: 1.4,
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < history.length; i++) ...[
                        _HistoryRow(day: history[i], maxKcal: maxKcal),
                        if (i != history.length - 1)
                          Container(
                            height: 1,
                            color: SalamatColors.line,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                      ],
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak, required this.pulse});

  final int streak;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    const goal = 7;
    final progress = (streak / goal).clamp(0.0, 1.0);
    final completed = (streak - 1).clamp(0, goal - 1);
    final todayIdx = streak > 0 ? completed : -1;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              streak > 0
                  ? SalamatIcon.flame(size: 22)
                  : SalamatIcon(
                      PhosphorIcons.plant(PhosphorIconsStyle.duotone),
                      size: 22,
                      color: SalamatTokens.accent,
                      bubbleColor: SalamatTokens.bubbleMint,
                    ),
              const SizedBox(width: 10),
              Text(
                streak > 0
                    ? loc.progressStreak(streak)
                    : loc.progressStreakStart,
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SalamatColors.ink,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            streak > 0 ? loc.progressNextGoal : loc.progressStreakStartHint,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: SalamatColors.i3,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: SalamatColors.g4,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(SalamatColors.g2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < goal; i++)
                _StreakDot(
                  state: i < completed
                      ? _DotState.done
                      : i == todayIdx
                          ? _DotState.today
                          : _DotState.empty,
                  pulse: pulse,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _DotState { done, today, empty }

class _StreakDot extends StatelessWidget {
  const _StreakDot({required this.state, required this.pulse});

  final _DotState state;
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    Widget circle;
    switch (state) {
      case _DotState.done:
        circle = Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: SalamatColors.g1,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            size: 16,
            color: SalamatColors.surf,
          ),
        );
        break;
      case _DotState.today:
        circle = ScaleTransition(
          scale: pulse,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: SalamatColors.g2,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: SalamatColors.g2.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
        break;
      case _DotState.empty:
        circle = Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: SalamatColors.line, width: 2),
          ),
        );
        break;
    }
    return SizedBox(width: 32, height: 32, child: Center(child: circle));
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({
    required this.consumed,
    required this.norm,
    required this.protein,
    required this.proteinNorm,
    required this.fat,
    required this.fatNorm,
    required this.carbs,
    required this.carbsNorm,
  });

  final int consumed;
  final int norm;
  final double protein;
  final double proteinNorm;
  final double fat;
  final double fatNorm;
  final double carbs;
  final double carbsNorm;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _CaloriesStatCard(consumed: consumed, norm: norm),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroStatCard(
                value: protein,
                norm: proteinNorm,
                label: loc.progressMacroProtein,
                color: _kProteinColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MacroStatCard(
                value: fat,
                norm: fatNorm,
                label: loc.progressMacroFat,
                color: _kFatColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MacroStatCard(
                value: carbs,
                norm: carbsNorm,
                label: loc.progressMacroCarbs,
                color: _kCarbsColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CaloriesStatCard extends StatelessWidget {
  const _CaloriesStatCard({required this.consumed, required this.norm});

  final int consumed;
  final int norm;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final progress = norm == 0 ? 0.0 : (consumed / norm).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$consumed',
                  style: GoogleFonts.manrope(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.progressOfNormKcal(norm),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: SalamatColors.i3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: CustomPaint(
              painter: _MiniRingPainter(progress: progress),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroStatCard extends StatelessWidget {
  const _MacroStatCard({
    required this.value,
    required this.norm,
    required this.label,
    required this.color,
  });

  final double value;
  final double norm;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final progress = norm == 0 ? 0.0 : (value / norm).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatDims.buttonRadius),
        border: Border.all(color: SalamatColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${value.round()}',
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: SalamatColors.ink,
              letterSpacing: -0.6,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              color: SalamatColors.i3,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: SalamatColors.g4,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRingPainter extends CustomPainter {
  _MiniRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final bg = Paint()
      ..color = const Color(0xFFF0F4EE)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);

    if (progress <= 0) return;

    final gradient = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: const [SalamatColors.g1, SalamatColors.g2],
    );
    final fg = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _MiniRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.day, required this.maxKcal});

  final _HistoryDay day;
  final int maxKcal;

  @override
  Widget build(BuildContext context) {
    final ratio = maxKcal == 0 ? 0.0 : (day.kcal / maxKcal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  day.label,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  day.date,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: SalamatColors.i3,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 80,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: SalamatColors.g4,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      SalamatColors.g2,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 64,
            child: Text(
              '${day.kcal}',
              textAlign: TextAlign.right,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalamatColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
