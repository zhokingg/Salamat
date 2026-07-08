import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import 'widgets.dart';

class GenderScreen extends ConsumerStatefulWidget {
  const GenderScreen({super.key});

  @override
  ConsumerState<GenderScreen> createState() => _GenderScreenState();
}

class _GenderScreenState extends ConsumerState<GenderScreen> {
  Gender? _selected;

  @override
  void initState() {
    super.initState();
    _selected = ref.read(userProvider).gender;
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setGender(_selected!);
    context.go('/onboarding/year');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 4,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.genderTitle, subtitle: loc.genderSubtitle),
          const SizedBox(height: 24),
          OnboardingSelectCard(
            title: loc.genderFemale,
            leading: const _Emoji('👩'),
            selected: _selected == Gender.female,
            onTap: () => setState(() => _selected = Gender.female),
          ),
          const SizedBox(height: 12),
          OnboardingSelectCard(
            title: loc.genderMale,
            leading: const _Emoji('👨'),
            selected: _selected == Gender.male,
            onTap: () => setState(() => _selected = Gender.male),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonNext,
      buttonEnabled: _selected != null,
      onContinue: _next,
    );
  }
}

class _Emoji extends StatelessWidget {
  const _Emoji(this.value);
  final String value;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(child: Text(value, style: const TextStyle(fontSize: 32))),
    );
  }
}
