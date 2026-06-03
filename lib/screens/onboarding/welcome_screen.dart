import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';
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
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: SalamatColors.g4,
              shape: BoxShape.circle,
            ),
            child: const Text('🏆', style: TextStyle(fontSize: 72)),
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
              color: SalamatColors.ink,
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
              color: SalamatColors.i2,
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
