import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

class TargetWeightScreen extends ConsumerStatefulWidget {
  const TargetWeightScreen({super.key});

  @override
  ConsumerState<TargetWeightScreen> createState() => _TargetWeightScreenState();
}

class _TargetWeightScreenState extends ConsumerState<TargetWeightScreen> {
  static const int _min = 40;
  static const int _max = 200;

  late final FixedExtentScrollController _ctl;
  late int _idx;
  late int _current;

  @override
  void initState() {
    super.initState();
    final u = ref.read(userProvider);
    _current = (u.weight?.round() ?? 70).clamp(_min, _max);
    final int defaultTarget;
    switch (u.goal) {
      case Goal.lose:
        defaultTarget = (_current - 5).clamp(_min, _max);
        break;
      case Goal.gain:
        defaultTarget = (_current + 5).clamp(_min, _max);
        break;
      default:
        defaultTarget = _current;
    }
    final start = (u.targetWeight?.round() ?? defaultTarget).clamp(_min, _max);
    _idx = start - _min;
    _ctl = FixedExtentScrollController(initialItem: _idx);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  int get _target => _min + _idx;
  int get _delta => _current - _target;

  String _deltaLabel(AppLocalizations loc) {
    if (_delta > 0) return loc.targetDeltaLose(_delta);
    if (_delta < 0) return loc.targetDeltaGain(-_delta);
    return loc.targetDeltaMaintain;
  }

  Future<void> _next() async {
    final u = ref.read(userProvider);

    // Safety gate: weight loss is not safe at BMI < 18.5. Show a
    // dismissable warning that requires explicit acknowledgement before
    // proceeding. The check fires here (target screen) because it's the
    // last point in the funnel where the user can still pivot the goal
    // before the plan is committed.
    if (u.goal == Goal.lose && u.bmiBand == BmiBand.under) {
      final proceed = await _showUnderweightWarning();
      if (proceed != true) {
        // "Change goal" or backdrop dismiss: bounce back to /onboarding/goal
        // so they can pick maintain/healthy instead. Don't persist target.
        // Resets the funnel to the goal step rather than stacking a
        // second copy of it on top of the current chain.
        if (mounted) context.go('/onboarding/goal');
        return;
      }
    }

    ref.read(userProvider.notifier).setTargetWeight(_target.toDouble());
    if (mounted) context.push('/onboarding/celebration');
  }

  Future<bool?> _showUnderweightWarning() {
    final loc = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      // barrierDismissible: false — Play requires explicit choice for
      // health warnings, no swipe-away.
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: sc.surface2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          loc.underweightWarningTitle,
          style: SalamatDarkType.style(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: sc.text,
          ),
        ),
        content: Text(
          loc.underweightWarningBody,
          style: SalamatDarkType.style(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.45,
            color: sc.text2,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              loc.underweightWarningChangeGoal,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: sc.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              loc.underweightWarningProceed,
              style: SalamatDarkType.style(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: sc.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 7,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.targetTitle, subtitle: loc.targetSubtitle),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: OnboardingWheelPicker(
              controller: _ctl,
              selectedIndex: _idx,
              min: _min,
              max: _max,
              onChanged: (i) => setState(() => _idx = i),
              suffix: loc.profileKgShort,
            ),
          ),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: sc.primarySoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _deltaLabel(loc),
                style: SalamatDarkType.style(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: sc.primary,
                ),
              ),
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      onContinue: _next,
    );
  }
}
