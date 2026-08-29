import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/onboarding_flag.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

class PlanReadyScreen extends ConsumerStatefulWidget {
  const PlanReadyScreen({super.key});

  @override
  ConsumerState<PlanReadyScreen> createState() => _PlanReadyScreenState();
}

class _PlanReadyScreenState extends ConsumerState<PlanReadyScreen> {
  int _calories = 0;
  int _weeksToTarget = 0;
  DateTime _targetDate = DateTime.now();

  /// The in-flight profile write started by [_commit]. The Continue button
  /// awaits this so the row is guaranteed persisted before the user can leave
  /// (and potentially close the app).
  Future<void>? _saveFuture;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _commit());
  }

  void _commit() {
    final u = ref.read(userProvider);
    final weight = u.weight ?? 70;
    final height = u.height ?? 165;
    final age = u.age ?? 25;

    final kcal = calculateDailyCalories(
      weight: weight,
      height: height,
      age: age,
      gender: u.gender,
      activityLevel: u.activityLevel,
      goal: u.goal,
    );
    ref.read(userProvider.notifier).setCalorieNorm(kcal);

    final delta = u.weightDelta.abs();
    final weeks = delta <= 0 ? 8 : (delta * 2).round().clamp(4, 52);
    final target = DateTime.now().add(Duration(days: weeks * 7));

    setState(() {
      _calories = kcal;
      _weeksToTarget = weeks;
      _targetDate = target;
    });

    // Local flag FIRST — a dead network must never bounce this user back
    // into onboarding on the next launch. The profile write below is sync.
    _saveFuture = OnboardingFlag.setCompleted().then((_) => SupabaseService.upsertUser(
      name: u.name.isEmpty ? 'Friend' : u.name,
      gender: u.gender == Gender.female ? 'female' : 'male',
      age: age,
      heightCm: height,
      weightKg: weight,
      goal: switch (u.goal) {
        Goal.lose => 'lose',
        Goal.gain => 'gain',
        Goal.maintain => 'maintain',
        Goal.healthy => 'maintain',
        null => 'maintain',
      },
      dailyCalories: kcal,
    ));
  }

  // Locale-aware short month label. The l10n setup ships ru and en — using
  // hand-rolled abbreviations to match the existing visual ("3 янв").
  String _formatDate(DateTime d, AppLocalizations loc) {
    const ru = [
      'янв', 'фев', 'мар', 'апр', 'мая', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final isRu = loc.localeName.startsWith('ru');
    final m = (isRu ? ru : en)[d.month - 1];
    return '${d.day} $m';
  }

  /// Month of the projected target date, in a form that reads naturally in
  /// the sentence ("in September" / «в сентябре» — prepositional case).
  String _reachMonth(AppLocalizations loc) {
    const ru = [
      'январе', 'феврале', 'марте', 'апреле', 'мае', 'июне',
      'июле', 'августе', 'сентябре', 'октябре', 'ноябре', 'декабре',
    ];
    const en = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final m = _targetDate.month - 1;
    return loc.localeName == 'ru' ? ru[m] : en[m];
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final u = ref.watch(userProvider);
    final current = u.weight?.round() ?? 70;
    final target = u.targetWeight?.round() ?? current;

    return OnboardingShell(
      step: null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            loc.planTitle,
            style: SalamatDarkType.style(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: sc.text,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: sc.surface2,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
              border: Border.all(color: sc.surface3),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _Endpoint(
                      title: loc.planNow,
                      value: loc.weightWeightValue(current),
                      date: _formatDate(DateTime.now(), loc),
                    ),
                    _Endpoint(
                      title: loc.planTarget,
                      value: loc.weightWeightValue(target),
                      date: _formatDate(_targetDate, loc),
                      highlighted: true,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: CustomPaint(
                    painter: _PlanChartPainter(
                      losing: current > target,
                      gaining: current < target,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _weeksToTarget > 0
                      ? loc.planWeeksToTarget(_weeksToTarget)
                      : loc.planMaintain,
                  style: SalamatDarkType.style(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sc.text2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Calorie budget — the hero number of the plan (per mockup).
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: sc.surface2,
              borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SalamatIcon.flame(size: 22),
                    const SizedBox(width: 10),
                    Text(
                      loc.planCaloriesLabel,
                      style: SalamatDarkType.style(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: sc.text2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _calories > 0
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: _calories.toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (_, v, __) => Text(
                          loc.planCaloriesValue(v.round()),
                          style: SalamatDarkType.style(
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                            color: sc.text,
                            letterSpacing: -0.6,
                            height: 1.0,
                          ),
                        ),
                      )
                    : Text(
                        loc.valueDash,
                        style: SalamatDarkType.style(
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          color: sc.text,
                          height: 1.0,
                        ),
                      ),
                const SizedBox(height: 14),
                // Macro pills — reference 30/30/40 split of the budget.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MacroPill(
                      label: loc.dashboardMacroProtein,
                      grams: (_calories * 0.30 / 4).round(),
                      unit: loc.gramsUnit,
                    ),
                    _MacroPill(
                      label: loc.dashboardMacroFat,
                      grams: (_calories * 0.30 / 9).round(),
                      unit: loc.gramsUnit,
                    ),
                    _MacroPill(
                      label: loc.dashboardMacroCarbs,
                      grams: (_calories * 0.40 / 4).round(),
                      unit: loc.gramsUnit,
                    ),
                  ],
                ),
                if (current != target) ...[
                  const SizedBox(height: 14),
                  Text(
                    loc.planReachLine(target, _reachMonth(loc)),
                    style: SalamatDarkType.style(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: sc.primary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.planStartTracking,
      onContinue: () async {
        // Ensure the profile write finished before leaving onboarding, so a
        // returning user is always recognised on the next launch.
        await _saveFuture;
        if (context.mounted) context.go('/dashboard');
      },
    );
  }
}

class _Endpoint extends StatelessWidget {
  const _Endpoint({
    required this.title,
    required this.value,
    required this.date,
    this.highlighted = false,
  });
  final String title;
  final String value;
  final String date;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = highlighted ? sc.primary : sc.text2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: SalamatDarkType.style(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            color: sc.text3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: SalamatDarkType.style(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: c,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          date,
          style: SalamatDarkType.style(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: sc.text3,
          ),
        ),
      ],
    );
  }
}

class _PlanChartPainter extends CustomPainter {
  _PlanChartPainter({required this.losing, required this.gaining});
  final bool losing;
  final bool gaining;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final axis = Paint()
      ..color = sc.surface3
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, h - 1), Offset(w, h - 1), axis);

    final line = Paint()
      ..color = sc.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = sc.primary.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final filledPath = Path();
    for (int i = 0; i <= 40; i++) {
      final t = i / 40.0;
      final x = t * w;
      final ease = 1 - (1 - t) * (1 - t);
      final double y;
      if (losing) {
        y = h * 0.2 + ease * h * 0.6;
      } else if (gaining) {
        y = h * 0.8 - ease * h * 0.6;
      } else {
        y = h * 0.5;
      }
      if (i == 0) {
        path.moveTo(x, y);
        filledPath.moveTo(x, h);
        filledPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        filledPath.lineTo(x, y);
      }
    }
    filledPath.lineTo(w, h);
    filledPath.close();
    canvas.drawPath(filledPath, fill);
    canvas.drawPath(path, line);

    final dot = Paint()..color = sc.primary;
    final endEase = 1.0;
    final double endY;
    if (losing) {
      endY = h * 0.2 + endEase * h * 0.6;
    } else if (gaining) {
      endY = h * 0.8 - endEase * h * 0.6;
    } else {
      endY = h * 0.5;
    }
    canvas.drawCircle(Offset(w - 2, endY), 5, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.grams,
    required this.unit,
  });

  final String label;
  final int grams;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: sc.primarySoft,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rPill),
      ),
      child: Text(
        '$label \u00b7 $grams $unit',
        style: SalamatDarkType.style(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: sc.primaryInk,
          height: 1.0,
        ),
      ),
    );
  }
}
