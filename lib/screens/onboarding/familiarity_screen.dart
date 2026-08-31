import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

class FamiliarityScreen extends ConsumerStatefulWidget {
  const FamiliarityScreen({super.key});

  @override
  ConsumerState<FamiliarityScreen> createState() => _FamiliarityScreenState();
}

class _FamiliarityScreenState extends ConsumerState<FamiliarityScreen> {
  Familiarity? _selected;

  static final _icons = {
    Familiarity.novice: PhosphorIcons.plant(PhosphorIconsStyle.duotone),
    Familiarity.intermediate:
        PhosphorIcons.bookOpen(PhosphorIconsStyle.duotone),
    Familiarity.expert: PhosphorIcons.medal(PhosphorIconsStyle.duotone),
  };

  @override
  void initState() {
    super.initState();
    _selected = ref.read(userProvider).familiarity;
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setFamiliarity(_selected!);
    context.push('/onboarding/activity');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 10,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.familiarityTitle),
          // The amber "75% answered the same way" card lived here. It was a
          // statistic about users the app does not have yet, so it is gone
          // rather than reworded. The question itself carries the screen.
          const SizedBox(height: 28),
          for (final f in Familiarity.values) ...[
            OnboardingSelectCard(
              title: f.label(loc),
              subtitle: f.subtitle(loc),
              leading: OnboardingLeadingIcon(
                icon: _icons[f] ?? PhosphorIcons.circle(),
                selected: _selected == f,
              ),
              selected: _selected == f,
              onTap: () => setState(() => _selected = f),
            ),
            if (f != Familiarity.values.last) const SizedBox(height: 12),
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
