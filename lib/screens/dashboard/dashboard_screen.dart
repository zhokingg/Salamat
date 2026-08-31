import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/meals_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/user_provider.dart';
import '../../providers/water_provider.dart';
import '../../providers/weight_provider.dart';
import '../../screens/manual_entry/manual_entry_sheet.dart';
import '../../widgets/update_weight_dialog.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_dark.dart';
import '../onboarding/widgets.dart';

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
    // Pull the authoritative scan counts once the tree is up, so the counter
    // above the camera button is real rather than a client guess.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(subscriptionProvider.notifier).refreshFromServer();
    });
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
    final greeting = user.name.trim().isNotEmpty
        ? loc.dashboardGreeting(user.name.trim())
        : loc.dashboardGreetingNoName;
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

    // Macro totals for the bars: stored values only, never an estimate, so
    // this agrees with `MealsState.totalProtein` (which the cook budget uses)
    // and with the protein score in Progress. An entry whose macros are not
    // known yet contributes nothing rather than a guess.
    var protein = 0.0, fat = 0.0, carbs = 0.0;
    for (final e in allEntries) {
      protein += e.protein;
      fat += e.fat;
      carbs += e.carbs;
    }

    // A day only counts toward the streak with at least one logged meal.
    final streak = allEntries.isEmpty ? 0 : 1;

    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDarkDims.navHeight + 40,
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
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: SalamatDarkType.style(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: sc.text,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                dateLine,
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: sc.text2,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: _WeekStrip(today: now, localeTag: localeTag),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: _CaloriesCard(
            ringAnim: _ringAnim,
            progress: progress,
            overflow: overflow,
            norm: norm,
            left: left,
            protein: protein,
            fat: fat,
            carbs: carbs,
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
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
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: const _CoachCard(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: const _WaterCard(),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: _WeightCard(
            weight: user.weight,
            logs: ref.watch(weightLogsProvider).valueOrNull ?? const [],
            onAdd: () => showUpdateWeightDialog(context, ref),
          ),
        ),
        if (left > 0) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
            child: _SnackIdeaCard(kcalLeft: left),
          ),
        ],
        if (allEntries.isEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => showManualEntrySheet(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: sc.primary,
                  side:  BorderSide(
                      color: sc.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rButton),
                  ),
                ),
                child: Text(
                  loc.manualAddButton,
                  style: SalamatDarkType.style(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
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
    Widget box(double h, {double r = SalamatDarkDims.rCard}) => Container(
          height: h,
          decoration: BoxDecoration(
            color: sc.surface,
            borderRadius: BorderRadius.circular(r),
          ),
        );
    return ListView(
      padding: EdgeInsets.only(
        top: 56,
        bottom: SalamatDarkDims.navHeight + 40,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
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
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: box(52, r: SalamatDarkDims.rPill),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
          child: box(340, r: SalamatDarkDims.rHero),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
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
            padding: const EdgeInsets.symmetric(
            horizontal: SalamatDarkDims.screenPadH,
          ),
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
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Row(
        children: [
          SalamatIcon(
            PhosphorIcons.wifiSlash(),
            size: 18,
            color: sc.warn,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              loc.dashboardOffline,
              style: SalamatDarkType.style(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sc.text,
                height: 1.2,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(
              loc.retryButton,
              style: SalamatDarkType.style(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: sc.primary,
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
        color: isToday ? sc.primary : sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Column(
        children: [
          Text(
            letter,
            style: SalamatDarkType.style(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: isToday
                  ? sc.onPrimary.withValues(alpha: 0.85)
                  : sc.text2,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '${date.day}',
            style: SalamatDarkType.style(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isToday
                  ? sc.onPrimary
                  : sc.text,
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
/// Hero card, repainted to the prototype's Home layout: a 132px calorie ring
/// on the left, the three macro bars stacked on the right, radius 24,
/// `--surface` fill, `--shadow-1`, padding 22.
///
/// The prototype also carries an Eaten / Burned / Net footer row under a
/// `--line` divider. It is omitted: "Burned" needs activity data (Apple
/// Health / step count) which this tranche does not touch.
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
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final statusLabel =
        left >= 0 ? loc.dashboardLeftLabel : loc.dashboardOverflowLabel;
    final numberColor = left >= 0 ? c.text : c.err;
    return SalamatCard(
      radius: SalamatDarkDims.rHero,
      padding: const EdgeInsets.all(SalamatDarkDims.padHero),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: SalamatDarkDims.ringSize,
            height: SalamatDarkDims.ringSize,
            child: AnimatedBuilder(
              animation: ringAnim,
              builder: (context, _) {
                final p = progress * ringAnim.value;
                return CustomPaint(
                  painter: _RingPainter(
                    progress: p,
                    overflow: overflow,
                    track: c.surface3,
                    fill: overflow ? c.err : c.primary,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CountUp(
                          value: left.abs(),
                          style: SalamatDarkType.numL
                              .copyWith(color: numberColor),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          '${loc.dashboardKcalUnit} $statusLabel',
                          style: SalamatDarkType.eyebrow.copyWith(
                            color: c.text3,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: SalamatDarkDims.gap20),
          Expanded(
            child: _MacroBars(
              protein: protein,
              fat: fat,
              carbs: carbs,
              norm: norm,
            ),
          ),
        ],
      ),
    );
  }
}

/// Calorie ring: `--surface-3` track, `--primary` sweep (`--err` on overflow),
/// stroke 11, round cap, no inner disc — the prototype's ring sits directly on
/// the card surface.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.overflow,
    required this.track,
    required this.fill,
  });

  final double progress;
  final bool overflow;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = SalamatDarkDims.ringStroke;
    final side = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: side - stroke,
      height: side - stroke,
    );

    final trackPaint = Paint()
      ..color = track
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, trackPaint);

    if (progress <= 0) return;

    final fg = Paint()
      ..color = fill
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.overflow != overflow ||
      oldDelegate.fill != fill;
}

/// Three stacked macro rows: `label` left, `value / target` right, then a 6px
/// pill bar. Colours follow the prototype — protein `--primary`,
/// carbs `--secondary`, fat `--accent`. Targets are the existing 30/30/40
/// display split, unchanged.
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
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        _MacroBar(
          label: loc.dashboardMacroProtein,
          value: protein,
          target: norm * 0.30 / 4,
          unit: loc.gramsUnit,
          color: c.primary,
        ),
        const SizedBox(height: 13),
        _MacroBar(
          label: loc.dashboardMacroCarbs,
          value: carbs,
          target: norm * 0.40 / 4,
          unit: loc.gramsUnit,
          color: c.secondary,
        ),
        const SizedBox(height: 13),
        _MacroBar(
          label: loc.dashboardMacroFat,
          value: fat,
          target: norm * 0.30 / 9,
          unit: loc.gramsUnit,
          color: c.accent,
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
    required this.color,
  });

  final String label;
  final double value;
  final double target;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fill = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SalamatDarkType.captionXs.copyWith(color: c.text2),
              ),
            ),
            Text(
              '${value.round()} / ${target.round()} $unit',
              style: SalamatDarkType.captionXs.copyWith(
                color: c.text3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: SalamatDarkDims.gap5),
        ClipRRect(
          borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
          child: SizedBox(
            height: SalamatDarkDims.macroBar,
            child: Stack(
              children: [
                Container(color: c.surface3),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: fill),
                  duration: const Duration(milliseconds: 620),
                  curve: SalamatDarkDims.ease,
                  builder: (_, f, __) => FractionallySizedBox(
                    widthFactor: f,
                    child: Container(color: color),
                  ),
                ),
              ],
            ),
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
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
      child: Row(
        children: [
          SalamatIcon.flame(size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.dashboardStreakLine(days),
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: sc.text,
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
    // The card is a doorway into the Meals tab — full diary lives there now.
    return GestureDetector(
      onTap: () => context.go('/meals'),
      behavior: HitTestBehavior.opaque,
      child: _body(loc),
    );
  }

  Widget _body(AppLocalizations loc) {
    if (entry == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
        child: Row(
          children: [
            SalamatIcon(
              PhosphorIcons.camera(PhosphorIconsStyle.duotone),
              size: 22,
              color: sc.primary,
              bubbleColor: sc.accentSoft,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.dashboardSnapFirstMeal,
                style: SalamatDarkType.style(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: sc.text2,
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
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
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
                  style: SalamatDarkType.style(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: sc.text2,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry!.name,
                  style: SalamatDarkType.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sc.text,
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  loc.dashboardKcalWithValue(entry!.kcal),
                  style: SalamatDarkType.style(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: sc.text2,
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

/// Cream weight card: current weight large, green "since start" delta and a
/// mini sparkline from `weight_logs`. "+" opens the shared Update-weight
/// dialog; tapping anywhere else is a doorway into the Progress tab.
class _WeightCard extends StatelessWidget {
  const _WeightCard({
    required this.weight,
    required this.logs,
    required this.onAdd,
  });

  final double? weight;
  final List<WeightLog> logs;
  final VoidCallback onAdd;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final current = weight ?? (logs.isEmpty ? null : logs.last.kg);
    final delta =
        (current != null && logs.isNotEmpty) ? current - logs.first.kg : null;
    return GestureDetector(
      onTap: () => context.go('/progress'),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
        color: sc.surface,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
        boxShadow: sc.shadow1,
      ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.dashboardWeightTitle,
                    style: SalamatDarkType.style(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: sc.text2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    current == null
                        ? '—'
                        : '${_fmt(current)} ${loc.profileKgShort}',
                    style: SalamatDarkType.style(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: sc.text,
                      height: 1.0,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (delta != null)
                    Text(
                      loc.dashboardWeightSinceStart(
                        '${delta >= 0 ? '+' : '−'}${_fmt(delta.abs())}',
                      ),
                      style: SalamatDarkType.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: sc.primary,
                      ),
                    )
                  else
                    // No weigh-ins yet: the big number above falls back to
                    // the profile weight; invite the first log instead of
                    // showing an empty delta.
                    Text(
                      loc.dashboardWeightFirstLog,
                      style: SalamatDarkType.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: sc.text2,
                      ),
                    ),
                ],
              ),
            ),
            if (logs.length >= 2) ...[
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                height: 40,
                child: CustomPaint(
                  painter: _SparklinePainter(
                    values: [for (final l in logs) l.kg],
                  ),
                ),
              ),
            ],
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onAdd,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration:  BoxDecoration(
                  color: sc.primary,
                  shape: BoxShape.circle,
                ),
                child: SalamatIcon(
                  PhosphorIcons.plus(PhosphorIconsStyle.bold),
                  size: 18,
                  color: sc.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Weight-history polyline, last point emphasized. Values are normalized to
/// the card's mini viewport; a flat history draws a mid-height line.
class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values});

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final shown = values.length > 14
        ? values.sublist(values.length - 14)
        : values;
    final min = shown.reduce(math.min);
    final max = shown.reduce(math.max);
    final span = max - min;
    const inset = 3.0;
    final h = size.height - inset * 2;
    final points = <Offset>[
      for (var i = 0; i < shown.length; i++)
        Offset(
          size.width * i / (shown.length - 1),
          span == 0
              ? size.height / 2
              : inset + h * (1 - (shown[i] - min) / span),
        ),
    ];
    final line = Paint()
      ..color = sc.primary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()..addPolygon(points, false),
      line,
    );
    canvas.drawCircle(
      points.last,
      3,
      Paint()..color = sc.primary,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}

/// Entry point to the coach, in the Home feed rather than the tab bar.
///
/// Visible to everyone, including free accounts: a paid feature nobody can see
/// is a feature nobody buys. What differs is where the tap lands — Pro opens
/// the chat, free opens the existing paywall. The badge says which it will be
/// BEFORE the tap, so the paywall is an answer to a question the user already
/// asked rather than a wall they walked into.
class _CoachCard extends ConsumerWidget {
  const _CoachCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context)!;
    final c = context.c;
    final sub = ref.watch(subscriptionProvider);
    // Until the server has answered, assume free: showing the badge and then
    // removing it is honest, while promising the chat and then charging is not.
    final isPro = sub.loaded && sub.isPro;

    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push(isPro ? '/coach' : '/paywall'),
        child: SalamatCard(
          radius: SalamatDarkDims.rCard,
          padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SalamatIcon(
                PhosphorIcons.chatCircleDots(PhosphorIconsStyle.duotone),
                size: 20,
                color: c.primary,
                bubbleColor: c.primarySoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            loc.coachCardTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: SalamatDarkType.style(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: c.text,
                            ),
                          ),
                        ),
                        if (!isPro) ...[
                          const SizedBox(width: 8),
                          const _ProBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      loc.coachCardBody,
                      style: SalamatDarkType.style(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: PhosphorIcon(
                  PhosphorIcons.caretRight(),
                  size: 16,
                  color: c.text3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "part of Pro" mark. Deliberately quiet — it is a label, not an advert.
class _ProBadge extends StatelessWidget {
  const _ProBadge();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.primarySoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        loc.coachCardBadge,
        style: SalamatDarkType.style(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: c.primary,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// White supportive-tone snack suggestion, rule-based on the calories left
/// today. Hidden entirely by the caller once the budget is spent.
class _SnackIdeaCard extends StatelessWidget {
  const _SnackIdeaCard({required this.kcalLeft});

  final int kcalLeft;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final text = kcalLeft > 400
        ? loc.snackIdeaHearty
        : kcalLeft >= 150
            ? loc.snackIdeaLight
            : loc.snackIdeaTiny;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SalamatIcon(
            PhosphorIcons.cookie(PhosphorIconsStyle.duotone),
            size: 20,
            color: sc.primary,
            bubbleColor: sc.accentSoft,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.snackIdeaTitle,
                  style: SalamatDarkType.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: sc.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: SalamatDarkType.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: sc.text2,
                    height: 1.35,
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

/// Water card, from the prototype's Home: droplet + `+250` action, the total
/// in litres, and a row of pips that fill as the day goes on.
///
/// `water_logs` ships in migration 0004, which is not applied yet. Until it
/// is, every write falls back to a device-local copy for the day and the card
/// says so in one muted line rather than pretending the value is stored.
class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final loc = AppLocalizations.of(context)!;
    final async = ref.watch(waterProvider);
    final water = async.valueOrNull ?? const WaterState();

    return SalamatCard(
      radius: SalamatDarkDims.rCard,
      padding: const EdgeInsets.all(SalamatDarkDims.padCardSmall),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(PhosphorIcons.drop(), size: 17, color: c.accent),
              const SizedBox(width: SalamatDarkDims.gap8),
              Expanded(
                child: Text(
                  loc.dashboardWater,
                  style: SalamatDarkType.captionS.copyWith(color: c.text2),
                ),
              ),
              if (water.canUndo)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ref.read(waterProvider.notifier).undo(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SalamatDarkDims.gap6,
                      vertical: 2,
                    ),
                    child: Text(
                      loc.waterUndo,
                      style: SalamatDarkType.micro.copyWith(color: c.text3),
                    ),
                  ),
                ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ref.read(waterProvider.notifier).add(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.primarySoft,
                    borderRadius:
                        BorderRadius.circular(SalamatDarkDims.rPill),
                  ),
                  child: Text(
                    loc.waterAdd(kWaterSipMl),
                    style: SalamatDarkType.micro.copyWith(
                      color: c.primaryInk,
                      fontWeight: SalamatDarkType.semi,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                loc.dashboardWaterLiters(
                  NumberFormat.decimalPatternDigits(
                    locale: Localizations.localeOf(context).toString(),
                    decimalDigits: 2,
                  ).format(water.totalMl / 1000),
                ),
                style: SalamatDarkType.numTitle.copyWith(color: c.text),
              ),
              const SizedBox(width: SalamatDarkDims.gap6),
              Text(
                loc.waterOfGoal(
                  NumberFormat.decimalPatternDigits(
                    locale: Localizations.localeOf(context).toString(),
                    decimalDigits: 1,
                  ).format(kWaterGoalMl / 1000),
                ),
                style: SalamatDarkType.micro.copyWith(color: c.text3),
              ),
            ],
          ),
          const SizedBox(height: SalamatDarkDims.gap10),
          Row(
            children: [
              for (var i = 0; i < kWaterPips; i++) ...[
                if (i > 0) const SizedBox(width: SalamatDarkDims.gap4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    decoration: BoxDecoration(
                      color: i < water.filledPips ? c.accent : c.surface3,
                      borderRadius:
                          BorderRadius.circular(SalamatDarkDims.rPill),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!water.synced && !water.loading) ...[
            const SizedBox(height: SalamatDarkDims.gap8),
            Text(
              loc.waterNotSynced,
              style: SalamatDarkType.micro.copyWith(color: c.text3),
            ),
          ],
        ],
      ),
    );
  }
}
