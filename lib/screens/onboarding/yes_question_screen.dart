import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/colors.dart';
import '../../theme/dimensions.dart';
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

  String get _beforeEmoji => switch (question) {
        YesQuestion.lose => '😟',
        YesQuestion.order => '🍔',
        YesQuestion.health => '💊',
      };

  String get _afterEmoji => switch (question) {
        YesQuestion.lose => '🤩',
        YesQuestion.order => '🥗',
        YesQuestion.health => '💚',
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
      step: 14,
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
              color: SalamatColors.ink,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _Illust(
                  emoji: _beforeEmoji,
                  caption: loc.yesCaptionBefore,
                  bg: SalamatColors.line,
                  emojiOpacity: 0.55,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: SalamatColors.i3,
                ),
              ),
              Expanded(
                child: _Illust(
                  emoji: _afterEmoji,
                  caption: loc.yesCaptionAfter,
                  bg: SalamatColors.g3,
                  emojiOpacity: 1.0,
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
    required this.emoji,
    required this.caption,
    required this.bg,
    required this.emojiOpacity,
  });
  final String emoji;
  final String caption;
  final Color bg;
  final double emojiOpacity;

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
          child: Opacity(
            opacity: emojiOpacity,
            child: Text(emoji, style: const TextStyle(fontSize: 72)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: GoogleFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: SalamatColors.i3,
          ),
        ),
      ],
    );
  }
}
