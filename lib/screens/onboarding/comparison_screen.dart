import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/dimensions.dart';
import '../../theme/salamat_theme.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

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
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: _Bar(
                      label: loc.comparisonWithout,
                      heightFraction: 0.35,
                      color: SalamatTokens.ringTrack,
                      labelColor: SalamatTokens.textMuted,
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: _Bar(
                      label: loc.comparisonWith,
                      heightFraction: 1.0,
                      color: SalamatTokens.amber,
                      labelColor: SalamatTokens.amber,
                      featured: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: SalamatTokens.pillBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                SalamatIcon(
                  PhosphorIcons.chartLineUp(PhosphorIconsStyle.duotone),
                  size: 20,
                  color: SalamatTokens.accentDeep,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loc.comparisonStat,
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SalamatTokens.accentDeep,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.go('/onboarding/social-proof'),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.label,
    required this.heightFraction,
    required this.color,
    required this.labelColor,
    this.featured = false,
  });

  final String label;
  final double heightFraction;
  final Color color;
  final Color labelColor;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    // Layout: badge (optional fixed height) + bar (Expanded, scales to fill)
    // + spacer + label (fixed). The bar uses FractionallySizedBox inside the
    // Expanded region so its size is derived from whatever space remains
    // after the fixed-height children — no LayoutBuilder math, no risk of
    // overflowing the parent. heightFraction = 1.0 fills exactly the
    // available bar region; 0.35 shows 35% of it from the bottom.
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (featured)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: SalamatTokens.amber,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '×2',
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: SalamatTokens.surfaceAlt,
              ),
            ),
          ),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: heightFraction.clamp(0.0, 1.0),
              widthFactor: 1.0,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(SalamatDims.cardRadius),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}
