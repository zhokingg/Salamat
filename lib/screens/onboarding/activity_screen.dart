import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../providers/user_provider.dart';
import 'widgets.dart';

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key});

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  ActivityLevel? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(userProvider).activityLevel;
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setActivityLevel(_selected!);
    context.go('/onboarding/summary');
  }

  static const _icons = {
    ActivityLevel.sedentary: LucideIcons.armchair,
    ActivityLevel.light: LucideIcons.footprints,
    ActivityLevel.moderate: LucideIcons.activity,
    ActivityLevel.veryActive: LucideIcons.dumbbell,
  };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 12,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.activityTitle, subtitle: loc.activitySubtitle),
          const SizedBox(height: 28),
          for (final lvl in ActivityLevel.values) ...[
            OnboardingSelectCard(
              title: lvl.label(loc),
              subtitle: lvl.subtitle(loc),
              leading: OnboardingLeadingIcon(
                icon: _icons[lvl] ?? LucideIcons.circle,
                selected: _selected == lvl,
              ),
              selected: _selected == lvl,
              onTap: () => setState(() => _selected = lvl),
            ),
            if (lvl != ActivityLevel.values.last) const SizedBox(height: 12),
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
