import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/salamat_theme.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

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
      onContinue: () => context.go('/onboarding/social-proof'),
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
      decoration: SalamatTokens.card(color: SalamatTokens.surfaceAlt),
      child: Row(
        children: [
          SalamatIcon(
            icon,
            size: 22,
            color: SalamatTokens.accentDeep,
            bubbleColor: SalamatTokens.bubbleMint,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: SalamatTokens.textPrimary,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
