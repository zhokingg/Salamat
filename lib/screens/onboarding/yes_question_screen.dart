import 'package:flutter/material.dart';
import 'package:salamat/l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/dimensions.dart';
import '../../theme/salamat_theme.dart';
import '../../theme/salamat_icons.dart';
import 'widgets.dart';

enum YesQuestion { lose, order, health }

class YesQuestionScreen extends StatelessWidget {
  const YesQuestionScreen({super.key, required this.question});

  final YesQuestion question;

  String _headline(AppLocalizations loc) => switch (question) {
        YesQuestion.lose => loc.yesLoseQuestion,
        YesQuestion.order => loc.yesOrderQuestion,
        YesQuestion.health => loc.yesHealthQuestion,
      };

  PhosphorIconData get _beforeIcon => switch (question) {
        YesQuestion.lose => PhosphorIcons.smileySad(PhosphorIconsStyle.duotone),
        YesQuestion.order =>
          PhosphorIcons.hamburger(PhosphorIconsStyle.duotone),
        YesQuestion.health => PhosphorIcons.pill(PhosphorIconsStyle.duotone),
      };

  PhosphorIconData get _afterIcon => switch (question) {
        YesQuestion.lose => PhosphorIcons.smiley(PhosphorIconsStyle.duotone),
        YesQuestion.order =>
          PhosphorIcons.bowlFood(PhosphorIconsStyle.duotone),
        YesQuestion.health => PhosphorIcons.heart(PhosphorIconsStyle.duotone),
      };

  String get _next => switch (question) {
        YesQuestion.lose => '/onboarding/yes/order',
        YesQuestion.order => '/onboarding/yes/health',
        YesQuestion.health => '/onboarding/comparison',
      };

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return OnboardingShell(
      step: 13,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            _headline(loc),
            style: GoogleFonts.manrope(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.6,
              color: SalamatTokens.textPrimary,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _Illust(
                  icon: _beforeIcon,
                  iconColor: SalamatTokens.textMuted,
                  caption: loc.yesCaptionBefore,
                  bg: SalamatTokens.ringTrack,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: SalamatTokens.iconQuiet,
                ),
              ),
              Expanded(
                child: _Illust(
                  icon: _afterIcon,
                  iconColor: SalamatTokens.accentDeep,
                  caption: loc.yesCaptionAfter,
                  bg: SalamatTokens.pillBg,
                ),
              ),
            ],
          ),
          const Spacer(),
        ],
      ),
      buttonLabel: loc.buttonYes,
      onContinue: () => context.go(_next),
      secondaryLabel: loc.buttonNo,
      onSecondary: () => context.go(_next),
    );
  }
}

class _Illust extends StatelessWidget {
  const _Illust({
    required this.icon,
    required this.iconColor,
    required this.caption,
    required this.bg,
  });
  final PhosphorIconData icon;
  final Color iconColor;
  final String caption;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 140,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(SalamatDims.cardRadius),
          ),
          child: PhosphorIcon(icon, size: 64, color: iconColor),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: SalamatTokens.iconQuiet,
          ),
        ),
      ],
    );
  }
}
