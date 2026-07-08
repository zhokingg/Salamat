import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

class GoalScreen extends ConsumerStatefulWidget {
  const GoalScreen({super.key});

  @override
  ConsumerState<GoalScreen> createState() => _GoalScreenState();
}

// Line icons in place of emoji — same semantic mapping, premium feel.
final _icon = {
  Goal.lose: PhosphorIcons.trendDown(PhosphorIconsStyle.duotone),
  Goal.gain: PhosphorIcons.barbell(PhosphorIconsStyle.duotone),
  Goal.maintain: PhosphorIcons.target(PhosphorIconsStyle.duotone),
  Goal.healthy: PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
};

class _GoalScreenState extends ConsumerState<GoalScreen> {
  Goal? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(userProvider).goal;
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setGoal(_selected!);
    context.go('/onboarding/gender');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 3,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.goalTitle, subtitle: loc.goalSubtitle),
          const SizedBox(height: 28),
          for (var i = 0; i < Goal.values.length; i++) ...[
            OnboardingSelectCard(
              title: Goal.values[i].label(loc),
              subtitle: Goal.values[i].subtitle(loc),
              leading: OnboardingLeadingIcon(
                icon: _icon[Goal.values[i]] ?? PhosphorIcons.circle(),
                selected: _selected == Goal.values[i],
              ),
              selected: _selected == Goal.values[i],
              onTap: () => setState(() => _selected = Goal.values[i]),
            ),
            if (i != Goal.values.length - 1) const SizedBox(height: 12),
          ],
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      buttonEnabled: _selected != null,
      onContinue: _next,
    );
  }
}
