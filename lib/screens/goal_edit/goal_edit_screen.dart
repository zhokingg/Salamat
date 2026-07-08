import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:salamat/l10n/app_localizations.dart';

import '../../providers/user_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme/dimensions.dart';
import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import '../onboarding/widgets.dart'
    show OnboardingSelectCard, OnboardingWheelPicker, calculateDailyCalories;

/// Standalone goal editor, reached from Profile → "My goal".
///
/// Deliberately NOT part of the onboarding flow: it is a short pushed route
/// with its own exit (pop back to Profile), no motivational screens, and it
/// never touches the `onboarding_completed` flag. Nothing is mutated until
/// the final Save — backing out midway leaves the profile untouched.
class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({super.key});

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  static const int _minKg = 40;
  static const int _maxKg = 200;

  /// 0 = pick goal, 1 = pick target weight (lose/gain only).
  int _step = 0;
  Goal? _goal;
  late FixedExtentScrollController _wheelCtl;
  int _idx = 0;
  bool _saving = false;

  static final Map<Goal, PhosphorIconData> _icons = {
    Goal.lose: PhosphorIcons.trendDown(PhosphorIconsStyle.duotone),
    Goal.gain: PhosphorIcons.barbell(PhosphorIconsStyle.duotone),
    Goal.maintain: PhosphorIcons.target(PhosphorIconsStyle.duotone),
    Goal.healthy: PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
  };

  @override
  void initState() {
    super.initState();
    _goal = ref.read(userProvider).goal;
    _wheelCtl = FixedExtentScrollController();
  }

  @override
  void dispose() {
    _wheelCtl.dispose();
    super.dispose();
  }

  int get _target => _minKg + _idx;

  bool get _needsTarget => _goal == Goal.lose || _goal == Goal.gain;

  void _toTargetStep() {
    final u = ref.read(userProvider);
    final current = (u.weight?.round() ?? 70).clamp(_minKg, _maxKg);
    final fallback = _goal == Goal.lose
        ? (current - 5).clamp(_minKg, _maxKg)
        : (current + 5).clamp(_minKg, _maxKg);
    final start =
        (u.targetWeight?.round() ?? fallback).clamp(_minKg, _maxKg);
    _idx = start - _minKg;
    _wheelCtl.dispose();
    _wheelCtl = FixedExtentScrollController(initialItem: _idx);
    setState(() => _step = 1);
  }

  Future<void> _save() async {
    if (_goal == null || _saving) return;
    setState(() => _saving = true);
    final notifier = ref.read(userProvider.notifier);
    notifier.setGoal(_goal!);
    if (_needsTarget) {
      notifier.setTargetWeight(_target.toDouble());
    }
    // Recompute the calorie plan with the new goal against existing body data.
    final u = ref.read(userProvider);
    final kcal = calculateDailyCalories(
      weight: u.weight ?? 70,
      height: u.height ?? 165,
      age: u.age ?? 25,
      gender: u.gender,
      activityLevel: u.activityLevel,
      goal: u.goal,
    );
    notifier.setCalorieNorm(kcal);
    // Persist — unlike onboarding this writes immediately, so a later
    // restart can't silently revert the edit.
    await SupabaseService.upsertUser(
      name: u.name.isEmpty ? 'Friend' : u.name,
      gender: u.gender == Gender.female ? 'female' : 'male',
      age: u.age ?? 25,
      heightCm: u.height ?? 165,
      weightKg: u.weight ?? 70,
      goal: switch (u.goal) {
        Goal.lose => 'lose',
        Goal.gain => 'gain',
        _ => 'maintain',
      },
      dailyCalories: kcal,
    );
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: SalamatTokens.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: SalamatTokens.textPrimary,
          ),
          onPressed: () {
            if (_step == 1) {
              setState(() => _step = 0);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          loc.profileSettingMyGoal,
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: SalamatTokens.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SalamatDims.screenPadding,
          ),
          child: _step == 0 ? _goalStep(loc) : _targetStep(loc),
        ),
      ),
    );
  }

  Widget _goalStep(AppLocalizations loc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(loc.goalSubtitle, style: SalamatType.caption),
        const SizedBox(height: 16),
        for (final g in Goal.values) ...[
          OnboardingSelectCard(
            title: g.label(loc),
            subtitle: g.subtitle(loc),
            leading: SalamatIcon(
              _icons[g] ?? PhosphorIcons.circle(),
              size: 22,
              color: SalamatTokens.accentDeep,
              bubbleColor: SalamatTokens.bubbleMint,
            ),
            selected: _goal == g,
            onTap: () => setState(() => _goal = g),
          ),
          const SizedBox(height: 12),
        ],
        const Spacer(),
        _Cta(
          label: _needsTarget ? loc.buttonNext : loc.buttonSave,
          enabled: _goal != null && !_saving,
          onTap: _needsTarget ? _toTargetStep : _save,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _targetStep(AppLocalizations loc) {
    final delta = _target - (ref.read(userProvider).weight?.round() ?? 70);
    final deltaLabel = delta < 0
        ? loc.targetDeltaLose(-delta)
        : delta > 0
            ? loc.targetDeltaGain(delta)
            : loc.targetDeltaMaintain;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(loc.targetSubtitle, style: SalamatType.caption),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: OnboardingWheelPicker(
            controller: _wheelCtl,
            selectedIndex: _idx,
            min: _minKg,
            max: _maxKg,
            onChanged: (i) => setState(() => _idx = i),
            suffix: loc.profileKgShort,
          ),
        ),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: SalamatTokens.pillBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              deltaLabel,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: SalamatTokens.pillText,
              ),
            ),
          ),
        ),
        const Spacer(),
        _Cta(
          label: loc.buttonSave,
          enabled: !_saving,
          onTap: _save,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Cta extends StatelessWidget {
  const _Cta({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: SalamatDims.buttonHeight,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: SalamatTokens.accentDeep,
          foregroundColor: SalamatTokens.onAccent,
          disabledBackgroundColor: SalamatTokens.pillBg,
          disabledForegroundColor: SalamatTokens.textMuted,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SalamatTokens.radiusCta),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
