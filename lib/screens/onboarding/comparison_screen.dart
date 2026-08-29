import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';

import '../../theme/salamat_icons.dart';
import 'widgets.dart';
import '../../theme/salamat_dark.dart';

/// Step 14: what the app actually does. Deliberately capability-only copy —
/// no effectiveness multipliers, percentages or outcome promises.
class ComparisonScreen extends StatelessWidget {
  const ComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 14,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          OnboardingHeadline(loc.comparisonTitle),
          const SizedBox(height: 28),
          _FeatureRow(
            icon: PhosphorIcons.camera(PhosphorIconsStyle.duotone),
            text: loc.comparisonFeaturePhoto,
          ),
          const SizedBox(height: 12),
          _FeatureRow(
            icon: PhosphorIcons.chartLineUp(PhosphorIconsStyle.duotone),
            text: loc.comparisonFeatureNumbers,
          ),
          const SizedBox(height: 12),
          _FeatureRow(
            icon: PhosphorIcons.squaresFour(PhosphorIconsStyle.duotone),
            text: loc.comparisonFeatureOneScreen,
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.push('/onboarding/social-proof'),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});

  final PhosphorIconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sc.surface2,
        borderRadius: BorderRadius.circular(SalamatDarkDims.rCard),
      ),
      child: Row(
        children: [
          SalamatIcon(
            icon,
            size: 22,
            color: sc.primary,
            bubbleColor: sc.accentSoft,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: SalamatDarkType.style(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: sc.text,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
