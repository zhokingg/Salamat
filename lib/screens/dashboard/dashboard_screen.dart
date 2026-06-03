import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../providers/meals_provider.dart';
import '../../providers/user_provider.dart';
import '../../screens/onboarding/widgets.dart' show CountUp;
import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import '../../theme/elevation.dart';

const Color _kOverflow = Color(0xFFC0392B);

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

  final int _streak = 1;

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
    final meals = ref.watch(mealsProvider).valueOrNull ?? const MealsState();

    final norm = user.calorieNorm ?? 2000;
    final name = user.name.isNotEmpty ? user.name : loc.dashboardGuestName;
    final consumed = meals.totalKcalAll;
    final overflow = consumed > norm;
    final left = norm - consumed;
    final progress = norm == 0 ? 0.0 : (consumed / norm).clamp(0.0, 1.0);

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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  loc.dashboardGreeting(name),
                  style: GoogleFonts.manrope(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.ink,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              _StreakBadge(days: _streak),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CaloriesCard(
            ringAnim: _ringAnim,
            progress: progress,
            overflow: overflow,
            consumed: consumed,
            norm: norm,
            left: left,
            protein: meals.totalProtein,
            fat: meals.totalFat,
            carbs: meals.totalCarbs,
          ),
        ),
        const SizedBox(height: 28),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: Text(
            loc.dashboardMeals,
            style: GoogleFonts.manrope(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
            ),
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
              onTap: () => context.push(
                '/search',
                extra: _kMealViews[i].type,
              ),
            ),
          ),
          if (i != _kMealViews.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SalamatElevation.hairline),
        boxShadow: SalamatElevation.card,
      ),
      // One ICU-plural string instead of stacked number + bare "days" — this
      // is what made the old badge render "1 дней" in Russian. The plural
      // rule lives in app_ru.arb so the badge now follows one/few/many.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(
            loc.dashboardStreakLine(days),
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _CaloriesCard extends StatelessWidget {
  const _CaloriesCard({
    required this.ringAnim,
    required this.progress,
    required this.overflow,
    required this.consumed,
    required this.norm,
    required this.left,
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final Animation<double> ringAnim;
  final double progress;
  final bool overflow;
  final int consumed;
  final int norm;
  final int left;
  final double protein;
  final double fat;
  final double carbs;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final remainderText =
        left >= 0 ? loc.dashboardLeft(left) : loc.dashboardOverflow(-left);
    final remainderColor = left >= 0 ? SalamatColors.g1 : _kOverflow;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: SalamatColors.surf,
        borderRadius: BorderRadius.circular(SalamatElevation.cardRadius),
        border: Border.all(color: SalamatElevation.hairline),
        boxShadow: SalamatElevation.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.dashboardCaloriesLabel,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: SalamatColors.i3,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 176,
              height: 176,
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
                            value: consumed,
                            style: GoogleFonts.manrope(
                              fontSize: 48,
                              fontWeight: FontWeight.w800,
                              color: SalamatColors.ink,
                              height: 1.0,
                              letterSpacing: -1.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            loc.dashboardConsumedOfNorm(norm),
                            style: GoogleFonts.manrope(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: SalamatColors.i3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            remainderText,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: remainderColor,
                              letterSpacing: -0.1,
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
          const SizedBox(height: 22),
          _MacroRow(protein: protein, fat: fat, carbs: carbs),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.overflow});

  final double progress;
  final bool overflow;

  @override
  void paint(Canvas canvas, Size size) {
    // Heavier stroke + softer background ring + sweep gradient for a more
    // premium hero element.
    const stroke = 14.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final bg = Paint()
      ..color = const Color(0xFFEDF2EB)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * math.pi, false, bg);

    if (progress <= 0) return;

    final Paint fg;
    if (overflow) {
      fg = Paint()
        ..color = _kOverflow
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
    } else {
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + 2 * math.pi,
        colors: SalamatElevation.ringGradient,
      );
      fg = Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = stroke
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
    }

    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fg,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.overflow != overflow;
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.protein,
    required this.fat,
    required this.carbs,
  });

  final double protein;
  final double fat;
  final double carbs;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(child: _MacroCell(value: protein, label: loc.dashboardMacroProtein)),
        Container(width: 1, height: 40, color: SalamatColors.line),
        Expanded(child: _MacroCell(value: fat, label: loc.dashboardMacroFat)),
        Container(width: 1, height: 40, color: SalamatColors.line),
        Expanded(child: _MacroCell(value: carbs, label: loc.dashboardMacroCarbs)),
      ],
    );
  }
}

class _MacroCell extends StatelessWidget {
  const _MacroCell({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(
      children: [
        Text(
          '${value.round()} ${loc.gramsUnit}',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: SalamatColors.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: SalamatColors.i3,
          ),
        ),
      ],
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
        decoration: BoxDecoration(
          color: SalamatColors.surf,
          borderRadius: BorderRadius.circular(SalamatElevation.cardRadius),
          border: Border.all(color: SalamatElevation.hairline),
          boxShadow: SalamatElevation.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(type.emoji, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    type.label(loc),
                    style: GoogleFonts.manrope(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: SalamatColors.ink,
                    ),
                  ),
                ),
                Text(
                  loc.dashboardKcalWithValue(totalKcal),
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight:
                        totalKcal == 0 ? FontWeight.w400 : FontWeight.w700,
                    color: totalKcal == 0
                        ? SalamatColors.i3
                        : SalamatColors.ink,
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
                  fontWeight: FontWeight.w400,
                  color: SalamatColors.i3,
                ),
              ),
            ] else ...[
              const SizedBox(height: 10),
              Container(height: 1, color: SalamatColors.line),
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
                  color: SalamatColors.ink,
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
                  color: SalamatColors.i3,
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
              fontWeight: FontWeight.w700,
              color: SalamatColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}
