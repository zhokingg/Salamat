import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/manual_entry/manual_entry_sheet.dart';
import '../../screens/onboarding/widgets.dart' show CountUp;
import '../../theme/dimensions.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';

const List<_MealView> _kMealViews = [
  _MealView(type: MealType.breakfast),
  _MealView(type: MealType.lunch),
  _MealView(type: MealType.dinner),
];

class _MealView {
  const _MealView({required this.type});
  final MealType type;
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final Animation<double> _ringAnim;

  @override
  void initState() {
    super.initState();
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _ringAnim = CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic);
    _ringCtrl.forward();
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final user = ref.watch(userProvider);
    final mealsAsync = ref.watch(mealsProvider);

    // Three explicit states — an empty flash-render is not allowed:
    //  loading → skeleton; error → local data + offline banner with Retry;
    //  data → normal content.
    return mealsAsync.when(
      loading: () => _Skeleton(),
      error: (_, __) =>
          _buildContent(context, loc, user, const MealsState(), offline: true),
      data: (meals) =>
          _buildContent(context, loc, user, meals, offline: false),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations loc,
    UserState user,
    MealsState meals, {
    required bool offline,
  }) {
    final norm = user.calorieNorm ?? 2000;
    final name = user.name.isNotEmpty ? user.name : loc.dashboardGuestName;
    final consumed = meals.totalKcalAll;
    final overflow = consumed > norm;
    final left = norm - consumed;
    final progress = norm == 0 ? 0.0 : (consumed / norm).clamp(0.0, 1.0);

    final localeTag = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final dateLine = _capitalize(DateFormat('EEEE, d MMMM', localeTag).format(now));

    // Most recently added entry across all meal slots (visual only).
    final allEntries =
        MealType.values.expand((t) => meals.forType(t)).toList();
    final lastEntry = allEntries.isEmpty ? null : allEntries.last;

    // A day only counts toward the streak with at least one logged meal.
    final streak = allEntries.isEmpty ? 0 : 1;

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDims.tabBarHeight + 40,
      ),
      children: [
        if (offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _OfflineBanner(
              onRetry: () => ref.invalidate(mealsProvider),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.dashboardGreeting(name),
                style: GoogleFonts.manrope(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: SalamatTokens.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLine,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SalamatTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _WeekStrip(today: now, localeTag: localeTag),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CaloriesCard(
            ringAnim: _ringAnim,
            progress: progress,
            overflow: overflow,
            norm: norm,
            left: left,
            protein: meals.totalProtein,
            fat: meals.totalFat,
            carbs: meals.totalCarbs,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          // IntrinsicHeight gives the stretch a FINITE height to fill.
          // A bare stretch-Row inside a ListView asks its children for
          // infinite height -> layout exception -> the whole dashboard
          // subtree never paints ("dead Home").
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _StreakCard(days: streak)),
                const SizedBox(width: 12),
                Expanded(child: _LastMealCard(entry: lastEntry)),
              ],
            ),
          ),
        ),
        if (allEntries.isEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => showManualEntrySheet(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SalamatTokens.accentDeep,
                  side: const BorderSide(
                      color: SalamatTokens.accent, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(SalamatTokens.radiusCta),
                  ),
                ),
                child: Text(
                  loc.manualAddButton,
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  loc.dashboardMeals,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SalamatTokens.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showManualEntrySheet(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  loc.manualAddButton,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SalamatTokens.accentDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < _kMealViews.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _MealCard(
              type: _kMealViews[i].type,
              entries: meals.forType(_kMealViews[i].type),
              totalKcal: meals.totalKcal(_kMealViews[i].type),
              onTap: () => showManualEntrySheet(
                context,
                initialMealType: _kMealViews[i].type,
              ),
            ),
          ),
          if (i != _kMealViews.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Loading skeleton — soft surface-colored blocks mirroring the real layout,
/// so the dashboard never flash-renders empty data.
class _Skeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget box(double h, {double r = SalamatTokens.radiusCard}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: SalamatTokens.surface,
            borderRadius: BorderRadius.circular(r),
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FractionallySizedBox(
                widthFactor: 0.55,
                child: box(26, r: 8),
              ),
              const SizedBox(height: 8),
              FractionallySizedBox(
                widthFactor: 0.35,
                child: box(14, r: 6),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: box(52, r: SalamatTokens.radiusPill),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: box(340, r: SalamatTokens.radiusHero),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: box(72)),
              const SizedBox(width: 12),
              Expanded(child: box(72)),
            ],
          ),
        ),
        const SizedBox(height: 28),
        for (var i = 0; i < 3; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: box(64),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// Offline banner: the backend is unreachable, the numbers below come from
/// local data (profile from onboarding). Retry re-fires the meals load.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: SalamatTokens.surfaceAlt,
        borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
      ),
      child: Row(
        children: [
          SalamatIcon(
            PhosphorIcons.wifiSlash(),
            size: 18,
            color: SalamatTokens.amber,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.dashboardOffline,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: SalamatTokens.textPrimary,
                height: 1.2,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              loc.retryButton,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: SalamatTokens.accentDeep,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current-week calendar strip: Mon–Sun day chips, today filled with accent.
/// Visual only — days are not tappable (no per-day history view yet).
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today, required this.localeTag});

  final DateTime today;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final letterFmt = DateFormat.E(localeTag);
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: _DayChip(
              date: monday.add(Duration(days: i)),
              isToday: i == today.weekday - 1,
              letterFmt: letterFmt,
            ),
          ),
          if (i != 6) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.isToday,
    required this.letterFmt,
  });

  final DateTime date;
  final bool isToday;
  final DateFormat letterFmt;

  @override
  Widget build(BuildContext context) {
    final letter = letterFmt.format(date).replaceAll('.', '').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isToday ? SalamatTokens.accentDeep : SalamatTokens.surface,
        borderRadius: BorderRadius.circular(SalamatTokens.radiusPill),
      ),
      child: Column(
        children: [
          Text(
            letter,
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isToday
                  ? SalamatTokens.onAccent.withValues(alpha: 0.85)
                  : SalamatTokens.textMuted,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${date.day}',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isToday
                  ? SalamatTokens.onAccent
                  : SalamatTokens.textPrimary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cream "Calories budget" card: full calorie ring (accent fill on the beige
/// track, white disc in the centre) with the remaining value large (w600),
/// and three macro mini-bars underneath.
class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({
    required this.ringAnim,
    required this.progress,
    required this.overflow,
    required this.norm,
    required this.left,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final Animation<double> ringAnim;
  final double progress;
  final bool overflow;
  final int norm;
  final int left;
  final double protein;
  final double fat;
  final double carbs;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final statusLabel =
        left >= 0 ? loc.dashboardLeftLabel : loc.dashboardOverflowLabel;
    final numberColor =
        left >= 0 ? SalamatTokens.textPrimary : SalamatTokens.danger;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: SalamatTokens.card(radius: SalamatTokens.radiusHero),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.dashboardCaloriesBudget,
            style: GoogleFonts.manrope(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: SalamatTokens.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 188,
              height: 188,
              child: AnimatedBuilder(
                animation: ringAnim,
                builder: (context, _) {
                  final p = progress * ringAnim.value;
                  return CustomPaint(
                    painter: _RingPainter(progress: p, overflow: overflow),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CountUp(
                            value: left.abs(),
                            style: GoogleFonts.manrope(
                              fontSize: 44,
                              fontWeight: FontWeight.w600,
                              color: numberColor,
                              height: 1.0,
                              letterSpacing: -1.0,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            statusLabel,
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: SalamatTokens.textMuted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loc.dashboardConsumedOfNorm(norm),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: SalamatTokens.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 18),
          _MacroBars(protein: protein, fat: fat, carbs: carbs, norm: norm),
        ],
      ),
    );
  }
}

/// Full calorie ring: beige track, accent progress (danger on overflow),
/// white disc in the centre for the numerals to sit on.
class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.overflow});

  final double progress;
  final bool overflow;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 16.0;
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: side - stroke,
      height: side - stroke,
    );

    // White inner disc — the numerals sit on a clean layer.
    final disc = Paint()
      ..color = SalamatTokens.surfaceAlt
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, side / 2 - stroke, disc);

    final track = Paint()
      ..color = SalamatTokens.ringTrack
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);

    if (progress <= 0) return;

    final fg = Paint()
      ..color = overflow ? SalamatTokens.danger : SalamatTokens.accent
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.overflow != overflow;
}

/// Three macro mini-bars. Display targets are derived from the calorie norm
/// with a standard 30/30/40 split (visual reference only, not stored).
class _MacroBars extends StatelessWidget {
  const _MacroBars({
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.norm,
  });

  final double protein;
  final double fat;
  final double carbs;
  final int norm;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final proteinTarget = norm * 0.30 / 4; // g
    final fatTarget = norm * 0.30 / 9; // g
    final carbsTarget = norm * 0.40 / 4; // g
    return Row(
      children: [
        Expanded(
          child: _MacroBar(
            label: loc.dashboardMacroProtein,
            value: protein,
            target: proteinTarget,
            unit: loc.gramsUnit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroBar(
            label: loc.dashboardMacroFat,
            value: fat,
            target: fatTarget,
            unit: loc.gramsUnit,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MacroBar(
            label: loc.dashboardMacroCarbs,
            value: carbs,
            target: carbsTarget,
            unit: loc.gramsUnit,
          ),
        ),
      ],
    );
  }
}

class _MacroBar extends StatelessWidget {
  const _MacroBar({
    required this.label,
    required this.value,
    required this.target,
    required this.unit,
  });

  final String label;
  final double value;
  final double target;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final fill = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${value.round()} $unit',
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: SalamatTokens.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(
              children: [
                Container(color: SalamatTokens.ringTrack),
                FractionallySizedBox(
                  widthFactor: fill,
                  child: Container(color: SalamatTokens.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: SalamatTokens.textMuted,
          ),
        ),
      ],
    );
  }
}

/// White level-2 card with the flame sticker and the streak line.
class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      decoration: SalamatTokens.card(color: SalamatTokens.surfaceAlt),
      child: Row(
        children: [
          SalamatIcon.flame(size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.dashboardStreakLine(days),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalamatTokens.textPrimary,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White level-2 card with the most recent diary entry (name + kcal, food
/// illustration). Empty state invites the first camera snap.
class _LastMealCard extends StatelessWidget {
  const _LastMealCard({required this.entry});

  final MealEntry? entry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    if (entry == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        decoration: SalamatTokens.card(color: SalamatTokens.surfaceAlt),
        child: Row(
          children: [
            SalamatIcon(
              PhosphorIcons.camera(PhosphorIconsStyle.duotone),
              size: 22,
              color: SalamatTokens.accent,
              bubbleColor: SalamatTokens.bubbleMint,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.dashboardSnapFirstMeal,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SalamatTokens.textMuted,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.centerLeft,
      decoration: SalamatTokens.card(color: SalamatTokens.surfaceAlt),
      child: Row(
        children: [
          FoodIllustration.forDish(entry!.name, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  loc.dashboardLastMeal,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: SalamatTokens.textMuted,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry!.name,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: SalamatTokens.textPrimary,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  loc.dashboardKcalWithValue(entry!.kcal),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: SalamatTokens.textMuted,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.type,
    required this.entries,
    required this.totalKcal,
    required this.onTap,
  });

  final MealType type;
  final List<MealEntry> entries;
  final int totalKcal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final empty = entries.isEmpty;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SalamatTokens.card(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SalamatIcon(
                  type.icon,
                  size: 20,
                  color: SalamatTokens.accentDeep,
                  bubbleColor: SalamatTokens.bubbleMint,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label(loc),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SalamatTokens.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: SalamatTokens.pill(),
                  child: Text(
                    loc.dashboardKcalWithValue(totalKcal),
                    style: GoogleFonts.manrope(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: totalKcal == 0
                          ? SalamatTokens.textMuted
                          : SalamatTokens.pillText,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            if (empty) ...[
              const SizedBox(height: 10),
              Text(
                loc.dashboardEmptyMeal,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: SalamatTokens.textMuted,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(height: 1, color: SalamatTokens.ringTrack),
              const SizedBox(height: 10),
              for (var i = 0; i < entries.length; i++) ...[
                _EntryRow(entry: entries[i]),
                if (i != entries.length - 1) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry});

  final MealEntry entry;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FoodIllustration.forDish(entry.name, size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                entry.name,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: SalamatTokens.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                loc.gramsSuffix(entry.grams.round()),
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: SalamatTokens.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Text(
            '${entry.kcal}',
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SalamatTokens.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}


/// Meal-slot icons (Duotone) — replaces the old emoji markers.
extension _MealTypeIcon on MealType {
  PhosphorIconData get icon => switch (this) {
        MealType.breakfast =>
          PhosphorIcons.sunHorizon(PhosphorIconsStyle.duotone),
        MealType.lunch => PhosphorIcons.sun(PhosphorIconsStyle.duotone),
        MealType.dinner =>
          PhosphorIcons.moonStars(PhosphorIconsStyle.duotone),
        MealType.snack => PhosphorIcons.cookie(PhosphorIconsStyle.duotone),
      };
}
