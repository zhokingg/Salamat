import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/user_provider.dart';
import 'widgets.dart';

/// S3 — country selection. Determines paywall currency. Pre-selects based
/// on the device's ISO country code if it's one we support; otherwise
/// defaults to "Other" (USD).
class CountryScreen extends ConsumerStatefulWidget {
  const CountryScreen({super.key});

  @override
  ConsumerState<CountryScreen> createState() => _CountryScreenState();
}

class _CountryScreenState extends ConsumerState<CountryScreen> {
  Country? _selected;

  @override
  void initState() {
    super.initState();
    final stored = ref.read(userProvider).country;
    if (stored != null) {
      _selected = stored;
    } else {
      final deviceLocale =
          WidgetsBinding.instance.platformDispatcher.locale;
      _selected = Country.fromDeviceCode(deviceLocale.countryCode);
    }
  }

  void _next() {
    if (_selected == null) return;
    ref.read(userProvider.notifier).setCountry(_selected!);
    context.go('/onboarding/goal');
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
          OnboardingHeadline(loc.countryTitle, subtitle: loc.countrySubtitle),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: Country.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final c = Country.values[i];
                return OnboardingSelectCard(
                  title: c.label(loc),
                  leading: _FlagBadge(flag: c.flag),
                  selected: _selected == c,
                  onTap: () => setState(() => _selected = c),
                );
              },
            ),
          ),
        ],
      ),
      buttonLabel: loc.buttonNext,
      buttonEnabled: _selected != null,
      onContinue: _next,
    );
  }
}

class _FlagBadge extends StatelessWidget {
  const _FlagBadge({required this.flag});
  final String flag;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Center(child: Text(flag, style: const TextStyle(fontSize: 28))),
    );
  }
}
