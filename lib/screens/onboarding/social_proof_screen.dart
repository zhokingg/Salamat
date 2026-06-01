import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
import 'widgets.dart';

class SocialProofScreen extends StatelessWidget {
  const SocialProofScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 16,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            loc.socialTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: SalamatColors.ink,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(left: 90, child: _Avatar(emoji: '👨🏽', bg: SalamatColors.g3)),
                Positioned(right: 90, child: _Avatar(emoji: '👩🏻', bg: SalamatColors.warn)),
                _Avatar(emoji: '👩🏽', bg: SalamatColors.g1, big: true),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            loc.socialUsersCount,
            style: GoogleFonts.manrope(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: SalamatColors.g1,
              letterSpacing: -1.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            loc.socialUsersLabel,
            style: GoogleFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: SalamatColors.i2,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SalamatColors.g4,
              borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
            ),
            child: Column(
              children: [
                Text(
                  loc.socialStatPercent,
                  style: GoogleFonts.manrope(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: SalamatColors.g1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.socialStatText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SalamatColors.ink,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonContinue,
      onContinue: () => context.go('/onboarding/building'),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.emoji, required this.bg, this.big = false});
  final String emoji;
  final Color bg;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 80.0 : 64.0;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: SalamatColors.surf, width: 4),
      ),
      child: Text(emoji, style: TextStyle(fontSize: big ? 40 : 32)),
    );
  }
}
