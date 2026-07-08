import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/dimensions.dart';
import '../../theme/salamat_theme.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

class SocialProofScreen extends StatelessWidget {
  const SocialProofScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 15,
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
              color: SalamatTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 90,
                  child: _Avatar(
                    icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                    fg: SalamatTokens.accentDeep,
                    bg: SalamatTokens.pillBg,
                  ),
                ),
                Positioned(
                  right: 90,
                  child: _Avatar(
                    icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                    fg: SalamatTokens.onAccent,
                    bg: SalamatTokens.amber,
                  ),
                ),
                _Avatar(
                  icon: PhosphorIcons.user(PhosphorIconsStyle.duotone),
                  fg: SalamatTokens.onAccent,
                  bg: SalamatTokens.accentDeep,
                  big: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            loc.socialUsersCount,
            style: GoogleFonts.manrope(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: SalamatTokens.accentDeep,
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
              color: SalamatTokens.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SalamatTokens.pillBg,
              borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
            ),
            child: Column(
              children: [
                Text(
                  loc.socialStatPercent,
                  style: GoogleFonts.manrope(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: SalamatTokens.accentDeep,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  loc.socialStatText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: SalamatTokens.textPrimary,
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
  const _Avatar({
    required this.icon,
    required this.fg,
    required this.bg,
    this.big = false,
  });
  final PhosphorIconData icon;
  final Color fg;
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
        border: Border.all(color: SalamatTokens.surfaceAlt, width: 4),
      ),
      child: PhosphorIcon(icon, size: big ? 36 : 28, color: fg),
    );
  }
}
