import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/salamat_icons.dart';
import '../../theme/salamat_theme.dart';
import 'widgets.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          SalamatIcon(
            PhosphorIcons.trophy(PhosphorIconsStyle.duotone),
            size: 72,
            color: SalamatTokens.amber,
            bubbleColor: SalamatTokens.bubbleAmber,
          ),
          const SizedBox(height: 32),
          Text(
            loc.welcomeHeadline,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: SalamatTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            loc.welcomeSubtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              height: 1.4,
              color: SalamatTokens.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            loc.welcomeFreeLine,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: SalamatTokens.textMuted,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
      buttonLabel: loc.buttonStart,
      onContinue: () => context.go('/onboarding/name'),
    );
  }
}
